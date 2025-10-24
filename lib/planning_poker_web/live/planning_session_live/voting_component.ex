defmodule PlanningPokerWeb.PlanningSessionLive.VotingComponent do
  use PlanningPokerWeb, :live_component

  alias PlanningPokerWeb.PlanningSessionLive.EditableSectionComponent
  alias PlanningPoker.Planning

  def handle_event("insert_at_end", _params, socket) do
    session_id = socket.assigns.session_id
    user_id = socket.assigns.current_user_id

    # Get the last section ID
    last_section =
      socket.assigns.issue_edit.sections
      |> Enum.max_by(& &1.order, fn -> nil end)

    case last_section do
      nil ->
        {:noreply, socket}

      section ->
        Planning.insert_section_after(session_id, section.id, user_id)
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <main>
      <.layout_box title="Voting">
        <h1 class="text-4xl font-semibold mb-6">
          <a class="underline decoration-primary hover:decoration-primary/50 decoration-4" href={@issue["webUrl"]} target="_blank">
            <%= @issue["title"] %>
          </a>
        </h1>

        <div class="space-y-4">
          <%= if @issue_edit && length(@issue_edit.sections) > 0 do %>
            <%= for section <- Enum.sort_by(@issue_edit.sections, & &1.order) do %>
              <.live_component
                module={EditableSectionComponent}
                id={"section-#{section.id}"}
                section={section}
                locks={@issue_edit.locks}
                session_id={@session_id}
                current_user_id={@current_user_id}
              />
            <% end %>

            <div class="flex justify-center mt-6">
              <button
                phx-click="insert_at_end"
                phx-target={@myself}
                class="btn btn-outline btn-sm gap-2"
              >
                <.icon name="hero-plus-circle" class="w-5 h-5" />
                Add Section
              </button>
            </div>
          <% else %>
            <div id="issue-description" class="prose prose-lg" phx-hook="LazyImages" data-base-url={@issue[:base_url]}>
              <%= raw(@issue["descriptionHtml"]) %>
            </div>
          <% end %>
        </div>

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
