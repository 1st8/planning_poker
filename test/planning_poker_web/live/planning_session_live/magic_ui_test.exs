defmodule PlanningPokerWeb.PlanningSessionLive.MagicUITest do
  use PlanningPokerWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias PlanningPoker.{PlanningSession, TokenCredentials}

  @endpoint PlanningPokerWeb.Endpoint

  setup %{conn: conn} do
    # Each test gets a fresh, registry-named PlanningSession to avoid cross-test
    # interference (the LiveView mounts a session id derived from URL params, so
    # we bypass routing and put the live process directly under a unique id).
    session_id = "magic-ui-#{:erlang.unique_integer([:positive])}"

    Phoenix.PubSub.subscribe(PlanningPoker.PubSub, "planning_sessions:#{session_id}")

    {:ok, pid} =
      PlanningSession.start_link(
        name: {:via, Registry, {PlanningPoker.PlanningSession.Registry, session_id}},
        args: %{id: session_id, token: "fake-token"}
      )

    # Drain the initial fetch_issues broadcast so it doesn't race with assertions.
    assert_receive {:state_change, %{state: :lobby}}, 1000

    # Seed magic_estimation state with a couple of issues + the standard markers.
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

    user = PlanningPoker.IssueProviders.Mock.get_user("alice")
    turn_order = [user.id, "p2", "p3"]

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
        |> Map.put(:magic_enabled, false)
        |> Map.put(:magic_applied, MapSet.new())

      {:magic_estimation, updated}
    end)

    on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :kill)
    end)

    conn =
      conn
      |> Plug.Test.init_test_session(%{
        "current_user" => user,
        "token" => %TokenCredentials{access_token: "mock-token-alice"}
      })

    {:ok, conn: conn, session_id: session_id, pid: pid, user: user}
  end

  describe "magic disabled" do
    test "shows toggle but hides progress pill and Apply button", %{conn: conn, session_id: id} do
      {:ok, view, html} = live(conn, "/?id=#{id}")

      # Toggle is rendered.
      assert html =~ "Magic: off"
      assert has_element?(view, "button[phx-click='toggle_magic']")

      # Progress pill not rendered.
      refute html =~ "magically estimated"

      # Apply-magic button not rendered.
      refute has_element?(view, "button[phx-click='apply_all_magic']")
    end
  end

  describe "magic enabled with one ready issue" do
    setup %{pid: pid, user: user} do
      :ok = :gen_statem.call(pid, {:toggle_magic, true})

      Enum.each([user.id, "p2", "p3"], fn pid_id ->
        :ok =
          :gen_statem.call(
            pid,
            {:update_magic_hints, pid_id, %{"issue-a" => %{"raw_head" => "5"}}}
          )
      end)

      :ok
    end

    test "shows progress pill, ready badge, wand badge and Apply button", %{
      conn: conn,
      session_id: id
    } do
      {:ok, view, html} = live(conn, "/?id=#{id}")

      # Progress pill: 0/2 placed, 1 ready.
      assert html =~ "0/2 magically estimated"
      assert html =~ "1 ready"

      # Per-issue wand badge for the ready issue.
      assert has_element?(
               view,
               ~s|button[phx-click='apply_single_magic'][phx-value-issue-id='issue-a']|
             )

      # Pending badge for the other issue.
      assert html =~ "0/3"

      # Apply-all button shows the count.
      assert has_element?(view, "button[phx-click='apply_all_magic']")
      assert html =~ "Apply magic (1)"
    end

    test "clicking Apply-all moves the issue into the estimated column", %{
      conn: conn,
      session_id: id,
      pid: pid
    } do
      {:ok, view, _html} = live(conn, "/?id=#{id}")

      view
      |> element("button[phx-click='apply_all_magic']")
      |> render_click()

      state = :gen_statem.call(pid, :get_state)
      ids = Enum.map(state.estimated_issues, & &1["id"])
      idx = Enum.find_index(ids, &(&1 == "marker/5"))
      assert is_integer(idx)
      assert Enum.at(ids, idx + 1) == "issue-a"
      assert "issue-a" in state.magic.applied
    end

    test "clicking the per-issue wand badge applies that one issue", %{
      conn: conn,
      session_id: id,
      pid: pid
    } do
      {:ok, view, _html} = live(conn, "/?id=#{id}")

      view
      |> element("button[phx-click='apply_single_magic'][phx-value-issue-id='issue-a']")
      |> render_click()

      state = :gen_statem.call(pid, :get_state)
      ids = Enum.map(state.estimated_issues, & &1["id"])
      idx = Enum.find_index(ids, &(&1 == "marker/5"))
      assert is_integer(idx)
      assert Enum.at(ids, idx + 1) == "issue-a"
      assert "issue-a" in state.magic.applied
    end

    test "after applying, the card carries the magic-applied class", %{
      conn: conn,
      session_id: id
    } do
      {:ok, view, _html} = live(conn, "/?id=#{id}")

      view
      |> element("button[phx-click='apply_all_magic']")
      |> render_click()

      html = render(view)

      # The issue-a card should now carry the magic-applied class.
      assert html =~ ~r/class="[^"]*magic-applied[^"]*"[^>]*data-id="issue-a"/ or
               html =~ ~r/data-id="issue-a"[^>]*class="[^"]*magic-applied/

      assert html =~ ~s|data-magic-applied="true"|
    end
  end

  describe "toggle handler" do
    test "clicking the toggle flips magic_enabled on the session", %{
      conn: conn,
      session_id: id,
      pid: pid
    } do
      {:ok, view, _html} = live(conn, "/?id=#{id}")

      view |> element("button[phx-click='toggle_magic']") |> render_click()

      state = :gen_statem.call(pid, :get_state)
      assert state.magic.enabled == true

      view |> element("button[phx-click='toggle_magic']") |> render_click()
      state = :gen_statem.call(pid, :get_state)
      assert state.magic.enabled == false
    end
  end

  describe "error flash" do
    # Sending apply_single_magic on a :pending issue does call put_flash/3, but
    # this app's root layout does not render <.flash_group>, so flash content
    # never appears in any HTML the LiveView returns to the test. We instead
    # verify the side-effect: the genstatem state is unchanged (no magic
    # placement) and the LiveView remains alive (no crash).
    test "applying single magic on a not-ready issue does not crash and leaves state untouched",
         %{conn: conn, session_id: id, pid: pid} do
      :ok = :gen_statem.call(pid, {:toggle_magic, true})
      # No hints sent — issue-a is :pending.

      {:ok, view, _html} = live(conn, "/?id=#{id}")

      _ = render_hook(view, "apply_single_magic", %{"issue-id" => "issue-a"})

      # View still renders; no crash.
      assert render(view) =~ "Magic Estimation"

      # State is unchanged: issue-a stays in unestimated, magic.applied empty.
      state = :gen_statem.call(pid, :get_state)
      assert Enum.any?(state.unestimated_issues, fn i -> i["id"] == "issue-a" end)
      assert state.magic.applied == []
    end
  end
end
