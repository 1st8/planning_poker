defmodule PlanningPokerWeb.PlanningSessionLive.VotingComponent do
  use PlanningPokerWeb, :live_component

  alias PlanningPokerWeb.PlanningSessionLive.CollaborativeIssueEditorComponent

  def render(assigns) do
    ~H"""
    <main>
      <.layout_box title="Voting">
        <h1 class="text-4xl font-semibold">
          <a
            class="underline decoration-primary hover:decoration-primary/50 decoration-4"
            href={@issue["webUrl"]}
            target="_blank"
          >
            {@issue["title"]}
          </a>
        </h1>
        
    <!-- Collaborative Issue Editor -->
        <.live_component
          module={CollaborativeIssueEditorComponent}
          id="collaborative-editor"
          issue={@issue}
          current_user_id={@current_user_id}
          session_id={@session_id}
          participants={@participants}
        />

        <:controls>
          <%= if @mode == :magic_estimation do %>
            <%= if @issue_modified do %>
              <!-- Show both buttons when issue has modifications -->
              <button class="btn btn-sm" phx-click="back_to_lobby">
                Discard changes & Back
              </button>
              <button
                class="btn btn-primary"
                phx-click="save_and_back_to_lobby"
                disabled={!!@issue["saving"]}
              >
                {if @issue["saving"], do: "Saving...", else: "Save issue & Back"}
              </button>
            <% else %>
              <!-- Show only Back button when no modifications -->
              <button class="btn" phx-click="back_to_lobby">
                Back
              </button>
            <% end %>
          <% else %>
            <!-- Traditional planning poker mode -->
            <button class="btn" phx-click="finish_voting">
              Finish Voting
            </button>
          <% end %>
        </:controls>
      </.layout_box>
    </main>
    """
  end
end
