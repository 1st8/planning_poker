defmodule PlanningPokerWeb.PlanningSessionLive.ParticipantsListComponent do
  use PlanningPokerWeb, :live_component

  def render(assigns) do
    ~H"""
    <aside>
      <.layout_box title="Participants">
        <ul class="flex flex-col gap-1">
          <%= for participant <- @participants do %>
            <li class="flex items-center gap-2 relative">
              <div class="avatar h-10 w-10">
                <img class={"mask mask-squircle #{if participant[:vote], do: "blur-sm grayscale", else: ""}"} src={participant.avatar} aria-hidden="true" />
                <%= if participant[:vote] do %>
                  <.icon name="hero-check-badge-solid" class="text-success absolute h-10 w-10" />
                <% end %>
              </div>
              <%= render_name(participant, @participants) %>
            </li>
          <% end %>
        </ul>
        <:controls>
          <a class="btn btn-secondary btn-sm" href="/participate" title="Settings">
            <.icon name="hero-cog-6-tooth-mini" />
          </a>
        </:controls>
      </.layout_box>
    </aside>
    """
  end

  # Helper function to render participant names
  def render_name(participant, participants) do
    first_name = participant.name |> String.split(" ") |> List.first()
    occurrences = Enum.count(participants, fn p -> String.split(p.name, " ") |> List.first() == first_name end)

    if occurrences > 1 do
      last_name_initial = participant.name |> String.split(" ") |> List.last() |> String.first()
      "#{first_name} #{last_name_initial}."
    else
      first_name
    end
  end
end
