defmodule PlanningPoker.IssueProviders.Gitlab do
  @moduledoc """
  GitLab issue provider adapter.

  Integrates with GitLab's GraphQL API to fetch issues from a configured board list.

  ## Configuration

  Requires the following environment variables:
  - `GITLAB_SITE` - GitLab instance URL (defaults to "https://gitlab.com")
  - `DEFAULT_LIST_ID` - Board list ID to fetch issues from (defaults to 9_945_417)

  ## Authentication

  Uses OAuth access tokens obtained through the GitLab OAuth flow.
  The token must be passed when creating the client:

      client = Gitlab.client(token: user_token)
  """

  use Tesla
  require Logger

  @behaviour PlanningPoker.IssueProvider

  @board_list_query """
    query ListIssues($listId: ListID!, $filters: BoardIssueInput!) {
      boardList(id: $listId) {
        issues(filters: $filters) {
          nodes {
            id
            title
            referencePath: reference(full: true)
            webUrl
          }
        }
      }
    }
  """

  @get_issue_query """
    query GetIssue($issueId: IssueID!) {
      issue(id: $issueId) {
        id
        iid
        title
        description
        descriptionHtml
        referencePath: reference(full: true)
        webUrl
        epic {
          title
          reference: reference(full: true)
        }
        author {
          name
        }
        createdAt
      }
    }
  """

  @impl PlanningPoker.IssueProvider
  def client(opts \\ []) do
    token = Keyword.fetch!(opts, :token)

    middleware = [
      {Tesla.Middleware.BaseUrl, System.get_env("GITLAB_SITE", "https://gitlab.com")},
      {Tesla.Middleware.Headers, [{"AUTHORIZATION", "Bearer #{token}"}]},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end

  @doc """
  Fetches issues from a GitLab board list.

  Returns a list of issues with basic information suitable for the planning session lobby.
  Only fetches issues without estimates (weight: "None" filter).

  ## Options

  - `:list_id` - The board list ID to fetch from (defaults to DEFAULT_LIST_ID env var or 9_945_417)

  ## Returns

  - `{:ok, issues}` where issues is a list of maps with id, title, referencePath, webUrl
  - `{:error, reason}` on failure

  ## Example

      iex> client = Gitlab.client(token: "oauth-token")
      iex> {:ok, issues} = Gitlab.fetch_issues(client, list_id: 9_945_417)
      {:ok, [
        %{
          "id" => "gid://gitlab/Issue/96438580",
          "referencePath" => "1st8/planning_poker#1",
          "title" => "Add feature X",
          "webUrl" => "https://gitlab.com/1st8/planning_poker/-/issues/1"
        }
      ]}
  """
  @impl PlanningPoker.IssueProvider
  def fetch_issues(client, opts \\ []) do
    # default id is "Open" list of https://gitlab.com/1st8/planning_poker/-/boards/3468418
    list_id = Keyword.get(opts, :list_id, System.get_env("DEFAULT_LIST_ID") || 9_945_417)

    case post(client, "/api/graphql", %{
           operationName: "ListIssues",
           variables: %{
             filters: %{weight: "None"},
             listId: "gid://gitlab/List/#{list_id}"
           },
           query: @board_list_query
         }) do
      {:ok, env} ->
        issues =
          get_in(env.body, [
            "data",
            "boardList",
            "issues",
            "nodes"
          ]) || []

        Logger.debug("Fetched #{Enum.count(issues)} issues list_id=#{inspect(list_id)}")
        {:ok, issues}

      {:error, reason} = error ->
        Logger.error("Failed to fetch issues: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Fetches detailed information for a specific GitLab issue.

  ## Arguments

  - `client` - Tesla client from `client/1`
  - `issue_id` - GitLab global ID (e.g., "gid://gitlab/Issue/123")
  - `opts` - Additional options (currently unused)

  ## Returns

  - `{:ok, issue}` where issue contains full details including description, epic, author, etc.
  - `{:error, reason}` on failure

  The returned issue map includes:
  - All fields from the GraphQL query
  - `:base_url` - The GitLab instance base URL (atom key)
  - `"sections"` - Parsed issue sections for collaborative editing (if IssueSection module available)
  """
  @impl PlanningPoker.IssueProvider
  def fetch_issue(client, issue_id, _opts \\ []) do
    case post(client, "/api/graphql", %{
           operationName: "GetIssue",
           variables: %{
             issueId: issue_id
           },
           query: @get_issue_query
         }) do
      {:ok, env} ->
        issue =
          get_in(env.body, [
            "data",
            "issue"
          ])

        if issue do
          enhanced_issue =
            Map.put(issue, :base_url, System.get_env("GITLAB_SITE", "https://gitlab.com"))

          {:ok, enhanced_issue}
        else
          {:error, :not_found}
        end

      {:error, reason} = error ->
        Logger.error("Failed to fetch issue #{issue_id}: #{inspect(reason)}")
        error
    end
  end
end
