defmodule PlanningPokerWeb.PlanningSessionLive.CollaborativeIssueEditorComponent do
  use PlanningPokerWeb, :live_component

  import PlanningPokerWeb.PlanningComponents

  alias PlanningPoker.Planning
  require Logger

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :gitlab_site, System.get_env("GITLAB_SITE", "https://gitlab.com"))

    ~H"""
    <div class="collaborative-editor prose prose-lg max-w-none" phx-hook="ProxyGitLabAssets" data-gitlab-site={@gitlab_site} id="collaborative-editor">
      <div :if={@issue["sections"]} class="sections-container">
        <%= for {section, index} <- Enum.with_index(@issue["sections"]) do %>
          <% is_edited =
            section["content"] != section["original_content"] and section["original_content"] != nil

          is_locked_by_other =
            section["locked_by"] != nil and section["locked_by"] != @current_user_id

          locked_by_user =
            is_locked_by_other && Enum.find(@participants, fn p -> p.id == section["locked_by"] end) %>
          <div
            id={"section-#{section["id"]}"}
            class="section-wrapper relative group hover:bg-base-200/50 transition-colors -mx-8 px-8"
            data-section-id={section["id"]}
          >
            <%= if section["locked_by"] == @current_user_id do %>
              <!-- Edit mode: textarea swap -->
              <div class="edit-mode mb-4">
                <textarea
                  id={"textarea-#{section["id"]}"}
                  data-section-id={section["id"]}
                  phx-hook="SectionEditor"
                  phx-target={@myself}
                  class="textarea rounded w-full min-h-[100px] font-mono text-sm resize-y"
                  placeholder="Enter section content..."
                ><%= section["content"] %></textarea>
                <div class="flex gap-2 mt-2">
                  <button
                    phx-click="unlock_section"
                    phx-value-section-id={section["id"]}
                    phx-target={@myself}
                    class="btn btn-primary btn-sm"
                  >
                    Save
                  </button>
                  <button
                    phx-click="cancel_section_edit"
                    phx-value-section-id={section["id"]}
                    phx-target={@myself}
                    class="btn btn-ghost btn-sm"
                  >
                    Cancel
                  </button>
                  <button
                    phx-click="delete_section"
                    phx-value-section-id={section["id"]}
                    phx-target={@myself}
                    class="btn btn-error btn-outline btn-sm ml-auto"
                  >
                    Delete
                  </button>
                </div>
              </div>
            <% else %>
              <div class={"section-display relative group/section #{if is_locked_by_other, do: "opacity-60"}"}>
                <%= if section["deleted"] do %>
                  <!-- Deleted indicator -->
                  <div class="absolute -left-6 -top-0.5 text-error/50" title="Marked for deletion">
                    <.icon name="hero-trash" class="w-4 h-4" />
                  </div>
                  <!-- Restore button on hover -->
                  <button
                    phx-click="restore_section"
                    phx-value-section-id={section["id"]}
                    phx-target={@myself}
                    class="absolute right-0 top-0 z-10 opacity-0 group-hover/section:opacity-100 transition-opacity btn btn-sm btn-success"
                    title="Restore this section"
                  >
                    <.icon name="hero-arrow-uturn-left" class="w-3 h-3" /> Restore
                  </button>
                <% else %>
                  <%= if is_locked_by_other do %>
                    <!-- Avatar and lock indicator when locked by others -->
                    <div
                      class="absolute -left-7 top-1 flex items-center gap-1 not-prose"
                      title={"Being edited by #{locked_by_user && locked_by_user.name}"}
                    >
                      <%= if locked_by_user do %>
                        <div class="inline-grid *:[grid-area:1/1]">
                          <div class="status status-warning animate-ping w-6 h-6"></div>
                          <div class="avatar">
                            <div class="w-6 h-6 rounded-full">
                              <.profile_image src={locked_by_user.avatar} alt={locked_by_user.name} />
                            </div>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% else %>
                    <!-- Edited indicator -->
                    <%= if is_edited do %>
                      <div
                        class="absolute -left-6 top-2 text-info flex items-center gap-1"
                        title="This section has been edited"
                      >
                        <.icon name="hero-pencil-square" class="w-4 h-4" />
                      </div>
                    <% end %>
                    <!-- Edit button on hover -->
                    <button
                      phx-click="lock_section"
                      phx-value-section-id={section["id"]}
                      phx-target={@myself}
                      class="absolute right-0 top-0 opacity-0 group-hover/section:opacity-100 transition-opacity btn btn-sm"
                      title="Edit this section"
                    >
                      <.icon name="hero-pencil" class="w-3 h-3" /> Edit
                    </button>
                  <% end %>
                <% end %>
                
    <!-- Regular prose content -->
                <div class={"section-content #{if section["deleted"], do: "line-through opacity-30"}"}>
                  <%= if section["content"] == "" do %>
                    <p class="text-base-content/40 italic text-sm">Empty section</p>
                  <% else %>
                    {raw(render_markdown(section["content"]))}
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(:issue, assigns.issue)
     |> assign(:current_user_id, assigns.current_user_id)
     |> assign(:session_id, assigns.session_id)
     |> assign(:participants, Map.get(assigns, :participants, []))}
  end

  @impl true
  def handle_event("lock_section", %{"section-id" => section_id}, socket) do
    case Planning.lock_section(
           socket.assigns.session_id,
           section_id,
           socket.assigns.current_user_id
         ) do
      :ok ->
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not lock section")}
    end
  end

  @impl true
  def handle_event("unlock_section", %{"section-id" => section_id}, socket) do
    case Planning.unlock_section(
           socket.assigns.session_id,
           section_id,
           socket.assigns.current_user_id
         ) do
      :ok ->
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not unlock section")}
    end
  end

  @impl true
  def handle_event("cancel_section_edit", %{"section-id" => section_id}, socket) do
    case Planning.cancel_section_edit(
           socket.assigns.session_id,
           section_id,
           socket.assigns.current_user_id
         ) do
      :ok ->
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not cancel section edit")}
    end
  end

  @impl true
  def handle_event(
        "update_section_content",
        %{"section_id" => section_id, "content" => content},
        socket
      ) do
    case Planning.update_section_content(
           socket.assigns.session_id,
           section_id,
           content,
           socket.assigns.current_user_id
         ) do
      :ok ->
        {:noreply, socket}

      {:error, reason} ->
        # Log error for debugging while maintaining silent UX for live updates
        Logger.warning(
          "Failed to update section content: session_id=#{socket.assigns.session_id}, " <>
            "section_id=#{section_id}, user_id=#{socket.assigns.current_user_id}, reason=#{inspect(reason)}"
        )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_section", %{"section-id" => section_id}, socket) do
    case Planning.delete_section(
           socket.assigns.session_id,
           section_id,
           socket.assigns.current_user_id
         ) do
      :ok ->
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not delete section")}
    end
  end

  @impl true
  def handle_event("restore_section", %{"section-id" => section_id}, socket) do
    case Planning.restore_section(socket.assigns.session_id, section_id) do
      :ok ->
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not restore section")}
    end
  end

  # Helpers

  defp render_markdown(content) do
    case Earmark.as_html(content) do
      {:ok, html, _} ->
        # Sanitize HTML to prevent XSS attacks
        HtmlSanitizeEx.basic_html(html)

      {:error, _html, _errors} ->
        "<p>Error rendering markdown</p>"
    end
  end
end
