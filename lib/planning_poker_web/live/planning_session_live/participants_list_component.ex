defmodule PlanningPokerWeb.PlanningSessionLive.ParticipantsListComponent do
  use PlanningPokerWeb, :live_component

  def render(assigns) do
    # Ensure active_participant_id has a default value
    assigns = assign_new(assigns, :active_participant_id, fn -> nil end)

    ~H"""
    <aside>
      <.layout_box title="Participants">
        <ul class="flex flex-col gap-1">
          <%= for participant <- @participants do %>
            <li class={[
              "flex items-center gap-2 relative p-1",
              participant.id == @active_participant_id && "participant-active"
            ]}>
              <div class="avatar h-10 w-10">
                <.profile_image
                  user={participant}
                  class={"mask mask-squircle #{if participant[:vote], do: "blur-sm grayscale", else: ""}"}
                  aria-hidden="true"
                />
                <%= if participant[:vote] do %>
                  <.icon name="hero-check-badge-solid" class="text-success absolute h-10 w-10" />
                <% end %>
              </div>
              <div class="flex flex-col">
                <span class="flex items-center gap-1">
                  {render_name(participant, @participants)}
                  <%= if participant.id == @active_participant_id do %>
                    <span class="badge badge-primary badge-xs">dran</span>
                  <% end %>
                </span>
                <%= if participant[:readiness] do %>
                  <small class="text-xs opacity-70">
                    {render_readiness(participant[:readiness])}
                  </small>
                <% end %>
              </div>
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

    occurrences =
      Enum.count(participants, fn p -> String.split(p.name, " ") |> List.first() == first_name end)

    if occurrences > 1 do
      last_name_initial = participant.name |> String.split(" ") |> List.last() |> String.first()
      "#{first_name} #{last_name_initial}."
    else
      first_name
    end
  end

  # Helper function to render readiness status
  defp render_readiness(value) do
    case value do
      "huh" -> "🤔 huh?"
      "umm" -> "😕 umm..."
      "okay" -> "🤷 okay I guess"
      "clear" -> "👍 pretty clear"
      "got_it" -> "🎯 10/10 got it"
      _ -> ""
    end
  end
end
