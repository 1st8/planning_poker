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

  describe "issue_byline/1 with comments" do
    defp byline(issue, opts \\ []) do
      render_component(&PlanningComponents.issue_byline/1, [issue: issue] ++ opts)
    end

    test "puts the count after the author, separated by a middle dot" do
      html =
        byline(%{
          "createdAt" => "2024-01-15T10:00:00Z",
          "author" => %{"name" => "Alice Anderson"},
          "comments" => [%{}, %{}]
        })

      text =
        html |> String.replace(~r/<[^>]*>/, "") |> String.replace(~r/\s+/, " ") |> String.trim()

      assert text == "Created on 15 Jan 2024 by Alice Anderson · 2 comments"
    end

    test "links the count to the given anchor and opens the block" do
      html = byline(%{"comments" => [%{}, %{}]}, comments_anchor: "issue-comments")

      assert html =~ ~s(href="#issue-comments")
      # the click opens the collapsed block, so the anchor lands on something visible
      assert html =~ "set_attr"
      assert html =~ "open"
      assert html =~ "2 comments"
    end

    test "leaves the count as plain text without an anchor" do
      html = byline(%{"comments" => [%{}, %{}]})

      refute html =~ "<a"
      assert html =~ "2 comments"
    end

    test "singularizes a lone comment" do
      assert byline(%{"comments" => [%{}]}) =~ "1 comment"
    end

    test "uses the bare count when the issue carries no comment bodies" do
      assert byline(%{"commentCount" => 4}) =~ "4 comments"
      assert byline(%{"commentCount" => 1}) =~ "1 comment"
      assert byline(%{"commentCount" => 0}) == ""
    end

    test "omits the count and its separator when there are no comments" do
      html = byline(%{"createdAt" => "2024-01-15T10:00:00Z", "comments" => []})

      text =
        html |> String.replace(~r/<[^>]*>/, "") |> String.replace(~r/\s+/, " ") |> String.trim()

      assert text == "Created on 15 Jan 2024"
    end

    test "renders for an issue that only has comments" do
      assert byline(%{"comments" => [%{}]}) =~ "1 comment"
    end
  end
end
