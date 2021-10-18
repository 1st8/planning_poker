defmodule PlanningPokerWeb.PlanningSessionLiveTest do
  use PlanningPokerWeb.ConnCase

  import Phoenix.LiveViewTest
  import PlanningPoker.PlanningFixtures

  @create_attrs %{}
  @update_attrs %{}
  @invalid_attrs %{}

  defp create_planning_session(_) do
    planning_session = planning_session_fixture()
    %{planning_session: planning_session}
  end

  describe "Index" do
    setup [:create_planning_session]

    test "lists all planning_sessions", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, Routes.planning_session_index_path(conn, :index))

      assert html =~ "Listing Planning sessions"
    end

    test "saves new planning_session", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, Routes.planning_session_index_path(conn, :index))

      assert index_live |> element("a", "New Planning session") |> render_click() =~
               "New Planning session"

      assert_patch(index_live, Routes.planning_session_index_path(conn, :new))

      assert index_live
             |> form("#planning_session-form", planning_session: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#planning_session-form", planning_session: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.planning_session_index_path(conn, :index))

      assert html =~ "Planning session created successfully"
    end

    test "updates planning_session in listing", %{conn: conn, planning_session: planning_session} do
      {:ok, index_live, _html} = live(conn, Routes.planning_session_index_path(conn, :index))

      assert index_live |> element("#planning_session-#{planning_session.id} a", "Edit") |> render_click() =~
               "Edit Planning session"

      assert_patch(index_live, Routes.planning_session_index_path(conn, :edit, planning_session))

      assert index_live
             |> form("#planning_session-form", planning_session: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#planning_session-form", planning_session: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.planning_session_index_path(conn, :index))

      assert html =~ "Planning session updated successfully"
    end

    test "deletes planning_session in listing", %{conn: conn, planning_session: planning_session} do
      {:ok, index_live, _html} = live(conn, Routes.planning_session_index_path(conn, :index))

      assert index_live |> element("#planning_session-#{planning_session.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#planning_session-#{planning_session.id}")
    end
  end

  describe "Show" do
    setup [:create_planning_session]

    test "displays planning_session", %{conn: conn, planning_session: planning_session} do
      {:ok, _show_live, html} = live(conn, Routes.planning_session_show_path(conn, :show, planning_session))

      assert html =~ "Show Planning session"
    end

    test "updates planning_session within modal", %{conn: conn, planning_session: planning_session} do
      {:ok, show_live, _html} = live(conn, Routes.planning_session_show_path(conn, :show, planning_session))

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Planning session"

      assert_patch(show_live, Routes.planning_session_show_path(conn, :edit, planning_session))

      assert show_live
             |> form("#planning_session-form", planning_session: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        show_live
        |> form("#planning_session-form", planning_session: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.planning_session_show_path(conn, :show, planning_session))

      assert html =~ "Planning session updated successfully"
    end
  end
end
