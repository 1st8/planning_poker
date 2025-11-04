defmodule PlanningPokerWeb.PlanningComponents do
  @moduledoc """
  Provides planning-specific UI components.
  """
  use Phoenix.Component

  @doc """
  Renders a profile image using Gravatar with SHA256 email hashing.

  ## Examples

      <.profile_image user={participant} class="w-8 h-8" />
      <.profile_image user={participant} aria-hidden="true" />
  """
  attr :user, :map, required: true, doc: "user map with name and optional email"
  attr :alt, :string, default: nil, doc: "the image alt text (defaults to user name)"
  attr :class, :string, default: "", doc: "additional CSS classes"
  attr :rest, :global, doc: "arbitrary HTML attributes (aria-hidden, etc.)"

  def profile_image(assigns) do
    assigns =
      assigns
      |> assign(:src, generate_gravatar_url(assigns.user))
      |> assign(:alt, assigns.alt || Map.get(assigns.user, :name, ""))

    ~H"""
    <img src={@src} alt={@alt} class={@class} {@rest} />
    """
  end

  # Generate a Gravatar URL using SHA256 hash of email
  # Falls back to initials-based generation if no Gravatar is found
  defp generate_gravatar_url(user) do
    email = Map.get(user, :email) || Map.get(user, "email") || "#{user.id || user["id"]}@example.com"
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
      |> URI.encode_www_form()

    "https://gravatar.com/avatar/#{email_hash}?d=https%3A%2F%2Fui-avatars.com%2Fapi%2F%3Fname%3D#{initials}%26background%3D0D8ABC%26color%3Dfff"
  end
end
