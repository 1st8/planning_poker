defmodule PlanningPokerWeb.PlanningSessionLive.MagicEstimationComponent do
  use PlanningPokerWeb, :live_component

  # Define a function component for rendering an item (issue or marker)
  defp render_item(assigns) do
    ~H"""
    <%= if @item["type"] == "marker" do %>
      <div class="marker-card bg-accent text-accent-content rounded-lg p-2 mb-2 cursor-move" data-id={@item["id"]}>
        <div class="flex gap-4 items-center justify-center">⬇️<span class="font-bold text-lg"><%= @item["value"] %></span>⬇️</div>
      </div>
    <% else %>
      <div class="issue-card bg-base-100 rounded-lg p-4 mb-2 cursor-move" data-id={@item["id"]}>
        <div class="font-medium">
          <%= @item["title"] %>
        </div>
        <small class="text-sm"><%= @item["referencePath"] %></small>
      </div>
    <% end %>
    """
  end

  def render(assigns) do
    ~H"""
    <main>
      <.layout_box title="Magic Estimation">
        <div class="grid grid-cols-2 gap-8" phx-hook="SortableIssues" id="magic-estimation-container">
          <div class="issue-column flex flex-col" id="unestimated-issues">
            <h2 class="text-xl font-semibold mb-4">Unestimated Issues</h2>
            <div class="issue-list sortable-list grow" data-column-id="unestimated-issues">
              <%= for item <- @unestimated_issues do %>
                <.render_item item={item} />
              <% end %>
            </div>
          </div>
          <div class="issue-column flex flex-col" id="estimated-issues">
            <h2 class="text-xl font-semibold mb-4">Estimated Issues (Ascending Story Points)</h2>
            <div class="issue-list sortable-list grow" data-column-id="estimated-issues">
              <%= for item <- @estimated_issues do %>
                <.render_item item={item} />
              <% end %>
            </div>
          </div>
        </div>
        <:controls>
          <button class="btn btn-primary btn-sm" phx-hook="LongPressButton" data-action="complete_estimation" id="complete-estimation-btn">
            <span>Press and hold to complete</span>
          </button>
        </:controls>
      </.layout_box>
    </main>
    """
  end
end
