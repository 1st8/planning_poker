defmodule PlanningPokerWeb.PlanningSessionLive.PersonalIssueNotesComponent do
  use PlanningPokerWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-8 bg-base-100 border-8 border-neutral p-8">
      <div class="flex flex-col gap-8">
        <h2 class="font-bold bg-neutral text-neutral-content uppercase -m-8 mb-0 px-8 py-2 border-b-8 border-neutral">
          Personal Notes
        </h2>
        <div class="flex flex-col gap-2">
          <textarea
            id={"personal-notes-#{@current_issue["id"]}"}
            class="textarea textarea-bordered w-full h-32 resize-none"
            placeholder="Write your personal notes for this issue..."
            phx-hook="PersonalIssueNotes"
            data-issue-id={@current_issue["id"]}
            data-participant-id={@current_participant[:id]}
          ><%= get_note(@personal_notes, @current_issue["id"]) %></textarea>
          <p class="text-xs text-base-content/50">
            Notes are saved locally and only visible to you
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp get_note(notes, issue_id) when is_map(notes) do
    Map.get(notes, issue_id, "")
  end

  defp get_note(_notes, _issue_id), do: ""
end
