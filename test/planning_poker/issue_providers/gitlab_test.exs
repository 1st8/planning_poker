defmodule PlanningPoker.IssueProviders.GitlabTest do
  use ExUnit.Case, async: true

  alias PlanningPoker.IssueProviders.Gitlab

  defp rest_list_issue(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => 42,
        "iid" => 7,
        "title" => "Add user profile page",
        "web_url" => "https://gitlab.com/acme/app/-/issues/7",
        "references" => %{"full" => "acme/app#7"},
        "author" => %{"name" => "Alice Anderson", "username" => "alice"},
        "created_at" => "2024-01-15T10:00:00.000Z"
      },
      overrides
    )
  end

  defp mock_list(body) do
    Tesla.Mock.mock(fn %{method: :get, url: url} ->
      assert url =~ "/api/v4/groups/acme/issues"
      %Tesla.Env{status: 200, body: body}
    end)
  end

  describe "fetch_issues/2" do
    test "carries the author and creation date into the list" do
      mock_list([rest_list_issue()])

      assert {:ok, [issue]} = Gitlab.fetch_issues(Gitlab.client(token: "t"), group: "acme")

      assert issue["author"] == %{"name" => "Alice Anderson"}
      assert issue["createdAt"] == "2024-01-15T10:00:00.000Z"
    end

    test "still normalizes the fields the lobby already relied on" do
      mock_list([rest_list_issue()])

      assert {:ok, [issue]} = Gitlab.fetch_issues(Gitlab.client(token: "t"), group: "acme")

      assert issue["id"] == "gid://gitlab/Issue/42"
      assert issue["title"] == "Add user profile page"
      assert issue["referencePath"] == "acme/app#7"
      assert issue["webUrl"] == "https://gitlab.com/acme/app/-/issues/7"
    end

    test "tolerates an issue without an author" do
      mock_list([rest_list_issue(%{"author" => nil})])

      assert {:ok, [issue]} = Gitlab.fetch_issues(Gitlab.client(token: "t"), group: "acme")

      assert issue["author"] == %{"name" => nil}
      assert PlanningPokerWeb.PlanningComponents.byline_text(issue) == "Created on 15 Jan 2024"
    end

    test "returns an unauthorized error when the token is rejected" do
      Tesla.Mock.mock(fn %{method: :get} -> %Tesla.Env{status: 401, body: %{}} end)

      assert {:error, :unauthorized} =
               Gitlab.fetch_issues(Gitlab.client(token: "t"), group: "acme")
    end
  end

  describe "fetch_issue/3" do
    # Shaped after a real response from the GitLab instance this runs against:
    # the widget list is mostly empty objects, and only the custom fields widget
    # carries a payload.
    defp graphql_issue(widgets) do
      %{
        "data" => %{
          "issue" => %{
            "id" => "gid://gitlab/Issue/8075",
            "iid" => "483",
            "title" => "Deutscher Text im englischen UI",
            "webUrl" => "https://gitlab.example/tixxt/core/-/issues/483"
          },
          "workItem" => %{"widgets" => widgets}
        }
      }
    end

    defp priority_widgets(value) do
      [
        %{},
        %{},
        %{
          "customFieldValues" => [
            %{
              "customField" => %{"name" => "Priority"},
              "selectedOptions" => [%{"value" => value}]
            }
          ]
        },
        %{}
      ]
    end

    defp mock_graphql(body, assert_variables \\ fn _ -> :ok end) do
      Tesla.Mock.mock(fn %{method: :post, url: url, body: request_body} ->
        assert url =~ "/api/graphql"
        assert_variables.(Jason.decode!(request_body)["variables"])
        %Tesla.Env{status: 200, body: body}
      end)
    end

    test "reads the Priority custom field off the work item" do
      mock_graphql(graphql_issue(priority_widgets("Low - Nice to Have")))

      assert {:ok, issue} =
               Gitlab.fetch_issue(Gitlab.client(token: "t"), "gid://gitlab/Issue/8075")

      assert issue["priority"] == "Low - Nice to Have"
    end

    test "asks for the work item under the id the issue shares with it" do
      mock_graphql(graphql_issue(priority_widgets("High - Next Sprint")), fn variables ->
        assert variables["issueId"] == "gid://gitlab/Issue/8075"
        assert variables["workItemId"] == "gid://gitlab/WorkItem/8075"
      end)

      assert {:ok, _issue} =
               Gitlab.fetch_issue(Gitlab.client(token: "t"), "gid://gitlab/Issue/8075")
    end

    test "leaves priority nil when the field is defined but unset" do
      widgets = [%{"customFieldValues" => [%{"customField" => %{"name" => "Priority"}}]}]
      mock_graphql(graphql_issue(widgets))

      assert {:ok, issue} =
               Gitlab.fetch_issue(Gitlab.client(token: "t"), "gid://gitlab/Issue/8075")

      assert issue["priority"] == nil
    end

    test "leaves priority nil when another custom field is set but Priority is not" do
      widgets = [
        %{
          "customFieldValues" => [
            %{
              "customField" => %{"name" => "Team"},
              "selectedOptions" => [%{"value" => "Platform"}]
            }
          ]
        }
      ]

      mock_graphql(graphql_issue(widgets))

      assert {:ok, issue} =
               Gitlab.fetch_issue(Gitlab.client(token: "t"), "gid://gitlab/Issue/8075")

      assert issue["priority"] == nil
    end

    test "still returns the issue when the instance has no work item widgets at all" do
      body = %{
        "data" => %{
          "issue" => %{"id" => "gid://gitlab/Issue/8075", "title" => "No custom fields here"},
          "workItem" => nil
        }
      }

      mock_graphql(body)

      assert {:ok, issue} =
               Gitlab.fetch_issue(Gitlab.client(token: "t"), "gid://gitlab/Issue/8075")

      assert issue["title"] == "No custom fields here"
      assert issue["priority"] == nil
    end

    test "returns an unauthorized error when the token is rejected" do
      Tesla.Mock.mock(fn %{method: :post} -> %Tesla.Env{status: 401, body: %{}} end)

      assert {:error, :unauthorized} =
               Gitlab.fetch_issue(Gitlab.client(token: "t"), "gid://gitlab/Issue/8075")
    end
  end
end
