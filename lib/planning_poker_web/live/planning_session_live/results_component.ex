defmodule PlanningPokerWeb.PlanningSessionLive.ResultsComponent do
  use PlanningPokerWeb, :live_component

  import PlanningPokerWeb.PlanningSessionLive.ParticipantsListComponent, only: [render_name: 2]

  def render(assigns) do
    ~H"""
    <main>
      <.layout_box title="Results">
        <h2 class="text-3xl font-semibold">
          <a
            class="underline decoration-primary hover:decoration-primary/50 decoration-4"
            href={@issue["webUrl"]}
            target="_blank"
          >
            {@issue["title"]}
          </a>
        </h2>
        <div class="flex flex-wrap gap-8 items-center">
          <%= for vote <- @votes do %>
            <% {bg, text} = @classes[vote[:vote]] %>
            <div class={"#{bg} #{text} flex flex-col items-stretch text-center border-4 border-neutral w-32 rounded-2xl"}>
              <strong class="text-8xl leading-normal">{vote[:vote]}</strong>
              <span class="bg-neutral text-neutral-content text-lg font-semibold truncate py-2">
                {render_name(vote, @votes)}
              </span>
            </div>
          <% end %>
        </div>
        <:controls>
          <button class="btn" phx-click="commit_results">Back to lobby</button>
        </:controls>
      </.layout_box>
    </main>
    """
  end
end
