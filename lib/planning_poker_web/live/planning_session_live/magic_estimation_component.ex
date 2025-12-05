defmodule PlanningPokerWeb.PlanningSessionLive.MagicEstimationComponent do
  use PlanningPokerWeb, :live_component

  # Define a function component for rendering an item (issue or marker)
  defp render_item(assigns) do
    ~H"""
    <%= if @item["type"] == "marker" do %>
      <div
        class="marker-card bg-accent text-accent-content rounded-lg p-2 mb-2 cursor-move"
        data-id={@item["id"]}
      >
        <div class="flex gap-4 items-center justify-center">
          ⬇️<span class="font-bold text-lg"><%= @item["value"] %></span>⬇️
        </div>
      </div>
    <% else %>
      <div class="issue-card bg-base-100 rounded-lg p-4 mb-2 cursor-move" data-id={@item["id"]}>
        <div class="font-medium">
          <a
            href={@item["webUrl"]}
            target="_blank"
            class="underline decoration-primary hover:decoration-primary/50 decoration-2"
          >
            {@item["title"]}
          </a>
        </div>
        <small class="text-sm">{@item["referencePath"]}</small>
        <%= if note = get_note(@personal_notes, @item["id"]) do %>
          <div class="mt-2 text-sm italic text-base-content/60 border-l-2 border-primary/30 pl-2">
            {note}
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp get_note(notes, issue_id) when is_map(notes) do
    case Map.get(notes, issue_id) do
      nil -> nil
      "" -> nil
      note -> note
    end
  end

  defp get_note(_notes, _issue_id), do: nil

  def render(assigns) do
    ~H"""
    <main>
      <.layout_box title="Magic Estimation">
        <%= if @updating_weights do %>
          <div class="alert alert-info mb-4">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              class="stroke-current shrink-0 w-6 h-6 animate-spin"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
              />
            </svg>
            <span>
              Updating issue weights... ({@weight_update_completed}/{@weight_update_total} completed)
            </span>
          </div>
        <% end %>

        <div class="grid grid-cols-2 gap-8" phx-hook="SortableIssues" id="magic-estimation-container">
          <div class="issue-column flex flex-col" id="unestimated-issues">
            <h2 class="text-xl font-semibold mb-4">Unestimated Issues</h2>
            <div class="issue-list sortable-list grow" data-column-id="unestimated-issues">
              <%= for item <- @unestimated_issues do %>
                <.render_item item={item} personal_notes={@personal_notes} />
              <% end %>
            </div>
          </div>
          <div class="issue-column flex flex-col" id="estimated-issues">
            <h2 class="text-xl font-semibold mb-4">Estimated Issues (Ascending Story Points)</h2>
            <div class="issue-list sortable-list grow" data-column-id="estimated-issues">
              <%= for item <- @estimated_issues do %>
                <.render_item item={item} personal_notes={@personal_notes} />
              <% end %>
            </div>
          </div>
        </div>
        <:controls>
          <button
            class="btn btn-primary btn-sm"
            phx-hook="LongPressButton"
            data-action="complete_estimation"
            id="complete-estimation-btn"
            disabled={@updating_weights}
          >
            <span>Press and hold to complete</span>
          </button>
        </:controls>
      </.layout_box>
    </main>
    """
  end
end
