defmodule PlanningPokerWeb.PlanningSessionLive.ReadinessControlsComponent do
  use PlanningPokerWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-8 bg-base-100 border-8 border-neutral p-8">
      <div class="flex flex-col gap-8">
        <h2 class="font-bold bg-neutral text-neutral-content uppercase -m-8 mb-0 px-8 py-2 border-b-8 border-neutral">
          Your Readiness
        </h2>
        <div class="flex flex-col gap-2">
          <%= for {emoji, label, value} <- readiness_options() do %>
            <button
              class={
                "btn btn-primary #{(@current_participant[:readiness] == value && "btn-accent btn-active") || ""} btn-lg text-lg btn-shadow justify-start"
              }
              value={value}
              phx-click="set_readiness"
            >
              <span class="text-2xl"><%= emoji %></span>
              <span><%= label %></span>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp readiness_options do
    [
      {"🤔", "huh?", "huh"},
      {"😕", "umm...", "umm"},
      {"🤷", "okay I guess", "okay"},
      {"👍", "pretty clear", "clear"},
      {"🎯", "10/10 got it", "got_it"}
    ]
  end
end
