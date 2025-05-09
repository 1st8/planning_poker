defmodule PlanningPokerWeb.PlanningSessionLive.VotingComponent do
  use PlanningPokerWeb, :live_component

  def render(assigns) do
    ~H"""
    <main>
      <.layout_box title="Voting">
        <h1 class="text-4xl font-semibold">
          <a class="underline decoration-primary hover:decoration-primary/50 decoration-4" href={@issue["webUrl"]} target="_blank">
            <%= @issue["title"] %>
          </a>
        </h1>
        <div id="issue-description" class="prose prose-lg" phx-hook="LazyImages" data-base-url={@issue[:base_url]}>
          <%= raw(@issue["descriptionHtml"]) %>
        </div>
        <:controls>
          <button class="btn" phx-click="finish_voting">Finish Voting</button>
        </:controls>
      </.layout_box>
    </main>
    """
  end
end
