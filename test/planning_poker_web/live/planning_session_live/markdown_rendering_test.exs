defmodule PlanningPokerWeb.PlanningSessionLive.MarkdownRenderingTest do
  use ExUnit.Case, async: true

  describe "MDEx markdown rendering with task lists" do
    test "renders unchecked task list items as disabled checkboxes" do
      markdown = "- [ ] Incomplete task"

      html = render_markdown(markdown)

      assert html =~ ~s(<input type="checkbox" disabled="")
      assert html =~ "Incomplete task"
      refute html =~ ~s(checked="")
    end

    test "renders checked task list items with checked attribute" do
      markdown = "- [x] Completed task"

      html = render_markdown(markdown)

      assert html =~ ~s(<input type="checkbox")
      assert html =~ ~s(checked="")
      assert html =~ ~s(disabled="")
      assert html =~ "Completed task"
    end

    test "renders mixed task list with checked and unchecked items" do
      markdown = """
      ## Tasks
      - [x] Done task
      - [ ] Todo task
      - [x] Another done task
      """

      html = render_markdown(markdown)

      # Should have 3 checkboxes
      checkbox_count = html |> String.split(~s(<input type="checkbox")) |> length() |> Kernel.-(1)
      assert checkbox_count == 3

      # Should have 2 checked
      checked_count = html |> String.split(~s(checked="")) |> length() |> Kernel.-(1)
      assert checked_count == 2
    end

    test "renders regular list items without checkboxes" do
      markdown = """
      - Regular item 1
      - Regular item 2
      """

      html = render_markdown(markdown)

      refute html =~ "checkbox"
      assert html =~ "Regular item 1"
      assert html =~ "Regular item 2"
    end

    test "handles task lists with other markdown features" do
      markdown = """
      # Issue Title

      Some **bold** text and *italic* text.

      ## Tasks
      - [x] ~~Strikethrough~~ completed task
      - [ ] Task with `code`
      - [ ] Task with [link](https://example.com)

      Regular paragraph.
      """

      html = render_markdown(markdown)

      # Check heading
      assert html =~ "<h1>Issue Title</h1>"

      # Check bold and italic
      assert html =~ "<strong>bold</strong>"
      assert html =~ "<em>italic</em>"

      # Check strikethrough in task
      assert html =~ "<del>Strikethrough</del>"

      # Check code in task
      assert html =~ "<code>code</code>"

      # Check link in task
      assert html =~ ~s(<a href="https://example.com">link</a>)

      # Check checkboxes
      assert html =~ ~s(<input type="checkbox")
    end

    test "renders empty task list item" do
      markdown = "- [ ] "

      html = render_markdown(markdown)

      assert html =~ ~s(<input type="checkbox" disabled="")
    end

    test "handles task lists in nested lists" do
      markdown = """
      - [ ] Parent task
        - [ ] Child task 1
        - [x] Child task 2
      """

      html = render_markdown(markdown)

      # Should have 3 checkboxes (parent + 2 children)
      checkbox_count = html |> String.split(~s(<input type="checkbox")) |> length() |> Kernel.-(1)
      assert checkbox_count == 3
    end
  end

  # Helper function that mimics the one in CollaborativeIssueEditorComponent
  defp render_markdown(content) do
    MDEx.to_html!(content,
      extension: [
        strikethrough: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true
      ],
      parse: [
        smart: true,
        relaxed_tasklist_matching: true
      ],
      render: [
        unsafe_: false
      ]
    )
  rescue
    _ ->
      "<p>Error rendering markdown</p>"
  end
end
