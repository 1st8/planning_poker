defmodule PlanningPokerWeb.PlanningComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias PlanningPokerWeb.PlanningComponents

  doctest PlanningPokerWeb.PlanningComponents

  describe "format_timestamp/1" do
    test "returns nil for a missing timestamp" do
      assert PlanningComponents.format_timestamp(nil) == nil
    end

    test "returns nil for an unparseable timestamp" do
      assert PlanningComponents.format_timestamp("yesterday") == nil
    end

    test "formats an ISO 8601 string" do
      assert PlanningComponents.format_timestamp("2024-01-15T10:00:00Z") == "15 Jan 2024"
    end

    test "accepts a DateTime as well as a string" do
      assert PlanningComponents.format_timestamp(~U[2024-03-01T12:00:00Z]) == "01 Mar 2024"
    end

    test "normalises a non-UTC offset to UTC" do
      # 00:30 on 16 Jan at +02:00 is still 22:30 on 15 Jan in UTC
      assert PlanningComponents.format_timestamp("2024-01-16T00:30:00+02:00") == "15 Jan 2024"
    end
  end

  describe "byline_text/1" do
    test "combines timestamp and author" do
      issue = %{"createdAt" => "2024-01-15T10:00:00Z", "author" => %{"name" => "Alice Anderson"}}

      assert PlanningComponents.byline_text(issue) == "Created on 15 Jan 2024 by Alice Anderson"
    end

    test "omits the author when unknown" do
      issue = %{"createdAt" => "2024-01-15T10:00:00Z"}

      assert PlanningComponents.byline_text(issue) == "Created on 15 Jan 2024"
    end

    test "omits the timestamp when unknown" do
      issue = %{"author" => %{"name" => "Alice Anderson"}}

      assert PlanningComponents.byline_text(issue) == "Created by Alice Anderson"
    end

    test "returns nil when neither is known" do
      assert PlanningComponents.byline_text(%{}) == nil
      assert PlanningComponents.byline_text(%{"author" => nil, "createdAt" => nil}) == nil
    end
  end

  describe "issue_byline/1" do
    test "renders the byline" do
      html =
        render_component(&PlanningComponents.issue_byline/1,
          issue: %{
            "createdAt" => "2024-01-15T10:00:00Z",
            "author" => %{"name" => "Alice Anderson"}
          }
        )

      assert html =~ "Created on 15 Jan 2024 by Alice Anderson"
    end

    test "renders nothing for an issue without author or timestamp" do
      html = render_component(&PlanningComponents.issue_byline/1, issue: %{})

      refute html =~ "Created"
    end

    test "carries the priority badge on the same line" do
      html =
        render_component(&PlanningComponents.issue_byline/1,
          issue: %{
            "createdAt" => "2024-01-15T10:00:00Z",
            "author" => %{"name" => "Alice Anderson"},
            "priority" => "Urgent"
          }
        )

      assert html =~ "Created on 15 Jan 2024 by Alice Anderson"
      assert html =~ "Urgent"
      assert html =~ "badge-error"
      # one paragraph holding both, rather than a second block below
      assert html |> String.split("<p") |> length() == 2
    end

    test "still renders the badge for an issue with a priority but no author or date" do
      html =
        render_component(&PlanningComponents.issue_byline/1, issue: %{"priority" => "High"})

      refute html =~ "Created"
      assert html =~ "High"
      assert html =~ "badge-warning"
    end
  end

  describe "issue_priority_badge/1" do
    defp badge(issue) do
      render_component(&PlanningComponents.issue_priority_badge/1, issue: issue)
    end

    test "renders the priority label" do
      html = badge(%{"priority" => "Low - Nice to Have"})

      assert html =~ "Low - Nice to Have"
      assert html =~ "badge"
    end

    test "colours the badge by the leading word of the label" do
      assert badge(%{"priority" => "Urgent - ASAP"}) =~ "badge-error"
      assert badge(%{"priority" => "High - Next Sprint"}) =~ "badge-warning"
      assert badge(%{"priority" => "Medium - Next Version"}) =~ "badge-info"
      assert badge(%{"priority" => "Low - Nice to Have"}) =~ "badge-ghost"
    end

    test "colours the bare level labels the same way" do
      assert badge(%{"priority" => "Urgent"}) =~ "badge-error"
      assert badge(%{"priority" => "High"}) =~ "badge-warning"
      assert badge(%{"priority" => "Medium"}) =~ "badge-info"
      assert badge(%{"priority" => "Low"}) =~ "badge-ghost"
    end

    test "falls back to a neutral badge for an unrecognised label" do
      html = badge(%{"priority" => "P1"})

      assert html =~ "P1"
      assert html =~ "badge-neutral"
    end

    test "renders nothing when the issue has no priority" do
      assert badge(%{}) == ""
      assert badge(%{"priority" => nil}) == ""
    end
  end
end
