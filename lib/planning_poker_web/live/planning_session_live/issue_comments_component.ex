defmodule PlanningPokerWeb.PlanningSessionLive.IssueCommentsComponent do
  @moduledoc """
  Renders the issue's comments below the description, collapsed by default.

  The provider has already dropped GitLab's system and internal notes, so every
  entry here was written by a person. Bodies are markdown and go through the
  same pipeline as the description, inside the same asset-proxy wrapper, so
  images and collapsible blocks behave identically.
  """
  use PlanningPokerWeb, :html

  alias PlanningPokerWeb.PlanningSessionLive.CollaborativeIssueEditorComponent

  attr :issue, :map, required: true

  def issue_comments(assigns) do
    assigns = assign(assigns, :comments, List.wrap(assigns.issue["comments"]))

    ~H"""
    <details :if={@comments != []} id="issue-comments" class="mt-8 border-t-4 border-base-300 pt-4">
      <summary class="cursor-pointer font-semibold select-none">
        Comments ({length(@comments)})
      </summary>

      <ol class="mt-4 flex flex-col gap-6">
        <li :for={comment <- @comments} class="flex flex-col gap-1">
          <p class="text-sm text-base-content/70">
            <span class="font-medium text-base-content">
              {get_in(comment, ["author", "name"]) || "Unknown"}
            </span>
            <span :if={format_datetime(comment["createdAt"])}>
              · {format_datetime(comment["createdAt"])}
            </span>
          </p>
          <div
            class="collaborative-editor prose max-w-none"
            phx-hook="ProxyGitLabAssets"
            data-project-id={@issue["projectId"]}
            id={"comment-#{comment["id"]}"}
          >
            {Phoenix.HTML.raw(CollaborativeIssueEditorComponent.render_markdown(comment["body"]))}
          </div>
        </li>
      </ol>
    </details>
    """
  end
end
