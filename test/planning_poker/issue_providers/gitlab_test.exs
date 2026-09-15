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

    test "carries the comment count into the list" do
      mock_list([rest_list_issue(%{"user_notes_count" => 3})])

      assert {:ok, [issue]} = Gitlab.fetch_issues(Gitlab.client(token: "t"), group: "acme")

      assert issue["commentCount"] == 3
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

  describe "fetch_issue/3 comments" do
    defp graphql_issue(notes) do
      %{
        "data" => %{
          "issue" => %{
            "id" => "gid://gitlab/Issue/8075",
            "title" => "VDT: 3 ELO Themen",
            "notes" => %{"nodes" => notes}
          }
        }
      }
    end

    defp note(attrs) do
      Map.merge(
        %{
          "id" => "gid://gitlab/Note/1",
          "body" => "a comment",
          "system" => false,
          "internal" => false,
          "createdAt" => "2026-09-15T11:09:00Z",
          "author" => %{"name" => "Stefan Bosch"}
        },
        attrs
      )
    end

    defp fetch(body) do
      Tesla.Mock.mock(fn %{method: :post} -> %Tesla.Env{status: 200, body: body} end)
      Gitlab.fetch_issue(Gitlab.client(token: "t"), "gid://gitlab/Issue/8075")
    end

    test "keeps only the notes a person wrote" do
      notes = [
        note(%{"id" => "n1", "body" => "set status to **To do**", "system" => true}),
        note(%{"id" => "n2", "body" => "MR draft für duplikate: https://example/1"}),
        note(%{"id" => "n3", "body" => "assigned to @kundenbetreuung", "system" => true}),
        note(%{"id" => "n4", "body" => "changed the description", "system" => true})
      ]

      assert {:ok, issue} = fetch(graphql_issue(notes))

      assert [%{"id" => "n2", "body" => "MR draft für duplikate: https://example/1"}] =
               issue["comments"]
    end

    test "drops internal notes" do
      notes = [
        note(%{"id" => "public", "body" => "visible"}),
        note(%{"id" => "hidden", "body" => "team only", "internal" => true})
      ]

      assert {:ok, issue} = fetch(graphql_issue(notes))

      assert [%{"id" => "public"}] = issue["comments"]
    end

    test "returns comments oldest first regardless of the order received" do
      notes = [
        note(%{"id" => "later", "createdAt" => "2026-09-15T11:44:09Z"}),
        note(%{"id" => "earlier", "createdAt" => "2026-09-04T11:16:07Z"}),
        note(%{"id" => "middle", "createdAt" => "2026-09-15T11:09:00Z"})
      ]

      assert {:ok, issue} = fetch(graphql_issue(notes))

      assert ["earlier", "middle", "later"] = Enum.map(issue["comments"], & &1["id"])
    end

    test "carries author and timestamp through" do
      assert {:ok, issue} = fetch(graphql_issue([note(%{})]))

      assert [comment] = issue["comments"]
      assert comment["author"] == %{"name" => "Stefan Bosch"}
      assert comment["createdAt"] == "2026-09-15T11:09:00Z"
    end

    test "yields an empty list when the issue has only system notes" do
      assert {:ok, issue} = fetch(graphql_issue([note(%{"system" => true})]))

      assert issue["comments"] == []
    end

    test "yields an empty list when the issue carries no notes at all" do
      body = %{"data" => %{"issue" => %{"id" => "gid://gitlab/Issue/8075", "title" => "Bare"}}}

      assert {:ok, issue} = fetch(body)

      assert issue["comments"] == []
    end
  end
end
