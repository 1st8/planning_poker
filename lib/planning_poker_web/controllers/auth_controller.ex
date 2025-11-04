defmodule PlanningPokerWeb.AuthController do
  @moduledoc """
  Auth controller responsible for handling Ueberauth responses and mock authentication
  """

  use PlanningPokerWeb, :controller

  plug Ueberauth when action in [:request, :callback]

  alias PlanningPoker.{UserFromAuth, IssueProvider}

  @doc """
  Initiates the OAuth request with the provider.
  The Ueberauth plug handles the actual redirect to the OAuth provider.
  """
  def request(conn, _params) do
    # Ueberauth plug will handle the redirect
    conn
  end

  @doc """
  Mock authentication for local development.
  Logs in as one of the predefined mock users (alice, bob, carol).
  Only available when using the Mock issue provider.
  """
  def mock_callback(conn, %{"username" => username}) do
    if IssueProvider.get_provider() == PlanningPoker.IssueProviders.Mock do
      case PlanningPoker.IssueProviders.Mock.get_user(username) do
        nil ->
          conn
          |> put_flash(:error, "Unknown mock user: #{username}. Available: alice, bob, carol")
          |> redirect(to: "/")

        user ->
          conn
          |> put_session(:current_user, user)
          |> put_session(:token, "mock-token-#{username}")
          |> configure_session(renew: true)
          |> put_flash(:info, "Logged in as #{user.name} (mock)")
          |> redirect(to: "/")
      end
    else
      conn
      |> put_flash(:error, "Mock authentication is only available with ISSUE_PROVIDER=mock")
      |> redirect(to: "/")
    end
  end

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
