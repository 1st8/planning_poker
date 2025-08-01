defmodule PlanningPokerWeb.AuthController do
  @moduledoc """
  Auth controller responsible for handling Ueberauth responses
  """

  use PlanningPokerWeb, :controller

  plug Ueberauth

  # alias Ueberauth.Strategy.Helpers
  alias PlanningPoker.UserFromAuth

  # def request(conn, _params) do
  #   render(conn, "request.html", callback_url: Helpers.callback_url(conn))
  # end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "You have been logged out!")
    |> clear_session()
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: "/")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case UserFromAuth.find_or_create(auth) do
      {:ok, user} ->
        conn
        |> put_session(:current_user, user)
        |> put_session(:token, auth.credentials.token)
        |> configure_session(renew: true)
        |> redirect(to: "/")

      # {:error, reason} ->
      #   conn
      #   |> put_flash(:error, reason)
      #   |> redirect(to: "/")
    end
  end
end
