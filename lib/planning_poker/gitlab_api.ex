defmodule PlanningPoker.GitlabApi do
  use Tesla

  def default_client do
    middleware = [
      {Tesla.Middleware.BaseUrl, System.fetch_env!("GITLAB_URL")},
      {Tesla.Middleware.Headers, [{"PRIVATE-TOKEN", System.fetch_env!("GITLAB_API_TOKEN")}]},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end

  @list_issues_query ~S"""
    query ListIssues(
      $fullPath: ID!,
      $boardId: ID!,
      $id: ID,
      $filters: BoardIssueInput,
      $isGroup: Boolean = false,
      $isProject: Boolean = false,
      $after: String,
      $first: Int
    ) {
      group(fullPath: $fullPath) @include(if: $isGroup) {
        board(id: $boardId) {
          lists(id: $id, issueFilters: $filters) {
            nodes {
              id
              issuesCount
              issues(first: $first, filters: $filters, after: $after) {
                edges {
                  node {
                    ...IssueNode
                    __typename
                  }
                  __typename
                }
                pageInfo {
                  endCursor
                  hasNextPage
                  __typename
                }
                __typename
              }
              __typename
            }
            __typename
          }
          __typename
        }
        __typename
      }
      project(fullPath: $fullPath) @include(if: $isProject) {
        board(id: $boardId) {
          lists(id: $id, issueFilters: $filters) {
            nodes {
              id
              issuesCount
              issues(first: $first, filters: $filters, after: $after) {
                edges {
                  node {
                    ...IssueNode
                    __typename
                  }
                  __typename
                }
                pageInfo {
                  endCursor
                  hasNextPage
                  __typename
                }
                __typename
              }
              __typename
            }
            __typename
          }
          __typename
        }
        __typename
      }
    }

    fragment IssueNode on Issue {
      id
      iid
      title
      referencePath: reference(full: true)
      dueDate
      timeEstimate
      totalTimeSpent
      humanTimeEstimate
      humanTotalTimeSpent
      weight
      confidential
      webUrl
      blocked
      blockedByCount
      relativePosition
      epic {
        id
        __typename
      }
      assignees {
        nodes {
          ...User
          __typename
        }
        __typename
      }
      labels {
        nodes {
          id
          title
          color
          description
          __typename
        }
        __typename
      }
      __typename
    }

    fragment User on User {
      id
      avatarUrl
      name
      username
      webUrl
      __typename
    }
  """

  def fetch_issues(client, opts \\ []) do
    board_id = Keyword.get(opts, :board_id, 15)
    list_id = Keyword.get(opts, :list_id, 68)

    {:ok, env} =
      post(client, "/api/graphql", %{
        operationName: "ListIssues",
        variables: %{
          isGroup: true,
          isProject: false,
          fullPath: "tixxt",
          boardId: "gid://gitlab/Board/#{board_id}",
          filters: %{not: %{}, weight: "None"},
          id: "gid://gitlab/List/#{list_id}"
        },
        query: @list_issues_query
      })

    issues =
      get_in(env.body, [
        "data",
        "group",
        "board",
        "lists",
        "nodes",
        Access.at(0),
        "issues",
        "edges"
      ])
      |> get_nodes_from_edges
      |> Enum.map(fn issue ->
        issue
        |> Map.merge(%{
          "labels" =>
            issue["labels"]
            |> get_nodes_from_connection()
            |> Enum.map(&Map.take(&1, ["title", "color"])),
          "assignees" =>
            issue["assignees"]
            |> get_nodes_from_connection()
            |> Enum.map(&Map.take(&1, ["name", "webUrl", "avatarUrl"]))
        })
        |> Map.take(["title", "referencePath", "webUrl", "labels", "assignees"])
      end)

    issues
  end

  defp get_nodes_from_edges(edges) do
    Enum.map(edges, fn edge -> edge["node"] end)
  end

  defp get_nodes_from_connection(connection) do
    connection["nodes"]
  end
end
