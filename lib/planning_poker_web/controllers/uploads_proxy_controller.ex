defmodule PlanningPokerWeb.UploadsProxyController do
  @moduledoc """
  Proxies requests to GitLab uploads to work around cross-domain cookie issues.

  Firefox doesn't send cookies for cross-domain image requests, which causes
  authentication failures when loading GitLab assets. This controller proxies
  the requests using the user's session token.
  """

  use PlanningPokerWeb, :controller
  require Logger

  @doc """
  Fetches an asset from GitLab uploads and streams it to the client.

  The path parameter contains the full path after /proxy/uploads/, which is
  prepended with the GitLab site URL to construct the full asset URL.

  Example:
    Request: /proxy/uploads/-/system/user/avatar/19/avatar.png
    Proxied to: https://gitlab.sys.mixxt.net/uploads/-/system/user/avatar/19/avatar.png
  """
  def fetch(conn, %{"path" => path}) do
    case get_session(conn, :token) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})

      token ->
        # Construct full GitLab URL
        gitlab_site = System.get_env("GITLAB_SITE", "https://gitlab.com")
        url = "#{gitlab_site}/uploads/#{Enum.join(path, "/")}"

        fetch_and_stream(conn, url, token)
    end
  end

  defp fetch_and_stream(conn, url, token) do
    # Create Tesla client with authorization
    client =
      Tesla.client([
        {Tesla.Middleware.Headers, [{"Authorization", "Bearer #{token}"}]}
      ])

    case Tesla.get(client, url) do
      {:ok, %Tesla.Env{status: 200, headers: headers, body: body}} ->
        content_type = get_header_value(headers, "content-type", "application/octet-stream")

        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("cache-control", "public, max-age=3600")
        |> send_resp(200, body)

      {:ok, %Tesla.Env{status: 404}} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Asset not found"})

      {:ok, %Tesla.Env{status: status}} ->
        Logger.warning("Proxy fetch returned status #{status} for URL: #{url}")

        conn
        |> put_status(:bad_gateway)
        |> json(%{error: "Failed to fetch asset (status: #{status})"})

      {:error, reason} ->
        Logger.error("Proxy fetch failed: #{inspect(reason)}")

        conn
        |> put_status(:bad_gateway)
        |> json(%{error: "Failed to fetch asset"})
    end
  end

  defp get_header_value(headers, key, default) do
    Enum.find_value(headers, default, fn {k, v} ->
      if String.downcase(k) == String.downcase(key), do: v
    end)
  end
end
