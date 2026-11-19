defmodule PlanningPokerWeb.PlanningSessionLive.PersonalIssueNotesComponent do
  use PlanningPokerWeb, :live_component

  def render(assigns) do
    assigns = assign(assigns, :ready?, !!assigns.current_participant[:readiness])

    ~H"""
    <div class="flex flex-col gap-8 bg-base-100 border-8 border-neutral p-8">
      <div class="flex flex-col gap-8">
        <h2 class="font-bold bg-neutral text-neutral-content uppercase -m-8 mb-0 px-8 py-2 border-b-8 border-neutral">
          Personal Notes
        </h2>
        <div class="flex flex-col gap-2">
          <input
            type="text"
            id={"personal-notes-#{@current_issue["id"]}"}
            class="input w-full"
            placeholder="Your estimate, e.g. 5 or 3-5"
            value={get_note(@personal_notes, @current_issue["id"])}
            phx-hook="PersonalIssueNotes"
            phx-keydown="set_readiness"
            phx-key="Enter"
            phx-value-ready={to_string(!@ready?)}
            data-issue-id={@current_issue["id"]}
            data-participant-id={@current_participant[:id]}
            data-magic-mode="true"
            autocomplete="off"
            autofocus
            phx-mounted={JS.focus()}
          />
          <p class="text-xs text-base-content/50">
            Notes are saved locally and only visible to you
          </p>
          <%!-- Filled by the PersonalIssueNotes hook; min-h reserves one line so the badge appearing doesn't shift the layout --%>
          <p
            id={"personal-notes-badge-#{@current_issue["id"]}"}
            class="text-xs text-base-content/50 italic min-h-4"
            aria-live="polite"
            data-role="magic-parse-badge"
            phx-update="ignore"
          >
          </p>
          <button
            class={[
              "btn btn-lg text-lg btn-shadow justify-center mt-2",
              (@ready? && "btn-accent btn-active") || "btn-primary"
            ]}
            phx-click="set_readiness"
            phx-value-ready={to_string(!@ready?)}
            aria-pressed={to_string(@ready?)}
          >
            <.icon :if={@ready?} name="hero-check-circle-solid" class="h-6 w-6" />
            <span>I'm ready</span>
          </button>
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
