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
  end
end
