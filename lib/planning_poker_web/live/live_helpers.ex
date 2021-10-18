defmodule PlanningPokerWeb.LiveHelpers do
  import Phoenix.LiveView.Helpers

  @doc """
  Renders a component inside the `PlanningPokerWeb.ModalComponent` component.

  The rendered modal receives a `:return_to` option to properly update
  the URL when the modal is closed.

  ## Examples

      <%= live_modal PlanningPokerWeb.PlanningSessionLive.FormComponent,
        id: @planning_session.id || :new,
        action: @live_action,
        planning_session: @planning_session,
        return_to: Routes.planning_session_index_path(@socket, :index) %>
  """
  def live_modal(component, opts) do
    path = Keyword.fetch!(opts, :return_to)
    modal_opts = [id: :modal, return_to: path, component: component, opts: opts]
    live_component(PlanningPokerWeb.ModalComponent, modal_opts)
  end
end
