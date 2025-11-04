defmodule PlanningPokerWeb.PlanningComponents do
  @moduledoc """
  Provides planning-specific UI components.
  """
  use Phoenix.Component

  @doc """
  Renders a profile image, automatically proxying GitLab URLs to work around
  cross-domain cookie issues.

  ## Examples

      <.profile_image src={user.avatar} alt={user.name} class="w-8 h-8" />
      <.profile_image src={user.avatar} aria-hidden="true" />
  """
  attr :src, :string, required: true, doc: "the image source URL"
  attr :alt, :string, default: "", doc: "the image alt text"
  attr :class, :string, default: "", doc: "additional CSS classes"
  attr :rest, :global, doc: "arbitrary HTML attributes (aria-hidden, etc.)"

  def profile_image(assigns) do
    assigns = assign(assigns, :proxied_src, proxy_gitlab_url(assigns.src))

    ~H"""
    <img src={@proxied_src} alt={@alt} class={@class} {@rest} />
    """
  end

  # Rewrites GitLab URLs to use the proxy endpoint
  defp proxy_gitlab_url(url) when is_binary(url) do
    gitlab_site = System.get_env("GITLAB_SITE", "https://gitlab.com")

    if String.starts_with?(url, "#{gitlab_site}/uploads/") do
      # Replace GitLab domain with local proxy path
      String.replace_prefix(url, "#{gitlab_site}/uploads/", "/proxy/uploads/")
    else
      # Non-GitLab URLs pass through unchanged (e.g., ui-avatars.com for mock users)
      url
    end
  end

  defp proxy_gitlab_url(nil), do: ""
end
