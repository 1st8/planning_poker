defmodule PlanningPoker.IssueProviders.MockTest do
  use ExUnit.Case, async: true

  alias PlanningPoker.IssueProviders.Mock

  setup do
    # Ensure the Mock GenServer is started
    # In test environment, it should start automatically, but we'll be explicit
    pid = Process.whereis(Mock)

    unless pid do
      {:ok, pid} = Mock.start_link([])
      on_exit(fn -> Process.exit(pid, :normal) end)
    end

    :ok
  end

  describe "client/1" do
    test "creates client with user_id" do
      client = Mock.client(user_id: "alice")
      assert client.provider == :mock
      assert client.user_id == "alice"
    end

    test "creates client from token" do
      client = Mock.client(token: "mock-token-bob")
      assert client.provider == :mock
      assert client.user_id == "bob"
    end

    test "defaults to alice when no opts provided" do
      client = Mock.client()
      assert client.provider == :mock
      assert client.user_id == "alice"
    end
  end

  describe "fetch_issues/2" do
    test "returns list of mock issues" do
      client = Mock.client()
      {:ok, issues} = Mock.fetch_issues(client)

      assert is_list(issues)
      assert length(issues) == 6

      # Check first issue has required fields
      first_issue = List.first(issues)
      assert first_issue["id"]
      assert first_issue["title"]
      assert first_issue["referencePath"]
      assert first_issue["webUrl"]
    end
  end

  describe "fetch_issue/3" do
    test "returns full issue details" do
      client = Mock.client()
      {:ok, issue} = Mock.fetch_issue(client, "mock-issue-1")

      assert issue["id"] == "mock-issue-1"
      assert issue["title"] == "Add user profile page"
      assert issue["description"]
      assert issue["author"]
      assert issue["createdAt"]
      assert issue[:base_url] == "http://localhost:4000"
    end

    test "returns error for unknown issue" do
      client = Mock.client()
      {:error, :not_found} = Mock.fetch_issue(client, "nonexistent")
    end
  end

  describe "get_user/1" do
    test "returns user for valid username" do
      user = Mock.get_user("alice")
      assert user.id == "mock-user-alice"
      assert user.name == "Alice Anderson"
      assert user.email == "alice@example.com"
      assert Map.has_key?(user, :avatar)
    end

    test "returns nil for invalid username" do
      assert Mock.get_user("unknown") == nil
    end
  end

  describe "list_users/0" do
    test "returns all mock users" do
      users = Mock.list_users()
      assert length(users) == 3

      names = Enum.map(users, & &1.name)
      assert "Alice Anderson" in names
      assert "Bob Builder" in names
      assert "Carol Chen" in names
    end
  end

  describe "update_issue/4" do
    test "updates issue description" do
      client = Mock.client()

      # First fetch the original issue
      {:ok, original} = Mock.fetch_issue(client, "mock-issue-1")
      original_description = original["description"]

      # Update the issue
      new_description = "Updated description for testing"
      {:ok, updated} = Mock.update_issue(client, "mock-project", "1", %{description: new_description})

      assert updated["description"] == new_description
      assert updated["id"] == "mock-issue-1"
      assert updated[:base_url] == "http://localhost:4000"

      # Verify the change persists
      {:ok, fetched} = Mock.fetch_issue(client, "mock-issue-1")
      assert fetched["description"] == new_description

      # Verify other fields remain unchanged
      assert fetched["title"] == original["title"]
      assert fetched["author"] == original["author"]
    end

    test "updates multiple fields" do
      client = Mock.client()

      {:ok, updated} =
        Mock.update_issue(client, "mock-project", "2", %{
          description: "New description",
          title: "Updated title"
        })

      assert updated["description"] == "New description"
      assert updated["title"] == "Updated title"
    end

    test "returns error for non-existent issue" do
      client = Mock.client()
      result = Mock.update_issue(client, "mock-project", "999", %{description: "Test"})

      assert result == {:error, :not_found}
    end

    test "preserves issue structure after update" do
      client = Mock.client()

      {:ok, updated} = Mock.update_issue(client, "mock-project", "3", %{description: "Test"})

      # Verify all expected fields are present
      assert updated["id"]
      assert updated["iid"]
      assert updated["title"]
      assert updated["description"]
      assert updated["webUrl"]
      assert updated["referencePath"]
      assert updated[:base_url]
    end
  end
end
