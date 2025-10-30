defmodule PlanningPokerWeb.PlanningSessionLive.CollaborativeIssueEditorComponent do
  use PlanningPokerWeb, :live_component

  alias PlanningPoker.Planning

  @impl true
  def render(assigns) do
    ~H"""
    <div class="collaborative-editor prose prose-lg max-w-none">
      <div :if={@issue["sections"]} class="sections-container">
        <%= for {section, index} <- Enum.with_index(@issue["sections"]) do %>
          <div
            id={"section-#{section["id"]}"}
            class="section-wrapper relative group"
            data-section-id={section["id"]}
          >
            <!-- Add section button (shown on hover between sections) -->
            <div
              :if={!section["locked_by"]}
              class="add-section-divider absolute -top-2 left-0 right-0 h-4 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center"
            >
              <button
                phx-click="add_section"
                phx-value-position={index}
                phx-target={@myself}
                class="bg-gray-100 hover:bg-gray-200 text-gray-600 text-xs px-2 py-0.5 rounded border border-gray-300 shadow-sm"
                title="Add section here"
              >
                + Add Section
              </button>
            </div>

            <%= if section["locked_by"] == @current_user_id do %>
              <!-- Edit mode: textarea swap -->
              <div class="edit-mode mb-4">
                <textarea
                  id={"textarea-#{section["id"]}"}
                  data-section-id={section["id"]}
                  phx-hook="SectionEditor"
                  phx-target={@myself}
                  class="w-full min-h-[100px] p-2 border border-gray-300 rounded font-mono text-sm focus:outline-none focus:ring-1 focus:ring-gray-400 resize-y"
                  placeholder="Enter section content..."
                ><%= section["content"] %></textarea>
                <div class="flex gap-2 mt-1">
                  <button
                    phx-click="unlock_section"
                    phx-value-section-id={section["id"]}
                    phx-target={@myself}
                    class="px-2 py-1 text-xs border border-gray-300 rounded hover:bg-gray-50"
                  >
                    Save
                  </button>
                  <button
                    phx-click="unlock_section"
                    phx-value-section-id={section["id"]}
                    phx-target={@myself}
                    class="px-2 py-1 text-xs border border-gray-300 rounded hover:bg-gray-50"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            <% else %>
              <!-- Display mode: looks like regular HTML -->
              <div class="section-display relative group/section">
                <%= if section["locked_by"] do %>
                  <!-- Subtle lock indicator when locked by others -->
                  <div class="absolute -left-6 top-0 text-gray-400" title="Being edited by another participant">
                    <.icon name="hero-lock-closed" class="w-3 h-3" />
                  </div>
                <% else %>
                  <!-- Edit button on hover -->
                  <button
                    phx-click="lock_section"
                    phx-value-section-id={section["id"]}
                    phx-target={@myself}
                    class="absolute -right-10 top-0 opacity-0 group-hover/section:opacity-100 transition-opacity bg-gray-100 hover:bg-gray-200 text-gray-600 text-xs px-2 py-0.5 rounded border border-gray-300 shadow-sm"
                    title="Edit this section"
                  >
                    Edit
                  </button>
                <% end %>

                <!-- Regular prose content -->
                <div class="section-content">
                  <%= if section["content"] == "" do %>
                    <p class="text-gray-400 italic text-sm">Empty section</p>
                  <% else %>
                    <%= raw(render_markdown(section["content"])) %>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <!-- Add section at end button -->
        <div class="add-section-end mt-4 pt-2 border-t border-gray-200 opacity-50 hover:opacity-100 transition-opacity">
          <button
            phx-click="add_section"
            phx-value-position={length(@issue["sections"] || [])}
            phx-target={@myself}
            class="text-sm text-gray-600 hover:text-gray-800 flex items-center gap-1"
          >
            <.icon name="hero-plus" class="w-4 h-4" />
            Add Section
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(%{issue: issue, current_user_id: current_user_id, session_id: session_id}, socket) do
    {:ok,
     socket
     |> assign(:issue, issue)
     |> assign(:current_user_id, current_user_id)
     |> assign(:session_id, session_id)}
  end

  @impl true
  def handle_event("lock_section", %{"section-id" => section_id}, socket) do
    case Planning.lock_section(socket.assigns.session_id, section_id, socket.assigns.current_user_id) do
      :ok ->
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not lock section")}
    end
  end

  @impl true
  def handle_event("unlock_section", %{"section-id" => section_id}, socket) do
    case Planning.unlock_section(socket.assigns.session_id, section_id, socket.assigns.current_user_id) do
      :ok ->
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not unlock section")}
    end
  end

  @impl true
  def handle_event("add_section", %{"position" => position}, socket) do
    position = String.to_integer(position)

    case Planning.add_section(socket.assigns.session_id, position, socket.assigns.current_user_id) do
      :ok ->
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not add section")}
    end
  end

  @impl true
  def handle_event("update_section_content", %{"section_id" => section_id, "content" => content}, socket) do
    case Planning.update_section_content(socket.assigns.session_id, section_id, content, socket.assigns.current_user_id) do
      :ok ->
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}  # Silently fail for live updates
    end
  end

  @impl true
  def handle_event("delete_section", %{"section-id" => _section_id}, socket) do
    # TODO: Implement delete_section in the state machine
    {:noreply, put_flash(socket, :info, "Delete section not yet implemented")}
  end

  # Helpers

  defp render_markdown(content) do
    case Earmark.as_html(content) do
      {:ok, html, _} -> html
      {:error, _html, _errors} -> "<p>Error rendering markdown</p>"
    end
  end
end
