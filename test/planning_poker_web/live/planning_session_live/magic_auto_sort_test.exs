defmodule PlanningPokerWeb.PlanningSessionLive.MagicAutoSortTest do
  @moduledoc """
  Integration tests for the "Real Magic for Magic Estimation" feature
  (subtask 7). Drives multiple LiveView sockets against a shared
  PlanningSession and exercises the end-to-end flow of magic hints →
  consensus → apply via both gen_statem calls and rendered HTML.

  Mounting a LiveView joins the participant into Presence, and the
  Show LV's `presence_diff` handler calls `Planning.sync_turn_order/2`
  with the live participant ids — so the effective `turn_order` tracks
  the number of connected sockets after LV mounts have settled. Tests
  below reset `magic_hints` and `turn_order` via `:sys.replace_state`
  *after* mounting so the seeded participants line up with what the
  consensus computation expects.

  These tests deliberately avoid any HTTP (mock issue provider only) and
  do not assert on exact sparkle/animation classes — the UI progress
  pill text and wand badges are the canonical user-visible signals.
  """
  use PlanningPokerWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PlanningPoker.{Planning, PlanningSession, TokenCredentials}

  @endpoint PlanningPokerWeb.Endpoint

  setup do
    session_id = "magic-auto-sort-#{:erlang.unique_integer([:positive])}"

    Phoenix.PubSub.subscribe(PlanningPoker.PubSub, "planning_sessions:#{session_id}")

    {:ok, pid} =
      PlanningSession.start_link(
        name: {:via, Registry, {PlanningPoker.PlanningSession.Registry, session_id}},
        args: %{id: session_id, token: "fake-token"}
      )

    # Drain the initial fetch_issues broadcast.
    assert_receive {:state_change, %{state: :lobby}}, 1000

    issues = [
      %{"id" => "issue-a", "title" => "Issue A"},
      %{"id" => "issue-b", "title" => "Issue B"}
    ]

    markers =
      [1, 2, 3, 5, 8, 13, 21]
      |> Enum.map(fn v ->
        %{
          "id" => "marker/#{v}",
          "type" => "marker",
          "value" => Integer.to_string(v),
          "title" => "#{v} SP"
        }
      end)

    alice = PlanningPoker.IssueProviders.Mock.get_user("alice")
    bob = PlanningPoker.IssueProviders.Mock.get_user("bob")
    carol = PlanningPoker.IssueProviders.Mock.get_user("carol")

    turn_order = [alice.id, bob.id, carol.id]

    seed_state(pid, issues, markers, turn_order, true)

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :kill)
    end)

    {:ok,
     session_id: session_id,
     pid: pid,
     alice: alice,
     bob: bob,
     carol: carol,
     turn_order: turn_order,
     issues: issues,
     markers: markers}
  end

  # Forces the session into :magic_estimation with a known layout,
  # resetting hints and applied set. Used both in the initial setup and
  # to re-pin turn_order after LiveViews mount (which would otherwise
  # shrink turn_order via presence_diff → sync_turn_order).
  defp seed_state(pid, issues, markers, turn_order, magic_enabled) do
    :sys.replace_state(pid, fn {_state, data} ->
      updated =
        data
        |> Map.put(:issues, issues)
        |> Map.put(:unestimated_issues, issues ++ markers)
        |> Map.put(:estimated_issues, [])
        |> Map.put(:turn_order, turn_order)
        |> Map.put(:current_turn_index, 0)
        |> Map.put(:current_turn_moves, [])
        |> Map.put(:previous_turn_moves, [])
        |> Map.put(:magic_hints, %{})
        |> Map.put(:magic_enabled, magic_enabled)
        |> Map.put(:magic_applied, MapSet.new())

      {:magic_estimation, updated}
    end)
  end

  defp conn_for(user) do
    Phoenix.ConnTest.build_conn()
    |> Plug.Test.init_test_session(%{
      "current_user" => user,
      "token" => %TokenCredentials{access_token: "mock-token-#{user.name}"}
    })
  end

  defp seed_hint(pid, participant_id, issue_id, raw_head) do
    :ok =
      :gen_statem.call(
        pid,
        {:update_magic_hints, participant_id, %{issue_id => %{"raw_head" => raw_head}}}
      )
  end

  # Rebuilds turn_order on the gen_statem after LV mounts have settled.
  # This is our defence against Show LV's presence_diff handler calling
  # sync_turn_order and shrinking turn_order to only the sockets that
  # actually joined Presence.
  defp pin_turn_order(pid, turn_order) do
    :sys.replace_state(pid, fn {state, data} ->
      {state, Map.put(data, :turn_order, turn_order)}
    end)
  end

  describe "all three participants agree on an integer" do
    test "wand badge, Apply button, and apply-all flow place the issue",
         %{
           pid: pid,
           session_id: id,
           alice: alice,
           bob: bob,
           carol: carol,
           turn_order: turn_order
         } do
      {:ok, view_a, _} = live(conn_for(alice), "/?id=#{id}")
      {:ok, view_b, _} = live(conn_for(bob), "/?id=#{id}")

      # Let any presence_diff-driven sync_turn_order calls settle, then
      # re-pin turn_order to the three seeded participants so the
      # consensus computation uses the test's intended size.
      Process.sleep(50)
      pin_turn_order(pid, turn_order)

      # Three unanimous 5s for issue-a.
      seed_hint(pid, alice.id, "issue-a", "5")
      seed_hint(pid, bob.id, "issue-a", "5")
      seed_hint(pid, carol.id, "issue-a", "5")

      # Re-pin once more in case a presence_diff snuck in between calls.
      pin_turn_order(pid, turn_order)
      Process.sleep(50)

      html_a = render(view_a)

      # Wand badge with the target marker and Apply button (count 1).
      assert html_a =~ "🪄 5"
      assert html_a =~ "Apply magic (1)"

      # Click Apply-all from alice's socket.
      view_a
      |> element("button[phx-click='apply_all_magic']")
      |> render_click()

      # Server state: issue-a immediately follows marker/5.
      state = :gen_statem.call(pid, :get_state)
      ids = Enum.map(state.estimated_issues, & &1["id"])
      idx = Enum.find_index(ids, &(&1 == "marker/5"))
      assert is_integer(idx)
      assert Enum.at(ids, idx + 1) == "issue-a"
      assert "issue-a" in state.magic.applied

      # Both connected sockets see the updated order and the applied marker.
      html_a_after = render(view_a)
      html_b_after = render(view_b)

      assert html_a_after =~ ~s|data-magic-applied="true"|
      assert html_b_after =~ ~s|data-magic-applied="true"|

      # Progress pill advances. After apply, total_unestimated drops to 1
      # (only issue-b remains), so the pill reads "1/1 magically estimated".
      assert html_a_after =~ "1/1 magically estimated"
      assert html_b_after =~ "1/1 magically estimated"
    end
  end

  describe "range averaging rounds up to the nearest marker" do
    test "two 3-5 ranges and one 5 produce 🪄 5 and land after marker/5",
         %{
           pid: pid,
           session_id: id,
           alice: alice,
           bob: bob,
           carol: carol,
           turn_order: turn_order
         } do
      {:ok, view, _} = live(conn_for(alice), "/?id=#{id}")

      Process.sleep(50)
      pin_turn_order(pid, turn_order)

      # Range "3-5" parses to midpoint 4.0; three values → mean (4+4+5)/3 = 4.33.
      # nearest_marker with ties-up over [1,2,3,5,8,13,21] yields 5.
      seed_hint(pid, alice.id, "issue-a", "3-5")
      seed_hint(pid, bob.id, "issue-a", "3-5")
      seed_hint(pid, carol.id, "issue-a", "5")

      pin_turn_order(pid, turn_order)
      Process.sleep(50)

      html = render(view)
      assert html =~ "🪄 5"
      assert html =~ "Apply magic (1)"

      # Apply via the public API and assert placement.
      assert :ok = Planning.apply_magic(id, "issue-a")

      state = :gen_statem.call(pid, :get_state)
      ids = Enum.map(state.estimated_issues, & &1["id"])
      idx = Enum.find_index(ids, &(&1 == "marker/5"))
      assert is_integer(idx)
      assert Enum.at(ids, idx + 1) == "issue-a"
    end
  end

  describe "strict abstain policy blocks consensus until the abstainer leaves" do
    test "pending 2/3 chip flips to ready after sync_turn_order shrinks the group",
         %{
           pid: pid,
           session_id: id,
           alice: alice,
           bob: bob,
           carol: carol,
           turn_order: turn_order
         } do
      {:ok, view, _} = live(conn_for(alice), "/?id=#{id}")

      Process.sleep(50)
      pin_turn_order(pid, turn_order)

      # Alice & Bob agree on 5, Carol abstains with "?".
      seed_hint(pid, alice.id, "issue-a", "5")
      seed_hint(pid, bob.id, "issue-a", "5")
      seed_hint(pid, carol.id, "issue-a", "?")

      pin_turn_order(pid, turn_order)
      Process.sleep(50)

      html = render(view)
      # Pending chip shows 2 of 3 agreeing.
      assert html =~ "2/3"
      # No wand badge yet.
      refute html =~ "🪄 5"

      # Carol leaves — shrink turn_order to [alice, bob].
      :ok = Planning.sync_turn_order(id, [alice.id, bob.id])
      Process.sleep(50)

      html_after = render(view)
      assert html_after =~ "🪄 5"
      assert html_after =~ "Apply magic (1)"

      state = :gen_statem.call(pid, :get_state)

      assert %{status: :ready, target_marker: 5, agreeing: 2, total: 2} =
               Map.fetch!(state.magic.consensus, "issue-a")
    end
  end

  describe "manual drag overrides an applied magic placement" do
    test "moving the issue after apply clears it from magic.applied",
         %{
           pid: pid,
           session_id: id,
           alice: alice,
           bob: bob,
           carol: carol,
           turn_order: turn_order
         } do
      seed_hint(pid, alice.id, "issue-a", "5")
      seed_hint(pid, bob.id, "issue-a", "5")
      seed_hint(pid, carol.id, "issue-a", "5")
      pin_turn_order(pid, turn_order)

      assert :ok = Planning.apply_magic(id, "issue-a")

      state = :gen_statem.call(pid, :get_state)
      assert "issue-a" in state.magic.applied

      # Manually drag within the estimated column.
      :ok =
        Planning.update_issue_position(
          id,
          "issue-a",
          "estimated-issues",
          "estimated-issues",
          0
        )

      state_after = :gen_statem.call(pid, :get_state)
      refute "issue-a" in state_after.magic.applied
    end
  end

  describe "toggle off hides UI" do
    test "with magic disabled the pill, Apply button, and wand badges do not render",
         %{
           pid: pid,
           session_id: id,
           alice: alice,
           bob: bob,
           carol: carol,
           turn_order: turn_order
         } do
      # Seed a ready issue while magic is on.
      seed_hint(pid, alice.id, "issue-a", "5")
      seed_hint(pid, bob.id, "issue-a", "5")
      seed_hint(pid, carol.id, "issue-a", "5")
      pin_turn_order(pid, turn_order)

      # Sanity: confirm ready state before disabling.
      state_before = :gen_statem.call(pid, :get_state)
      assert state_before.magic.enabled == true
      assert state_before.magic.progress.ready == 1

      # Disable magic.
      :ok = Planning.toggle_magic(id, false)

      {:ok, view, _} = live(conn_for(alice), "/?id=#{id}")
      Process.sleep(50)
      html = render(view)

      refute html =~ "Apply magic"
      refute html =~ "magically estimated"
      # Per-issue wand badge gates on consensus.status == :ready within
      # the MagicEstimationComponent. When magic is disabled the
      # component's progress pill (which carries the only other "🪄 N"
      # text) is also hidden, so no wand badge text should render.
      refute html =~ "🪄 5"

      # Re-send hints while disabled. The implementation currently still
      # recomputes consensus even with magic disabled, but the UI does
      # not surface it — assert on the user-visible behaviour.
      seed_hint(pid, alice.id, "issue-b", "3")
      seed_hint(pid, bob.id, "issue-b", "3")
      seed_hint(pid, carol.id, "issue-b", "3")
      Process.sleep(50)

      html2 = render(view)
      refute html2 =~ "Apply magic"
      refute html2 =~ "magically estimated"
      refute html2 =~ "🪄 3"
      refute html2 =~ "🪄 5"
    end
  end

  describe "re-sending identical hints is idempotent" do
    test "duplicate updates leave the consensus entry for the issue stable",
         %{pid: pid, alice: alice} do
      hints = %{"issue-a" => %{"raw_head" => "5"}}

      :ok = :gen_statem.call(pid, {:update_magic_hints, alice.id, hints})
      state1 = :gen_statem.call(pid, :get_state)
      consensus1 = Map.fetch!(state1.magic.consensus, "issue-a")

      :ok = :gen_statem.call(pid, {:update_magic_hints, alice.id, hints})
      :ok = :gen_statem.call(pid, {:update_magic_hints, alice.id, hints})

      state2 = :gen_statem.call(pid, :get_state)
      consensus2 = Map.fetch!(state2.magic.consensus, "issue-a")

      # End state is stable. If the implementation already no-ops when
      # hints don't change, no extra broadcasts fire; if it always
      # broadcasts, re-broadcast is acceptable — this assertion only
      # checks observable state stability.
      assert consensus1 == consensus2
      assert consensus2.agreeing == 1
    end
  end
end
