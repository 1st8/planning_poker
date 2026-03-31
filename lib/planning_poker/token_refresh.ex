defmodule PlanningPoker.TokenRefresh do
  @moduledoc """
  Handles OAuth2 token refresh for GitLab access tokens.
  """

  require Logger

  alias PlanningPoker.TokenCredentials

  @doc """
  Attempts to refresh the token using the OAuth2 refresh_token grant.

  Returns `{:ok, new_credentials}` on success, or `{:error, reason}` on failure.
  Possible error reasons:
  - `:no_refresh_token` - credentials have no refresh_token
  - `:token_revoked` - GitLab rejected the refresh (token revoked or expired)
  - other - transient/network errors
  """
  def refresh(%TokenCredentials{refresh_token: nil}), do: {:error, :no_refresh_token}

  def refresh(%TokenCredentials{refresh_token: refresh_token}) do
    config = Application.fetch_env!(:ueberauth, Ueberauth.Strategy.Gitlab.OAuth)
    site = System.get_env("GITLAB_SITE", "https://gitlab.com")

    client =
      OAuth2.Client.new(
        strategy: OAuth2.Strategy.Refresh,
        client_id: config[:client_id],
        client_secret: config[:client_secret],
        site: site,
        token_url: "#{site}/oauth/token",
        serializers: %{"application/json" => Jason}
      )
      |> OAuth2.Client.put_param(:refresh_token, refresh_token)

    case OAuth2.Client.get_token(client) do
      {:ok, %{token: %OAuth2.AccessToken{access_token: access_token} = token}}
      when is_binary(access_token) and access_token != "" ->
        Logger.debug("GitLab token refreshed successfully")

        {:ok,
         %TokenCredentials{
           access_token: token.access_token,
           refresh_token: token.refresh_token || refresh_token,
           expires_at: token.expires_at
         }}

      {:ok, %{token: _token}} ->
        Logger.error("GitLab token refresh returned empty access token")
        {:error, :token_revoked}

      {:error, %OAuth2.Response{status_code: status}} when status in [400, 401, 403] ->
        Logger.error("GitLab token refresh rejected with status #{status}")
        {:error, :token_revoked}

      {:error, reason} ->
        Logger.error("GitLab token refresh failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
