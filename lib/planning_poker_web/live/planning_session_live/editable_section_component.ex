defmodule PlanningPokerWeb.PlanningSessionLive.EditableSectionComponent do
  use PlanningPokerWeb, :live_component

  alias PlanningPoker.{Planning, IssueEditor}

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:editing, false)
     |> assign(:draft_content, assigns.section.content)}
  end

  @impl true
  def handle_event("start_edit", _params, socket) do
    section_id = socket.assigns.section.id
    session_id = socket.assigns.session_id
    user_id = socket.assigns.current_user_id

    case Planning.lock_section(session_id, section_id, user_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:editing, true)
         |> assign(:draft_content, socket.assigns.section.content)}

      {:error, :locked_by_other} ->
        {:noreply, put_flash(socket, :error, "This section is being edited by someone else")}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    section_id = socket.assigns.section.id
    session_id = socket.assigns.session_id
    user_id = socket.assigns.current_user_id

    Planning.unlock_section(session_id, section_id, user_id)

    {:noreply,
     socket
     |> assign(:editing, false)
     |> assign(:draft_content, socket.assigns.section.content)}
  end

  @impl true
  def handle_event("save_edit", %{"content" => content}, socket) do
    section_id = socket.assigns.section.id
    session_id = socket.assigns.session_id
    user_id = socket.assigns.current_user_id

    case Planning.update_section(session_id, section_id, content, user_id) do
      :ok ->
        Planning.unlock_section(session_id, section_id, user_id)
        {:noreply, assign(socket, :editing, false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save section")}
    end
  end

  @impl true
  def handle_event("update_draft", %{"value" => value}, socket) do
    {:noreply, assign(socket, :draft_content, value)}
  end

  @impl true
  def handle_event("insert_after", _params, socket) do
    section_id = socket.assigns.section.id
    session_id = socket.assigns.session_id
    user_id = socket.assigns.current_user_id

    case Planning.insert_section_after(session_id, section_id, user_id) do
      {:ok, _new_section_id} ->
        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to insert section")}
    end
  end

  @impl true
  def handle_event("delete_section", _params, socket) do
    section_id = socket.assigns.section.id
    session_id = socket.assigns.session_id
    user_id = socket.assigns.current_user_id

    case Planning.delete_section(session_id, section_id, user_id) do
      :ok ->
        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete section")}
    end
  end

  @impl true
  def render(assigns) do
    # Determine lock status
    lock_info = Map.get(assigns.locks, assigns.section.id)
    locked_by_me = lock_info && lock_info.user_id == assigns.current_user_id
    locked_by_other = lock_info && lock_info.user_id != assigns.current_user_id

    assigns =
      assigns
      |> assign(:lock_info, lock_info)
      |> assign(:locked_by_me, locked_by_me)
      |> assign(:locked_by_other, locked_by_other)

    ~H"""
    <div class="editable-section group relative mb-4 p-4 border border-gray-200 rounded-lg hover:border-blue-300 transition-colors">
      <%= if @locked_by_other do %>
        <div class="absolute top-2 right-2 text-xs text-yellow-600 bg-yellow-50 px-2 py-1 rounded">
          <.icon name="hero-lock-closed" class="w-3 h-3 inline" /> Editing...
        </div>
      <% end %>

      <%= if @editing do %>
        <div class="space-y-2">
          <textarea
            id={"section-textarea-#{@section.id}"}
            phx-hook="AutoResizeTextarea"
            phx-target={@myself}
            phx-change="update_draft"
            name="content"
            class="w-full min-h-[100px] p-2 border border-blue-400 rounded font-mono text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            phx-debounce="300"
          ><%= @draft_content %></textarea>

          <div class="flex gap-2">
            <button
              phx-click="save_edit"
              phx-target={@myself}
              class="px-3 py-1 bg-blue-600 text-white rounded hover:bg-blue-700 text-sm"
            >
              Save
            </button>
            <button
              phx-click="cancel_edit"
              phx-target={@myself}
              class="px-3 py-1 bg-gray-300 text-gray-700 rounded hover:bg-gray-400 text-sm"
            >
              Cancel
            </button>
            <%= if @locked_by_me do %>
              <button
                phx-click="delete_section"
                phx-target={@myself}
                class="ml-auto px-3 py-1 bg-red-600 text-white rounded hover:bg-red-700 text-sm"
                data-confirm="Delete this section?"
              >
                <.icon name="hero-trash" class="w-4 h-4" />
              </button>
            <% end %>
          </div>
        </div>
      <% else %>
        <div
          phx-click={unless(@locked_by_other, do: "start_edit")}
          phx-target={@myself}
          class={[
            "prose prose-sm max-w-none cursor-pointer",
            @locked_by_other && "opacity-60 cursor-not-allowed"
          ]}
        >
          <%= raw(IssueEditor.markdown_to_html(@section.content)) %>
        </div>

        <%= if !@locked_by_other do %>
          <button
            phx-click="insert_after"
            phx-target={@myself}
            class="absolute -bottom-3 left-1/2 transform -translate-x-1/2 opacity-0 group-hover:opacity-100 transition-opacity bg-blue-500 text-white rounded-full w-6 h-6 flex items-center justify-center hover:bg-blue-600 shadow-md"
            title="Insert section below"
          >
            <.icon name="hero-plus" class="w-4 h-4" />
          </button>
        <% end %>
      <% end %>
    </div>
    """
  end
end
