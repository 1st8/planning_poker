defmodule PlanningPokerWeb.PlanningSessionLive.VotingComponent do
  use PlanningPokerWeb, :live_component

  alias PlanningPokerWeb.PlanningSessionLive.CollaborativeIssueEditorComponent

  def render(assigns) do
    ~H"""
    <main>
      <.layout_box title="Voting">
        <h1 class="text-4xl font-semibold">
          <a class="underline decoration-primary hover:decoration-primary/50 decoration-4" href={@issue["webUrl"]} target="_blank">
            <%= @issue["title"] %>
          </a>
        </h1>

        <!-- Collaborative Issue Editor -->
        <.live_component
          module={CollaborativeIssueEditorComponent}
          id="collaborative-editor"
          issue={@issue}
          current_user_id={@current_user_id}
          session_id={@session_id}
        />

        <:controls>
          <button class="btn" phx-click={if @mode == :magic_estimation, do: "back_to_lobby", else: "finish_voting"}>
            <%= if @mode == :magic_estimation, do: "Back", else: "Finish Voting" %>
          </button>
        </:controls>
      </.layout_box>
    </main>
    """
  end
end
