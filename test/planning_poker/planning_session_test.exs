defmodule PlanningPoker.PlanningSessionTest do
  use ExUnit.Case, async: true

  alias PlanningPoker.PlanningSession

  setup do
    # Create a unique ID for each test
    session_id = "test-session-#{:erlang.unique_integer()}"

    # Start the session
    {:ok, pid} = PlanningSession.start_link(
      name: {:via, Registry, {PlanningPoker.PlanningSession.Registry, session_id}},
      args: %{id: session_id, token: "fake-token"}
    )

    # Subscribe to state changes
    Phoenix.PubSub.subscribe(PlanningPoker.PubSub, "planning_sessions:#{session_id}")

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :kill)
    end)

    {:ok, session_id: session_id, pid: pid}
  end

  describe "section editing in voting state" do
    setup %{session_id: session_id, pid: pid} do
      # Create a mock issue with description
      issue_with_sections = %{
        "id" => "gid://gitlab/Issue/123",
        "title" => "Test Issue",
        "description" => "First paragraph\n\nSecond paragraph",
        "sections" => [
          %{"id" => "section-0", "content" => "First paragraph", "locked_by" => nil, "position" => 0},
          %{"id" => "section-1", "content" => "Second paragraph", "locked_by" => nil, "position" => 1}
        ]
      }

      # Force the session into voting state with our test issue
      :sys.replace_state(pid, fn state_data ->
        {state, data} = state_data
        updated_data = data
          |> Map.put(:current_issue, issue_with_sections)
          |> Map.put(:issues, [%{"id" => "gid://gitlab/Issue/123", "title" => "Test Issue"}])

        {:voting, updated_data}
      end)

      {:ok, issue: issue_with_sections}
    end

    test "lock_section locks an unlocked section", %{pid: pid} do
      assert :gen_statem.call(pid, {:lock_section, "section-0", "user-123"}) == :ok

      # Verify state was updated
      state = :gen_statem.call(pid, :get_state)
      section = Enum.find(state.current_issue["sections"], &(&1["id"] == "section-0"))
      assert section["locked_by"] == "user-123"
    end

    test "lock_section prevents locking a section locked by another user", %{pid: pid} do
      # User 1 locks the section
      :gen_statem.call(pid, {:lock_section, "section-0", "user-123"})

      # User 2 tries to lock the same section
      assert :gen_statem.call(pid, {:lock_section, "section-0", "user-456"}) == {:error, :section_locked}
    end

    test "unlock_section unlocks a locked section", %{pid: pid} do
      # Lock first
      :gen_statem.call(pid, {:lock_section, "section-0", "user-123"})

      # Then unlock
      assert :gen_statem.call(pid, {:unlock_section, "section-0", "user-123"}) == :ok

      # Verify state was updated
      state = :gen_statem.call(pid, :get_state)
      section = Enum.find(state.current_issue["sections"], &(&1["id"] == "section-0"))
      assert section["locked_by"] == nil
    end

    test "unlock_section prevents unlocking by non-owner", %{pid: pid} do
      # User 1 locks the section
      :gen_statem.call(pid, {:lock_section, "section-0", "user-123"})

      # User 2 tries to unlock
      assert :gen_statem.call(pid, {:unlock_section, "section-0", "user-456"}) == {:error, :not_lock_owner}
    end

    test "update_section_content updates content when locked by user", %{pid: pid} do
      # Lock the section
      :gen_statem.call(pid, {:lock_section, "section-0", "user-123"})

      # Update content
      assert :gen_statem.call(pid, {:update_section_content, "section-0", "Updated content", "user-123"}) == :ok

      # Verify content was updated
      state = :gen_statem.call(pid, :get_state)
      section = Enum.find(state.current_issue["sections"], &(&1["id"] == "section-0"))
      assert section["content"] == "Updated content"
    end

    test "update_section_content fails when not locked by user", %{pid: pid} do
      # Lock with user 1
      :gen_statem.call(pid, {:lock_section, "section-0", "user-123"})

      # User 2 tries to update
      result = :gen_statem.call(pid, {:update_section_content, "section-0", "Updated content", "user-456"})
      assert result == {:error, :not_lock_owner}
    end

    test "update_section_content fails when section is not locked", %{pid: pid} do
      result = :gen_statem.call(pid, {:update_section_content, "section-0", "Updated content", "user-123"})
      assert result == {:error, :section_not_locked}
    end

    test "add_section adds a new section at specified position", %{pid: pid} do
      assert :gen_statem.call(pid, {:add_section, 1, "user-123"}) == :ok

      # Verify new section was added
      state = :gen_statem.call(pid, :get_state)
      assert length(state.current_issue["sections"]) == 3

      # Find the new section at position 1
      new_section = Enum.find(state.current_issue["sections"], &(&1["position"] == 1 && &1["content"] == ""))
      assert new_section != nil
      assert new_section["locked_by"] == "user-123"
    end

    test "add_section increments positions of following sections", %{pid: pid} do
      :gen_statem.call(pid, {:add_section, 1, "user-123"})

      # Verify positions were updated
      state = :gen_statem.call(pid, :get_state)
      original_section_1 = Enum.find(state.current_issue["sections"], &(&1["id"] == "section-1"))
      assert original_section_1["position"] == 2
    end

    test "broadcasts state changes on section operations", %{pid: pid} do
      # Clear any initial state change messages
      receive do
        {:state_change, _} -> :ok
      after
        0 -> :ok
      end

      # Lock a section
      :gen_statem.call(pid, {:lock_section, "section-0", "user-123"})

      # Should receive broadcast
      assert_receive {:state_change, state}
      assert state.state == :voting
      section = Enum.find(state.current_issue["sections"], &(&1["id"] == "section-0"))
      assert section["locked_by"] == "user-123"
    end

    test "delete_section marks section as deleted when locked by user", %{pid: pid} do
      # Lock the section first
      :gen_statem.call(pid, {:lock_section, "section-0", "user-123"})

      # Delete the section
      assert :gen_statem.call(pid, {:delete_section, "section-0", "user-123"}) == :ok

      # Verify section is marked as deleted and unlocked
      state = :gen_statem.call(pid, :get_state)
      section = Enum.find(state.current_issue["sections"], &(&1["id"] == "section-0"))
      assert section["deleted"] == true
      assert section["locked_by"] == nil
    end

    test "delete_section fails when not locked by user", %{pid: pid} do
      # Lock with user 1
      :gen_statem.call(pid, {:lock_section, "section-0", "user-123"})

      # User 2 tries to delete
      result = :gen_statem.call(pid, {:delete_section, "section-0", "user-456"})
      assert result == {:error, :not_lock_owner}
    end

    test "delete_section fails when section is not locked", %{pid: pid} do
      result = :gen_statem.call(pid, {:delete_section, "section-0", "user-123"})
      assert result == {:error, :section_not_locked}
    end
  end

  describe "issue modification tracking" do
    setup %{session_id: session_id, pid: pid} do
      # Create a mock issue with sections that have original_content
      issue_with_sections = %{
        "id" => "gid://gitlab/Issue/123",
        "iid" => "123",
        "title" => "Test Issue",
        "referencePath" => "test/project#123",
        "description" => "First paragraph\n\nSecond paragraph",
        "sections" => [
          %{
            "id" => "section-0",
            "content" => "First paragraph",
            "original_content" => "First paragraph",
            "locked_by" => nil,
            "position" => 0,
            "deleted" => false
          },
          %{
            "id" => "section-1",
            "content" => "Second paragraph",
            "original_content" => "Second paragraph",
            "locked_by" => nil,
            "position" => 1,
            "deleted" => false
          }
        ]
      }

      # Force the session into voting state with our test issue
      :sys.replace_state(pid, fn state_data ->
        {_state, data} = state_data
        updated_data = data
          |> Map.put(:current_issue, issue_with_sections)
          |> Map.put(:issues, [%{"id" => "gid://gitlab/Issue/123", "title" => "Test Issue"}])

        {:voting, updated_data}
      end)

      {:ok, issue: issue_with_sections}
    end

    test "issue_modified is false when no modifications", %{pid: pid} do
      state = :gen_statem.call(pid, :get_state)
      refute state.issue_modified
    end

    test "issue_modified is true when section content is changed", %{pid: pid} do
      # Lock and update a section
      :gen_statem.call(pid, {:lock_section, "section-0", "user-123"})
      :gen_statem.call(pid, {:update_section_content, "section-0", "Modified content", "user-123"})

      state = :gen_statem.call(pid, :get_state)
      assert state.issue_modified
    end

    test "issue_modified is true when section is deleted", %{pid: pid} do
      # Lock and delete a section
      :gen_statem.call(pid, {:lock_section, "section-0", "user-123"})
      :gen_statem.call(pid, {:delete_section, "section-0", "user-123"})

      state = :gen_statem.call(pid, :get_state)
      assert state.issue_modified
    end

    test "issue_modified is true when new section is added", %{pid: pid} do
      # Add a new section
      :gen_statem.call(pid, {:add_section, 1, "user-123"})

      state = :gen_statem.call(pid, :get_state)
      assert state.issue_modified
    end
  end

  describe "save_and_back_to_lobby" do
    setup %{session_id: session_id, pid: pid} do
      # Create a mock issue with sections
      issue_with_sections = %{
        "id" => "gid://gitlab/Issue/123",
        "iid" => "123",
        "title" => "Test Issue",
        "referencePath" => "test/project#123",
        "description" => "First paragraph\n\nSecond paragraph",
        "sections" => [
          %{
            "id" => "section-0",
            "content" => "First paragraph",
            "original_content" => "First paragraph",
            "locked_by" => nil,
            "position" => 0,
            "deleted" => false
          },
          %{
            "id" => "section-1",
            "content" => "Second paragraph",
            "original_content" => "Second paragraph",
            "locked_by" => nil,
            "position" => 1,
            "deleted" => false
          }
        ]
      }

      # Force the session into voting state
      :sys.replace_state(pid, fn state_data ->
        {_state, data} = state_data
        updated_data = data
          |> Map.put(:current_issue, issue_with_sections)
          |> Map.put(:issues, [%{"id" => "gid://gitlab/Issue/123", "title" => "Test Issue"}])

        {:voting, updated_data}
      end)

      {:ok, issue: issue_with_sections}
    end

    test "transitions to lobby immediately when no modifications", %{pid: pid} do
      # Call save_and_back_to_lobby without any modifications
      assert :gen_statem.call(pid, :save_and_back_to_lobby) == :ok

      # Should receive state change to lobby
      assert_receive {:state_change, state}
      assert state.state == :lobby
    end

    test "starts update task when modifications exist", %{pid: pid} do
      # Modify a section
      :gen_statem.call(pid, {:lock_section, "section-0", "user-123"})
      :gen_statem.call(pid, {:update_section_content, "section-0", "Modified content", "user-123"})
      :gen_statem.call(pid, {:unlock_section, "section-0", "user-123"})

      # Clear any pending messages
      :sys.get_state(pid)

      # Call save_and_back_to_lobby
      assert :gen_statem.call(pid, :save_and_back_to_lobby) == :ok

      # Should stay in voting state while saving
      # Note: In real scenario, the update task would complete and transition to lobby
      # But in test, we can't easily mock the async task completion
    end

    test "returns error when no current issue", %{pid: pid} do
      # Force back to lobby without current issue
      :sys.replace_state(pid, fn {_state, data} ->
        {:lobby, Map.delete(data, :current_issue)}
      end)

      result = :gen_statem.call(pid, :save_and_back_to_lobby)
      assert result == {:error, :no_current_issue}
    end
  end

  describe "section operations outside voting state" do
    test "section operations return error when no current issue", %{pid: pid} do
      # Session is in lobby state without current issue
      assert :gen_statem.call(pid, {:lock_section, "section-0", "user-123"}) == {:error, "invalid transition"}
    end
  end
end
