defmodule PlanningPokerWeb.PlanningSessionLive.TurnControlsComponent do
  use PlanningPokerWeb, :live_component

  def render(assigns) do
    ~H"""
    <aside>
      <.layout_box title="Deine Runde">
        <%= if @is_my_turn do %>
          <div class="flex items-center gap-2 text-success font-medium mb-4">
            <.icon name="hero-hand-raised" class="w-5 h-5" />
            <span>Du bist dran!</span>
          </div>
        <% else %>
          <div class="flex items-center gap-2 text-base-content/70 mb-4">
            <.icon name="hero-clock" class="w-5 h-5" />
            <span>
              <%= if @active_participant do %>
                <strong><%= @active_participant.name %></strong> ist dran...
              <% else %>
                Warte auf Teilnehmer...
              <% end %>
            </span>
          </div>
        <% end %>
        <button
          class="btn btn-secondary w-full"
          phx-click="end_turn"
          id="end-turn-btn"
          disabled={!@is_my_turn}
        >
          Bin fertig
        </button>
      </.layout_box>
    </aside>
    """
  end
end
