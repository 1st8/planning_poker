defmodule PlanningPokerWeb.PlanningComponents do
  @moduledoc """
  Provides planning-specific UI components.
  """
  use Phoenix.Component

  @doc """
  Renders a profile image with fallback support.

  First tries to load the avatar URL from the user (e.g., GitLab avatar).
  If that fails (e.g., Firefox blocking cross-origin cookies), falls back to Gravatar.
  Uses server-side state management to handle fallbacks reliably across LiveView updates.

  ## Examples

      <.live_component module={PlanningPokerWeb.PlanningComponents.ProfileImageComponent} id="user-123" user={user} class="w-8 h-8" />
      <.live_component module={PlanningPokerWeb.PlanningComponents.ProfileImageComponent} id="editor-456" user={user} aria-hidden="true" />
  """
  defmodule ProfileImageComponent do
    use Phoenix.LiveComponent

    @impl true
    def update(assigns, socket) do
      user = assigns.user
      avatar_url = Map.get(user, :avatar) || Map.get(user, "avatar")
      gravatar_url = generate_gravatar_url(user)

      # Initialize load_state if not already set
      load_state = socket.assigns[:load_state] || :initial

      # Determine src based on load state
      src = case load_state do
        :initial -> avatar_url || gravatar_url
        :failed_avatar -> gravatar_url
        :failed_gravatar -> gravatar_url  # Gravatar handles initials fallback
      end

      # Extract rest attributes (everything except known attrs)
      rest = assigns
        |> Map.drop([:user, :id, :class, :alt, :flash, :myself, :__changed__])
        |> Enum.into(%{})

      {:ok,
       socket
       |> assign(:id, assigns.id)
       |> assign(:user, user)
       |> assign(:class, assigns[:class] || "")
       |> assign(:src, src)
       |> assign(:avatar_url, avatar_url)
       |> assign(:gravatar_url, gravatar_url)
       |> assign(:load_state, load_state)
       |> assign(:alt, assigns[:alt] || Map.get(user, :name, ""))
       |> assign(:rest, rest)}
    end

    @impl true
    def handle_event("image_load_failed", _params, socket) do
      new_state = case socket.assigns.load_state do
        :initial -> :failed_avatar
        :failed_avatar -> :failed_gravatar
        :failed_gravatar -> :failed_gravatar  # Already at final fallback
      end

      new_src = case new_state do
        :failed_avatar -> socket.assigns.gravatar_url
        :failed_gravatar -> socket.assigns.gravatar_url
        _ -> socket.assigns.src
      end

      {:noreply, socket |> assign(:load_state, new_state) |> assign(:src, new_src)}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <img
        id={@id}
        src={@src}
        alt={@alt}
        class={@class}
        phx-hook="ProfileImage"
        phx-target={@myself}
        {@rest}
      />
      """
    end

    # Generate a Gravatar URL using SHA256 hash of email
    # Falls back to initials-based generation if no Gravatar is found
    defp generate_gravatar_url(user) do
      email =
        Map.get(user, :email) || Map.get(user, "email") || "#{user.id || user["id"]}@example.com"

      name = Map.get(user, :name) || Map.get(user, "name") || "User"

      # SHA256 hash the email
      email_hash =
        email
        |> String.downcase()
        |> String.trim()
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)

      # Extract initials for fallback: "Christoph Geschwind" -> "C G"
      initials =
        name
        |> String.split(" ")
        |> Enum.map(&String.first/1)
        |> Enum.join(" ")

      # URL encode the name parameter
      encoded_name = URI.encode_www_form(initials)

      "https://gravatar.com/avatar/#{email_hash}?d=initials&name=#{encoded_name}"
    end
  end
end
