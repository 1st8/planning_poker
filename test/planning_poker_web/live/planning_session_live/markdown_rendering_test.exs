defmodule PlanningPokerWeb.PlanningSessionLive.MarkdownRenderingTest do
  use ExUnit.Case, async: true

  alias PlanningPokerWeb.PlanningSessionLive.CollaborativeIssueEditorComponent

  defp render_markdown(content), do: CollaborativeIssueEditorComponent.render_markdown(content)

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

  describe "HTML sanitization" do
    test "allows details and summary tags" do
      markdown = """
      <details>
      <summary>Click to expand</summary>

      Hidden content here.

      </details>
      """

      html = render_markdown(markdown)

      assert html =~ "<details>"
      assert html =~ "<summary>"
      assert html =~ "Click to expand"
      assert html =~ "Hidden content here."
      assert html =~ "</summary>"
      assert html =~ "</details>"
    end

    test "filters out script tags" do
      markdown = """
      Some text

      <script>alert('xss')</script>

      More text
      """

      html = render_markdown(markdown)

      refute html =~ "<script>"
      refute html =~ "alert('xss')"
      refute html =~ "</script>"
      assert html =~ "Some text"
      assert html =~ "More text"
    end

    test "filters out other dangerous tags like iframe" do
      markdown = "<iframe src=\"https://evil.com\"></iframe>"

      html = render_markdown(markdown)

      refute html =~ "<iframe"
      refute html =~ "evil.com"
    end

    test "filters out event handlers in allowed tags" do
      markdown = "<details onclick=\"alert('xss')\"><summary>Title</summary>Content</details>"

      html = render_markdown(markdown)

      assert html =~ "<details>"
      refute html =~ "onclick"
      refute html =~ "alert"
    end

    test "renders markdown images inside details blocks" do
      markdown = """
      <details>
      <summary>Screenshot</summary>

      ![Beiträge_und_Interessantes](/static/Generated Image December 04, 2025 - 12_43PM.png)

      </details>
      """

      html = render_markdown(markdown)

      assert html =~ "<details>"
      assert html =~ "<summary>Screenshot</summary>"
      # The markdown image syntax should be converted to an <img> tag
      assert html =~ "<img"
      # Spaces in URLs get URL-encoded to %20
      assert html =~ ~s(src="/static/Generated%20Image%20December%2004,%202025%20-%2012_43PM.png")
      assert html =~ ~s(alt="Beiträge_und_Interessantes")
      # Should NOT show the raw markdown syntax
      refute html =~ "![Beiträge_und_Interessantes]"
    end
  end

  describe "HTML comment stripping" do
    test "strips standard HTML comments" do
      markdown = "Hello\n\n<!-- this is a comment -->\n\nWorld"

      html = render_markdown(markdown)

      assert html =~ "Hello"
      assert html =~ "World"
      refute html =~ "this is a comment"
      refute html =~ "<!--"
      refute html =~ "-->"
    end

    test "strips inline HTML comments" do
      markdown = "Hello <!-- hidden --> World"

      html = render_markdown(markdown)

      assert html =~ "Hello"
      assert html =~ "World"
      refute html =~ "hidden"
    end

    test "strips multiline HTML comments" do
      markdown = "before\n\n<!--\nmultiline\ncomment\n-->\n\nafter"

      html = render_markdown(markdown)

      assert html =~ "before"
      assert html =~ "after"
      refute html =~ "multiline"
      refute html =~ "comment"
    end

    test "strips malformed <!--> comment pattern" do
      markdown = "<!-->\nSome content\n-->"

      html = render_markdown(markdown)

      refute html =~ "Some content"
      refute html =~ "-->"
    end

    test "strips nested comment patterns without leaking content" do
      markdown = "<!-- <!-- nested --> -->"

      html = render_markdown(markdown)

      refute html =~ "nested"
      refute html =~ "-->"
    end

    test "strips comment-only sections to empty output" do
      markdown = "<!-- just a comment -->"

      html = render_markdown(markdown)

      assert html == ""
    end

    test "strips comments with metadata content" do
      markdown = "# Title\n\n<!-- weight: 5 -->\n\nDescription"

      html = render_markdown(markdown)

      assert html =~ "Title"
      assert html =~ "Description"
      refute html =~ "weight"
    end

    test "preserves arrow notation in regular text" do
      markdown = "value --> result"

      html = render_markdown(markdown)

      # The arrow text should be preserved (possibly with smart typography)
      stripped = html |> String.replace(~r/<[^>]+>/, "")
      assert stripped =~ "value"
      assert stripped =~ "result"
    end

    test "strips HTML comments inside details blocks" do
      markdown =
        "<details>\n<summary>Info</summary>\n\n<!-- hidden note -->\n\nVisible content\n\n</details>"

      html = render_markdown(markdown)

      assert html =~ "Visible content"
      refute html =~ "hidden note"
    end
  end

  describe "video URL rendering" do
    test "renders .mp4 URLs as video elements instead of img" do
      markdown = "![demo video](https://example.com/video.mp4)"

      html = render_markdown(markdown)

      assert html =~ "<video"
      assert html =~ "controls"
      assert html =~ "muted"
      assert html =~ ~s(max-width: 100%)
      assert html =~ ~s(<source src="https://example.com/video.mp4" type="video/mp4")
      refute html =~ "<img"
    end

    test "renders .webm URLs as video elements" do
      markdown = "![screen recording](https://example.com/recording.webm)"

      html = render_markdown(markdown)

      assert html =~ "<video"
      assert html =~ ~s(<source src="https://example.com/recording.webm" type="video/webm")
      assert html =~ ~s(title="screen recording")
      refute html =~ "<img"
    end

    test "renders .mov URLs as video elements" do
      markdown = "![clip](https://example.com/clip.mov)"

      html = render_markdown(markdown)

      assert html =~ "<video"
      assert html =~ ~s(type="video/quicktime")
      refute html =~ "<img"
    end

    test "renders .ogg URLs as video elements" do
      markdown = "![clip](https://example.com/clip.ogg)"

      html = render_markdown(markdown)

      assert html =~ "<video"
      assert html =~ ~s(type="video/ogg")
      refute html =~ "<img"
    end

    test "does not convert regular image URLs to video" do
      markdown = "![photo](https://example.com/photo.png)"

      html = render_markdown(markdown)

      assert html =~ "<img"
      refute html =~ "<video"
    end

    test "handles video URLs with query parameters" do
      markdown = "![video](https://example.com/video.mp4?token=abc123)"

      html = render_markdown(markdown)

      assert html =~ "<video"
      assert html =~ ~s(<source src="https://example.com/video.mp4?token=abc123")
      refute html =~ "<img"
    end

    test "handles mixed images and videos in the same content" do
      markdown = """
      ![screenshot](https://example.com/image.png)

      ![demo](https://example.com/demo.mp4)
      """

      html = render_markdown(markdown)

      assert html =~ "<img"
      assert html =~ "<video"
    end
  end
end
