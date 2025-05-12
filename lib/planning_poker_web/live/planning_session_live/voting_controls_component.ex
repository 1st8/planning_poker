defmodule PlanningPokerWeb.PlanningSessionLive.VotingControlsComponent do
  use PlanningPokerWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-8 bg-base-100 border-8 border-neutral p-8">
      <div class="flex flex-col gap-8">
        <h2 class="font-bold bg-neutral text-neutral-content uppercase -m-8 mb-0 px-8 py-2 border-b-8 border-neutral">
          Your Vote
        </h2>
        <div class="grid lg:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4 gap-2 lg:gap-4">
          <%= for option <- @options do %>
            <button
              class={
                "btn btn-primary #{(@current_participant[:vote] == option && "btn-accent btn-active") || ""} btn-lg text-2xl btn-shadow"
              }
              value={option}
              phx-click="cast_vote"
            >
              <%= option %>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
