defmodule PlanningPokerWeb.PlanningSessionLive.CollaborativeIssueEditorComponentTest do
  use ExUnit.Case, async: true

  alias PlanningPokerWeb.PlanningSessionLive.CollaborativeIssueEditorComponent

  defp render_markdown(content), do: CollaborativeIssueEditorComponent.render_markdown(content)

  describe "GitLab image attributes" do
    test "applies both width and height" do
      html = render_markdown("![Logo](img/logo.png){width=100 height=200px}")

      assert html =~ ~s(src="img/logo.png")
      assert html =~ ~s(alt="Logo")
      assert html =~ ~s(width="100")
      assert html =~ ~s(height="200px")
      refute html =~ "{width="
    end

    test "applies a percentage width" do
      html = render_markdown("![Banner](img/banner.png){width=75%}")

      assert html =~ ~s(src="img/banner.png")
      assert html =~ ~s(width="75%")
      refute html =~ "height="
      refute html =~ "{width="
    end

    test "applies height alone" do
      html = render_markdown("![Tall](img/tall.png){height=300px}")

      assert html =~ ~s(src="img/tall.png")
      assert html =~ ~s(height="300px")
      refute html =~ "width="
    end

    test "accepts the attributes in either order" do
      html = render_markdown("![Logo](img/logo.png){height=20 width=10}")

      assert html =~ ~s(width="10")
      assert html =~ ~s(height="20")
    end

    test "leaves images without an attribute block unchanged" do
      html = render_markdown("![Normal](img/normal.png)")

      assert html =~ ~s(src="img/normal.png")
      assert html =~ ~s(alt="Normal")
      refute html =~ "width="
      refute html =~ "height="
    end

    test "handles multiple images with attributes" do
      markdown = """
      ![One](img/one.png){width=100}

      Some text in between.

      ![Two](img/two.png){width=50 height=60}
      """

      html = render_markdown(markdown)

      assert html =~ ~s(src="img/one.png")
      assert html =~ ~s(src="img/two.png")
      assert html =~ ~s(width="100")
      assert html =~ ~s(width="50")
      assert html =~ ~s(height="60")
      assert html =~ "Some text in between."
    end

    test "handles two images with attributes on the same line" do
      html = render_markdown("![A](a.png){width=10} and ![B](b.png){height=20}")

      assert html =~ ~s(<img src="a.png" alt="A" width="10">)
      assert html =~ ~s(<img src="b.png" alt="B" height="20">)
    end

    test "ignores invalid values but keeps valid ones" do
      html = render_markdown("![Mixed](img/mixed.png){width=100 height=huge}")

      assert html =~ ~s(src="img/mixed.png")
      assert html =~ ~s(width="100")
      refute html =~ "height="
    end

    test "ignores unknown keys" do
      html = render_markdown("![Mixed](img/mixed.png){width=100 border=5}")

      assert html =~ ~s(width="100")
      refute html =~ "border"
    end

    test "ignores values with more than four digits" do
      html = render_markdown("![Big](img/big.png){width=12345}")

      assert html =~ ~s(src="img/big.png")
      refute html =~ ~s(width=")
    end

    test "leaves the block as text when no attribute is valid" do
      html = render_markdown("![Bad](img/bad.png){width=abc}")

      assert html =~ ~s(src="img/bad.png")
      refute html =~ ~s(width=")
      assert html =~ "{width=abc}"
    end

    test "does not crash on an empty attribute block" do
      html = render_markdown("![Empty](img/empty.png){}")

      assert html =~ ~s(src="img/empty.png")
      refute html =~ ~s(width=")
    end

    test "encodes spaces in urls before applying attributes" do
      html = render_markdown("![Spaced](img/my image.png){width=100}")

      assert html =~ ~s(src="img/my%20image.png")
      assert html =~ ~s(width="100")
    end

    test "carries width and height over to converted video tags" do
      html = render_markdown("![Clip](media/clip.mp4){width=320 height=240}")

      assert html =~ "<video"
      assert html =~ ~s(<source src="media/clip.mp4" type="video/mp4")
      assert html =~ ~s(width="320")
      assert html =~ ~s(height="240")
    end

    test "applies attributes to images inside details blocks" do
      markdown = """
      <details>
      <summary>More</summary>

      ![Inner](img/inner.png){width=42}

      </details>
      """

      html = render_markdown(markdown)

      assert html =~ ~s(src="img/inner.png")
      assert html =~ ~s(width="42")
    end
  end
end
