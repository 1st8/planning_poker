defmodule PlanningPokerWeb.PlanningComponents do
  @moduledoc """
  Provides planning-specific UI components.
  """
  use Phoenix.Component

  @doc """
  Renders a profile image.

  ## Examples

      <.profile_image src={user.avatar} alt={user.name} class="w-8 h-8" />
      <.profile_image src={user.avatar} aria-hidden="true" />
  """
  attr :src, :string, required: true, doc: "the image source URL"
  attr :alt, :string, default: "", doc: "the image alt text"
  attr :class, :string, default: "", doc: "additional CSS classes"
  attr :rest, :global, doc: "arbitrary HTML attributes (aria-hidden, etc.)"

  def profile_image(assigns) do
    ~H"""
    <img src={@src} alt={@alt} class={@class} {@rest} />
    """
  end
end
