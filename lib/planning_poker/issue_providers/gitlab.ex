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
        projectId
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

    case Tesla.post(client, "/api/graphql", %{
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
    case Tesla.post(client, "/api/graphql", %{
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

  @doc """
  Updates a GitLab issue with new attributes.

  Uses the REST API endpoint: PUT /projects/:id/issues/:issue_iid

  ## Arguments

  - `client` - Tesla client from `client/1`
  - `project_id` - Project ID or path (e.g., "1st8/planning_poker" or "42")
  - `issue_iid` - Issue internal ID (e.g., "123" for #123)
  - `attrs` - Map of attributes to update (supports: description, title, labels, etc.)

  ## Returns

  - `{:ok, issue}` where issue is the updated issue map
  - `{:error, reason}` on failure

  ## Example

      iex> client = Gitlab.client(token: "oauth-token")
      iex> Gitlab.update_issue(client, "1st8/planning_poker", "42", %{description: "Updated"})
      {:ok, %{"id" => 123, "iid" => 42, "description" => "Updated", ...}}
  """
  @impl PlanningPoker.IssueProvider
  def update_issue(client, project_id, issue_iid, attrs) do
    # URL-encode the project_id to handle paths like "1st8/planning_poker"
    encoded_project_id = URI.encode_www_form(project_id)
    path = "/api/v4/projects/#{encoded_project_id}/issues/#{issue_iid}"

    case Tesla.put(client, path, attrs) do
      {:ok, env} ->
        issue = env.body

        if issue do
          # Convert REST API response to match GraphQL format
          enhanced_issue =
            issue
            |> normalize_rest_issue()
            |> Map.put(:base_url, System.get_env("GITLAB_SITE", "https://gitlab.com"))

          Logger.debug("Updated issue #{issue_iid} in project #{project_id}")
          {:ok, enhanced_issue}
        else
          {:error, :not_found}
        end

      {:error, reason} = error ->
        Logger.error("Failed to update issue #{issue_iid}: #{inspect(reason)}")
        error
    end
  end

  # Private helper to normalize REST API response to match GraphQL format
  defp normalize_rest_issue(issue) do
    %{
      "id" => "gid://gitlab/Issue/#{issue["id"]}",
      "iid" => to_string(issue["iid"]),
      "projectId" => issue["project_id"],
      "title" => issue["title"],
      "description" => issue["description"],
      "descriptionHtml" => issue["description_html"],
      "referencePath" => issue["references"]["full"],
      "webUrl" => issue["web_url"],
      "author" => %{"name" => get_in(issue, ["author", "name"])},
      "createdAt" => issue["created_at"]
    }
    |> maybe_add_epic(issue)
  end

  defp maybe_add_epic(result, issue) do
    case issue["epic"] do
      nil ->
        result

      epic ->
        Map.put(result, "epic", %{"title" => epic["title"], "reference" => epic["reference"]})
    end
  end
end
