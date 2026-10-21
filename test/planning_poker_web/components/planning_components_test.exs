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

    test "leaves the priority to the line below" do
      html =
        render_component(&PlanningComponents.issue_byline/1,
          issue: %{
            "createdAt" => "2024-01-15T10:00:00Z",
            "author" => %{"name" => "Alice Anderson"},
            "priority" => "Urgent"
          }
        )

      assert html =~ "Created on 15 Jan 2024 by Alice Anderson"
      refute html =~ "Urgent"
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

  describe "issue_tags/1" do
    defp tags(issue), do: render_component(&PlanningComponents.issue_tags/1, issue: issue)

    test "puts priority, milestone and labels on one line, in that order" do
      html =
        tags(%{
          "priority" => "Urgent",
          "milestone" => %{"title" => "v1.2"},
          "labels" => [%{"title" => "bug"}]
        })

      assert html =~ "badge-error"
      assert html |> String.split("<p") |> length() == 2

      text =
        html |> String.replace(~r/<[^>]*>/, "") |> String.replace(~r/\s+/, " ") |> String.trim()

      assert text == "Priority: Urgent Milestone: v1.2 bug"
    end

    test "names each element's kind on hover" do
      html =
        tags(%{
          "priority" => "Urgent",
          "milestone" => %{"title" => "v1.2"},
          "labels" => [%{"title" => "bug"}, %{"title" => "Tech"}]
        })

      assert html =~ ~s(title="Priority")
      assert html =~ ~s(title="Milestone")
      assert html |> String.split(~s(title="Label")) |> length() == 3
    end

    test "renders the priority on its own" do
      html = tags(%{"priority" => "High"})

      assert html =~ "High"
      assert html =~ "badge-warning"
    end

    test "renders the milestone" do
      html = tags(%{"milestone" => %{"title" => "v1.2"}})

      assert html =~ "Milestone:"
      assert html =~ "v1.2"
    end

    test "renders each label in its own colours" do
      html =
        tags(%{
          "labels" => [
            %{"title" => "bug", "color" => "#D9534F", "textColor" => "#FFFFFF"},
            %{"title" => "frontend", "color" => "#F0AD4E", "textColor" => "#333333"}
          ]
        })

      assert html =~ "bug"
      assert html =~ "background-color: #D9534F; color: #FFFFFF;"
      assert html =~ "frontend"
      assert html =~ "background-color: #F0AD4E; color: #333333;"
      refute html =~ "Milestone:"
    end

    test "drops a colour that is not a hex code" do
      html =
        tags(%{"labels" => [%{"title" => "bug", "color" => "red; position: fixed"}]})

      assert html =~ "bug"
      refute html =~ "position"
    end

    test "renders nothing when the issue has neither" do
      assert tags(%{}) == ""
      assert tags(%{"priority" => nil, "milestone" => nil, "labels" => []}) == ""
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
