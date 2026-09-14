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
end
