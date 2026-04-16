defmodule PlanningPokerWeb.PlanningComponents do
  @moduledoc """
  Provides planning-specific UI components.
  """
  use Phoenix.Component

  @doc """
  Renders a profile image using Gravatar.

  Generates a Gravatar URL based on the user's email with initials as fallback.

  ## Examples

      <.profile_image user={user} class="w-8 h-8" />
      <.profile_image user={user} alt="User avatar" />
  """
  attr :user, :map, required: true
  attr :class, :string, default: ""
  attr :alt, :string, default: nil
  attr :rest, :global

  def profile_image(assigns) do
    assigns = assign(assigns, :src, generate_gravatar_url(assigns.user))
    assigns = assign(assigns, :alt, assigns.alt || Map.get(assigns.user, :name, ""))

    ~H"""
    <img
      src={@src}
      alt={@alt}
      class={@class}
      {@rest}
    />
    """
  end

  @doc """
  Renders a banner showing the remaining OAuth session time and a manual
  "extend session" button. Hidden for non-expiring tokens (mock provider).

  The `token_info` map must contain:
    * `:seconds_until_expiry` — integer (nullable)
    * `:refreshable` — boolean
    * `:refreshing` — boolean
    * `:non_expiring` — boolean
  """
  attr :token_info, :map, required: true

  def session_token_banner(assigns) do
    ~H"""
    <div :if={not @token_info.non_expiring} class="w-full flex justify-center">
      <div
        id="session-token-banner"
        class={[
          "flex items-center gap-3 px-4 py-2 m-2 rounded-lg shadow-sm text-sm",
          session_banner_class(@token_info)
        ]}
        role="status"
      >
        <span class="font-medium">
          <%= cond do %>
            <% @token_info.seconds_until_expiry == nil -> %>
              Sitzung aktiv
            <% @token_info.seconds_until_expiry <= 0 -> %>
              Sitzung abgelaufen
            <% true -> %>
              Sitzung läuft noch
              <span data-session-remaining-seconds={@token_info.seconds_until_expiry}>
                {format_remaining(@token_info.seconds_until_expiry)}
              </span>
          <% end %>
        </span>
        <span :if={@token_info.refreshing} class="loading loading-spinner loading-xs"></span>
        <button
          :if={@token_info.refreshable and not @token_info.refreshing}
          type="button"
          phx-click="refresh_token_now"
          class="btn btn-xs btn-primary"
          id="refresh-token-btn"
        >
          Jetzt verlängern
        </button>
        <a
          :if={not @token_info.refreshable}
          href="/auth/logout"
          class="btn btn-xs btn-warning"
        >
          Neu einloggen
        </a>
      </div>
    </div>
    """
  end

  # < 10 min  -> warning colour, otherwise neutral
  defp session_banner_class(%{seconds_until_expiry: nil}), do: "bg-base-200"

  defp session_banner_class(%{seconds_until_expiry: s}) when s <= 0,
    do: "bg-error text-error-content"

  defp session_banner_class(%{seconds_until_expiry: s}) when s < 600,
    do: "bg-warning text-warning-content"

  defp session_banner_class(_), do: "bg-base-200"

  defp format_remaining(seconds) when seconds <= 0, do: "0 min"

  defp format_remaining(seconds) do
    minutes = div(seconds, 60)

    cond do
      minutes < 1 -> "<1 min"
      minutes < 60 -> "#{minutes} min"
      true -> "#{div(minutes, 60)}h #{rem(minutes, 60)}m"
    end
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
