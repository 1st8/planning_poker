defmodule PlanningPokerWeb.PlanningComponents do
  @moduledoc """
  Provides planning-specific UI components.
  """
  use Phoenix.Component

  @doc """
  Renders a profile image with fallback support.

  First tries to load the avatar URL from the user (e.g., GitLab avatar).
  If that fails (e.g., Firefox blocking cross-origin cookies), falls back to Gravatar.

  ## Examples

      <.profile_image user={participant} class="w-8 h-8" />
      <.profile_image user={participant} aria-hidden="true" />
  """
  attr :user, :map, required: true, doc: "user map with name and optional email"
  attr :alt, :string, default: nil, doc: "the image alt text (defaults to user name)"
  attr :class, :string, default: "", doc: "additional CSS classes"
  attr :rest, :global, doc: "arbitrary HTML attributes (aria-hidden, etc.)"

  def profile_image(assigns) do
    avatar_url = Map.get(assigns.user, :avatar) || Map.get(assigns.user, "avatar")
    gravatar_url = generate_gravatar_url(assigns.user)

    assigns =
      assigns
      |> assign(:src, avatar_url || gravatar_url)
      |> assign(:gravatar_fallback, gravatar_url)
      |> assign(:has_avatar, !!avatar_url)
      |> assign(:alt, assigns.alt || Map.get(assigns.user, :name, ""))

    ~H"""
    <img
      src={@src}
      alt={@alt}
      class={@class}
      onerror={if @has_avatar, do: "this.onerror=null; this.src='#{@gravatar_fallback}'", else: nil}
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

    # Extract initials for fallback: "Christoph Geschwind" -> "C+G"
    initials =
      name
      |> String.split(" ")
      |> Enum.map(&String.first/1)
      |> Enum.join("+")

    # URL encode the name parameter
    encoded_name = URI.encode_www_form(initials)

    "https://gravatar.com/avatar/#{email_hash}?d=initials&name=#{encoded_name}"
  end
end
