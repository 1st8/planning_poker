defmodule PlanningPokerWeb.PlanningSessionLive.LobbyComponent do
  use PlanningPokerWeb, :live_component

  def render(assigns) do
    ~H"""
    <main>
      <.layout_box title="Issues">
        <ol class="grid 2xl:grid-cols-2 gap-8">
          <%= for issue <- @data.issues do %>
            <li class="flex bg-base-300 rounded-lg rounded-r-full">
              <div class="grow px-4 py-3">
                <a class="block text-lg font-medium underline decoration-primary hover:decoration-primary/50 decoration-2" href={issue["webUrl"]} target="_blank">
                  <%= issue["title"] %>
                </a>
                <small class="text-sm"><%= issue["referencePath"] %></small>
              </div>
              <button class="btn btn-accent btn-shadow btn-lg h-auto" phx-click="start_voting" phx-value-issue_id={issue["id"]}>
                Plan
              </button>
            </li>
          <% end %>
        </ol>
        <:controls>
          <%= if @data.fetching do %>
            <button class="btn btn-primary btn-xs loading" disabled phx-click="refresh_issues">
              Loading...
            </button>
          <% else %>
            <button class="btn btn-primary btn-sm" phx-click="refresh_issues">
              <.icon name="hero-arrow-path-mini" />
              Refresh
            </button>
          <% end %>
        </:controls>
      </.layout_box>
    </main>
    """
  end
end
