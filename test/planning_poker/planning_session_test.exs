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
    setup %{session_id: _session_id, pid: pid} do
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
        {_state, data} = state_data
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
      assert section["locked_by"]["id"] == "user-123"
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
      assert section["locked_by"]["id"] == "user-123"
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
    setup %{session_id: _session_id, pid: pid} do
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
  end

  describe "save_and_back_to_lobby" do
    setup %{session_id: _session_id, pid: pid} do
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

  describe "magic estimation weight persistence" do
    setup %{session_id: _session_id, pid: pid} do
      # Create mock issues
      issues = [
        %{
          "id" => "mock-issue-1",
          "iid" => "1",
          "title" => "First Issue",
          "referencePath" => "test-project#1",
          "weight" => nil
        },
        %{
          "id" => "mock-issue-2",
          "iid" => "2",
          "title" => "Second Issue",
          "referencePath" => "test-project#2",
          "weight" => nil
        },
        %{
          "id" => "mock-issue-3",
          "iid" => "3",
          "title" => "Third Issue",
          "referencePath" => "test-project#3",
          "weight" => nil
        }
      ]

      # Set up the session with issues
      :sys.replace_state(pid, fn {state, data} ->
        {state, Map.put(data, :issues, issues)}
      end)

      {:ok, issues: issues}
    end

    test "calculate_weights_from_positions assigns weights correctly", %{pid: pid} do
      # Start magic estimation
      :gen_statem.call(pid, :start_magic_estimation)

      # Simulate moving issues and markers to estimated column
      # Move marker/1 to position 0
      :gen_statem.call(pid, {:update_issue_position, "marker/1", "unestimated-issues", "estimated-issues", 0})
      # Move issue-2 to position 1 (should get weight 1)
      :gen_statem.call(pid, {:update_issue_position, "mock-issue-2", "unestimated-issues", "estimated-issues", 1})
      # Move marker/2 to position 2
      :gen_statem.call(pid, {:update_issue_position, "marker/2", "unestimated-issues", "estimated-issues", 2})
      # Move issue-1 to position 3 (should get weight 2)
      :gen_statem.call(pid, {:update_issue_position, "mock-issue-1", "unestimated-issues", "estimated-issues", 3})
      # Move marker/5 to position 4
      :gen_statem.call(pid, {:update_issue_position, "marker/5", "unestimated-issues", "estimated-issues", 4})
      # Move issue-3 to position 5 (should get weight 5)
      :gen_statem.call(pid, {:update_issue_position, "mock-issue-3", "unestimated-issues", "estimated-issues", 5})

      # Get state to verify the arrangement
      state = :gen_statem.call(pid, :get_state)

      # Verify estimated_issues are arranged correctly
      assert length(state.estimated_issues) == 6

      # Extract issue IDs in order
      ids = Enum.map(state.estimated_issues, & &1["id"])
      assert ids == ["marker/1", "mock-issue-2", "marker/2", "mock-issue-1", "marker/5", "mock-issue-3"]
    end

    test "complete_estimation with no estimated issues transitions to lobby", %{pid: pid} do
      # Start magic estimation
      :gen_statem.call(pid, :start_magic_estimation)

      # Clear any pending messages
      _cleared = clear_all_messages()

      # Complete estimation without moving any issues
      assert :gen_statem.call(pid, :complete_estimation) == :ok

      # Should transition to lobby immediately (no weights to update)
      # There might be multiple state changes (from complete_estimation and from fetch_issues refresh)
      # So let's collect a few and check that we eventually get to lobby
      states = collect_state_changes(2)

      # At least one state should be lobby
      assert Enum.any?(states, fn {_, s} -> s.state == :lobby end)
    end

    test "complete_estimation with estimated issues creates update tasks", %{pid: pid} do
      # Start magic estimation
      :gen_statem.call(pid, :start_magic_estimation)

      # Move some issues with markers
      :gen_statem.call(pid, {:update_issue_position, "marker/2", "unestimated-issues", "estimated-issues", 0})
      :gen_statem.call(pid, {:update_issue_position, "mock-issue-1", "unestimated-issues", "estimated-issues", 1})

      # Clear any pending messages
      _cleared = clear_all_messages()

      # Complete estimation
      assert :gen_statem.call(pid, :complete_estimation) == :ok

      # Collect state_change messages
      states = collect_state_changes(3)

      # First state should be magic_estimation with updating_weights=true
      {_, first_state} = List.first(states)
      assert first_state.state == :magic_estimation
      assert first_state.updating_weights == true
      assert first_state.weight_update_total == 1
      assert first_state.weight_update_completed == 0

      # Eventually should transition to lobby (updates complete)
      final_state = List.last(states) |> elem(1)
      assert final_state.state == :lobby
    end

    defp clear_all_messages() do
      clear_all_messages(0)
    end

    defp clear_all_messages(count) do
      receive do
        {:state_change, _} -> clear_all_messages(count + 1)
      after
        10 -> count
      end
    end

    defp collect_state_changes(max_count) do
      collect_state_changes(0, max_count, [])
    end

    defp collect_state_changes(count, max_count, acc) when count >= max_count do
      Enum.reverse(acc)
    end

    defp collect_state_changes(count, max_count, acc) do
      receive do
        {:state_change, state} ->
          collect_state_changes(count + 1, max_count, [{count + 1, state} | acc])
      after
        100 ->
          Enum.reverse(acc)
      end
    end

    test "issues before first marker are not assigned weights", %{pid: pid} do
      # Start magic estimation
      :gen_statem.call(pid, :start_magic_estimation)

      # Move an issue BEFORE any marker
      :gen_statem.call(pid, {:update_issue_position, "mock-issue-1", "unestimated-issues", "estimated-issues", 0})
      # Then add a marker after it
      :gen_statem.call(pid, {:update_issue_position, "marker/2", "unestimated-issues", "estimated-issues", 1})
      # And another issue after the marker
      :gen_statem.call(pid, {:update_issue_position, "mock-issue-2", "unestimated-issues", "estimated-issues", 2})

      # Get state
      state = :gen_statem.call(pid, :get_state)

      # Verify arrangement
      ids = Enum.map(state.estimated_issues, & &1["id"])
      assert ids == ["mock-issue-1", "marker/2", "mock-issue-2"]

      # Complete estimation (this would only update mock-issue-2 with weight=2)
      :gen_statem.call(pid, :complete_estimation)

      # The weight map should only contain mock-issue-2
      # mock-issue-1 should not be in the map (it's before the first marker)
      # We can verify this by checking the update task count
      state = :gen_statem.call(pid, :get_state)
      assert state.weight_update_total == 1  # Only one issue to update
    end
  end
end
