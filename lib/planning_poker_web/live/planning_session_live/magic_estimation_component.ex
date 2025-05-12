defmodule PlanningPokerWeb.PlanningSessionLive.MagicEstimationComponent do
  use PlanningPokerWeb, :live_component

  def render(assigns) do
    ~H"""
    <main>
      <.layout_box title="Magic Estimation">
        <div class="grid grid-cols-2 gap-8" phx-hook="SortableIssues" id="magic-estimation-container">
          <div class="issue-column flex flex-col" id="unestimated-issues">
            <h2 class="text-xl font-semibold mb-4">Unestimated Issues</h2>
            <div class="issue-list sortable-list grow" data-column-id="unestimated-issues">
              <%= for issue <- @unestimated_issues do %>
                <div class="issue-card bg-base-300 rounded-lg p-4 mb-2 cursor-move" data-id={issue["id"]}>
                  <div class="font-medium">
                    <%= issue["title"] %>
                  </div>
                  <small class="text-sm"><%= issue["referencePath"] %></small>
                </div>
              <% end %>
            </div>
          </div>
          <div class="issue-column flex flex-col" id="estimated-issues">
            <h2 class="text-xl font-semibold mb-4">Estimated Issues (Ascending Story Points)</h2>
            <div class="issue-list sortable-list grow" data-column-id="estimated-issues">
              <%= for issue <- @estimated_issues do %>
                <div class="issue-card bg-base-300 rounded-lg p-4 mb-2 cursor-move" data-id={issue["id"]}>
                  <div class="font-medium">
                    <%= issue["title"] %>
                  </div>
                  <small class="text-sm"><%= issue["referencePath"] %></small>
                </div>
              <% end %>
            </div>
          </div>
        </div>
        <:controls>
          <button class="btn" phx-click="back_to_lobby">
            Back to Lobby
          </button>
          <button class="btn btn-primary" phx-click="complete_estimation">
            Complete Estimation
          </button>
        </:controls>
      </.layout_box>
    </main>
    """
  end

  def handle_event("issue_moved", %{"issue_id" => issue_id, "from" => from, "to" => to, "new_index" => new_index} = params, socket) do
    # Debug logging
    IO.inspect(params, label: "MagicEstimationComponent received issue_moved event")

    # Send the event up to the parent LiveView which handles the PlanningSession
    send(self(), {:issue_moved, %{issue_id: issue_id, from: from, to: to, new_index: new_index}})
    {:noreply, socket}
  end
end
