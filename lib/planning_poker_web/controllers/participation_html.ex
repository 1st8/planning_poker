defmodule PlanningPokerWeb.ParticipationHTML do
  @moduledoc """
  This module contains participations rendered by ParticipationController.

  See the `participation_html` directory for all templates available.
  """
  use PlanningPokerWeb, :html

  embed_templates "participation_html/*"
end
