defmodule PlanningPoker.Presence do
  use Phoenix.Presence,
    otp_app: :planning_poker,
    pubsub_server: PlanningPoker.PubSub
end
