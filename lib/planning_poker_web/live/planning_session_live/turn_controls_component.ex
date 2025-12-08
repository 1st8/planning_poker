defmodule PlanningPokerWeb.PlanningSessionLive.TurnControlsComponent do
  use PlanningPokerWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-8 bg-base-100 border-8 border-neutral p-8">
      <div class="flex flex-col gap-8">
        <h2 class="font-bold bg-neutral text-neutral-content uppercase -m-8 mb-0 px-8 py-2 border-b-8 border-neutral">
          Deine Runde
        </h2>
        <div class="flex flex-col gap-4">
          <%= if @is_my_turn do %>
            <div class="flex items-center gap-2 text-success font-medium">
              <.icon name="hero-hand-raised" class="w-6 h-6" />
              <span class="text-lg">Du bist dran!</span>
            </div>
          <% else %>
            <div class="flex items-center gap-2 text-base-content/70">
              <.icon name="hero-clock" class="w-6 h-6" />
              <span class="text-lg">
                <%= if @active_participant do %>
                  <strong><%= @active_participant.name %></strong> ist dran...
                <% else %>
                  Warte auf Teilnehmer...
                <% end %>
              </span>
            </div>
          <% end %>
          <button
            class="btn btn-primary btn-lg text-lg btn-shadow w-full"
            phx-click="end_turn"
            id="end-turn-btn"
            disabled={!@is_my_turn}
          >
            Bin fertig
          </button>
        </div>
      </div>
    </div>
    """
  end
end
