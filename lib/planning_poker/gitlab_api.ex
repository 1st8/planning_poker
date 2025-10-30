defmodule PlanningPoker.GitlabApi do
  use Tesla
  require Logger

  def default_client(token: token) do
    middleware = [
      {Tesla.Middleware.BaseUrl, System.get_env("GITLAB_SITE", "https://gitlab.com")},
      {Tesla.Middleware.Headers, [{"AUTHORIZATION", "Bearer #{token}"}]},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end

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

  @doc """
  returns something like
    [
      %{
        "id" => "gid://gitlab/Issue/96438580",
        "iid" => "1",
        "referencePath" => "1st8/planning_poker#1",
        "title" => "Configurable issue source (Project/Group, Board, List)",
        "webUrl" => "https://gitlab.com/1st8/planning_poker/-/issues/1"
      }
    ]
  """
  def fetch_issues(client, opts \\ []) do
    # default id is "Open" list of https://gitlab.com/1st8/planning_poker/-/boards/3468418
    list_id = Keyword.get(opts, :list_id, System.get_env("DEFAULT_LIST_ID") || 9_945_417)

    {:ok, env} =
      post(client, "/api/graphql", %{
        operationName: "ListIssues",
        variables: %{
          filters: %{weight: "None"},
          listId: "gid://gitlab/List/#{list_id}"
        },
        query: @board_list_query
      })

    issues =
      get_in(env.body, [
        "data",
        "boardList",
        "issues",
        "nodes"
      ]) || []

    Logger.debug("Fetched #{Enum.count(issues)} issues list_id=#{inspect(list_id)}")

    issues
  end

  def fetch_issue(client, issue_id, _opts \\ []) do
    {:ok, env} =
      post(client, "/api/graphql", %{
        operationName: "GetIssue",
        variables: %{
          issueId: issue_id
        },
        query: @get_issue_query
      })

    get_in(env.body, [
      "data",
      "issue"
    ])
    |> Map.put(:base_url, System.get_env("GITLAB_SITE", "https://gitlab.com"))
  end
end
