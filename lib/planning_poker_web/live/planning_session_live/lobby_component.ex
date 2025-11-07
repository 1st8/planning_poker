defmodule PlanningPokerWeb.PlanningSessionLive.LobbyComponent do
  use PlanningPokerWeb, :live_component

  def render(assigns) do
    ~H"""
    <main>
      <.layout_box title="Issues">
        <%= if Enum.empty?(@data.issues) do %>
          <div class="text-center py-16">
            <div class="text-6xl mb-4">🎉</div>
            <h3 class="text-2xl font-bold mb-2">Alle Issues sind geplant!</h3>
            <p class="text-base-content/70">Tolle Arbeit! Es gibt momentan keine offenen Issues zum Planen.</p>
          </div>
        <% else %>
          <ol class="grid 2xl:grid-cols-2 gap-8">
            <%= for issue <- @data.issues do %>
              <li class="flex bg-base-300 rounded-lg rounded-r-full ">
                <div class="grow px-4 py-3 relative">
                  <a
                    class="block text-lg font-medium underline decoration-primary hover:decoration-primary/50 decoration-2"
                    href={issue["webUrl"]}
                    target="_blank"
                  >
                    {issue["title"]}
                  </a>
                  <small class="text-sm">{issue["referencePath"]}</small>
                  <%= if issue["id"] in @data.opened_issue_ids do %>
                    <.icon
                      name="hero-check-badge-solid"
                      class={"text-success absolute h-12 w-12 right-4 top-1/2 transform -translate-y-1/2 rotate-6 pointer-events-none" <> if issue["id"] == @data.most_recent_issue_id, do: " recently_opened", else: ""}
                    />
                  <% end %>
                </div>
                <button
                  class="btn btn-accent btn-shadow btn-lg h-auto"
                  phx-click="start_voting"
                  phx-value-issue_id={issue["id"]}
                >
                  {if @data.mode == :magic_estimation, do: "View", else: "Plan"}
                </button>
              </li>
            <% end %>
          </ol>
        <% end %>
        <:controls>
          <div class="space-x-1">
            <%= if @data.mode == :magic_estimation && !@data.fetching do %>
              <button class="btn btn-accent btn-sm" phx-click="start_magic_estimation">
                <.icon name="hero-sparkles-mini" /> Start Magic Estimation
              </button>
            <% end %>

            <%= if @data.fetching do %>
              <button class="btn btn-primary btn-sm loading" disabled phx-click="refresh_issues">
                Loading...
              </button>
            <% else %>
              <button class="btn btn-primary btn-sm" phx-click="refresh_issues">
                <.icon name="hero-arrow-path-mini" /> Refresh
              </button>
            <% end %>
          </div>
        </:controls>
      </.layout_box>
    </main>
    """
  end
end
