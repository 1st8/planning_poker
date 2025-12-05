defmodule PlanningPoker.IssueSectionTest do
  use ExUnit.Case, async: true

  alias PlanningPoker.IssueSection

  # Helper to create a user object from an ID
  defp user(id, name \\ nil, email \\ nil) do
    %{
      "id" => id,
      "name" => name || "User #{id}",
      "email" => email || "#{id}@example.com"
    }
  end

  describe "parse_into_sections/1" do
    test "parses markdown into sections split by double newlines" do
      markdown = "First paragraph\n\nSecond paragraph\n\nThird paragraph"
      sections = IssueSection.parse_into_sections(markdown)

      assert length(sections) == 3
      assert Enum.at(sections, 0)["content"] == "First paragraph"
      assert Enum.at(sections, 1)["content"] == "Second paragraph"
      assert Enum.at(sections, 2)["content"] == "Third paragraph"
    end

    test "assigns unique IDs and positions to sections" do
      markdown = "First paragraph\n\nSecond paragraph"
      sections = IssueSection.parse_into_sections(markdown)

      assert Enum.at(sections, 0)["id"] == "section-0"
      assert Enum.at(sections, 0)["position"] == 0
      assert Enum.at(sections, 1)["id"] == "section-1"
      assert Enum.at(sections, 1)["position"] == 1
    end

    test "initializes sections as unlocked" do
      markdown = "First paragraph"
      sections = IssueSection.parse_into_sections(markdown)

      assert Enum.at(sections, 0)["locked_by"] == nil
    end

    test "sets original_content to match initial content" do
      markdown = "First paragraph\n\nSecond paragraph"
      sections = IssueSection.parse_into_sections(markdown)

      assert Enum.at(sections, 0)["original_content"] == "First paragraph"
      assert Enum.at(sections, 1)["original_content"] == "Second paragraph"
    end

    test "initializes sections as not deleted" do
      markdown = "First paragraph"
      sections = IssueSection.parse_into_sections(markdown)

      assert Enum.at(sections, 0)["deleted"] == false
    end

    test "filters out empty sections" do
      markdown = "First paragraph\n\n\n\nSecond paragraph"
      sections = IssueSection.parse_into_sections(markdown)

      assert length(sections) == 2
    end

    test "returns empty list for nil input" do
      assert IssueSection.parse_into_sections(nil) == []
    end

    test "returns empty list for empty string" do
      assert IssueSection.parse_into_sections("") == []
    end

    test "preserves HTML comments as single section" do
      markdown = """
      Paragraph before.

      <!-- This is an HTML comment
      with multiple lines
      and double newlines

      inside it -->

      Paragraph after.
      """

      sections = IssueSection.parse_into_sections(markdown)

      assert length(sections) == 3
      assert Enum.at(sections, 0)["content"] == "Paragraph before."
      assert Enum.at(sections, 1)["content"] =~ "<!-- This is an HTML comment"
      assert Enum.at(sections, 1)["content"] =~ "inside it -->"
      assert Enum.at(sections, 2)["content"] == "Paragraph after."
    end

    test "preserves details tags as single section" do
      markdown = """
      Hier darf gesplittet werden.

      Hier auch. Die Details und der Kommentar aber nicht.

      <details>
      <summary>Screencast</summary>
      ![](/uploads/5060802188d3783d7425fec729c8d2db/Bildschirmaufnahme_2025-10-29_um_11.36.15.mov)

      </details>
      """

      sections = IssueSection.parse_into_sections(markdown)

      # Should have 3 sections: text before, details block, empty or nothing after
      assert length(sections) == 3
      assert Enum.at(sections, 0)["content"] == "Hier darf gesplittet werden."

      assert Enum.at(sections, 1)["content"] ==
               "Hier auch. Die Details und der Kommentar aber nicht."

      # The details block should be preserved as one section
      details_section = Enum.at(sections, 2)
      assert details_section["content"] =~ "<details>"
      assert details_section["content"] =~ "<summary>Screencast</summary>"
      assert details_section["content"] =~ "</details>"
    end

    test "preserves nested details with multiple newlines" do
      markdown = """
      First paragraph.

      <details>
      <summary>Details</summary>

      Content inside with newlines.

      More content.
      </details>

      Last paragraph.
      """

      sections = IssueSection.parse_into_sections(markdown)

      assert length(sections) == 3
      assert Enum.at(sections, 0)["content"] == "First paragraph."

      details_section = Enum.at(sections, 1)
      assert details_section["content"] =~ "<details>"
      assert details_section["content"] =~ "Content inside with newlines."
      assert details_section["content"] =~ "More content."
      assert details_section["content"] =~ "</details>"

      assert Enum.at(sections, 2)["content"] == "Last paragraph."
    end

    test "preserves details block with screenshot and following content" do
      markdown =
        "Siehe Screenshot\n\n<details>\n<summary>Screenshoht Webansicht</summary>\n\n![image](/uploads/27f23ec3f83bad30e93ccd314942f547/image.png)\n\n</details>\n\n\n---\n\n### Akzeptanzkriterien\n\n- [ ] Anpassung der Beschriftung im PDF und in der Webansicht (Staging und Prod)"

      sections = IssueSection.parse_into_sections(markdown)

      # Should be: "Siehe Screenshot", details block, "---", "### Akzeptanzkriterien", task list
      assert Enum.at(sections, 0)["content"] == "Siehe Screenshot"

      details_section = Enum.at(sections, 1)
      assert details_section["content"] =~ "<details>"
      assert details_section["content"] =~ "<summary>Screenshoht Webansicht</summary>"
      assert details_section["content"] =~ "![image]"
      assert details_section["content"] =~ "</details>"

      # The remaining content after details should be separate sections
      remaining_contents = sections |> Enum.drop(2) |> Enum.map(& &1["content"])
      assert "---" in remaining_contents
      assert "### Akzeptanzkriterien" in remaining_contents
      assert Enum.any?(remaining_contents, &(&1 =~ "Anpassung der Beschriftung"))
    end

    test "preserves code blocks as single section" do
      markdown = """
      Paragraph before.

      ```elixir
      def hello do
        IO.puts("Hello World")

        IO.puts("Multiple lines")
      end
      ```

      Paragraph after.
      """

      sections = IssueSection.parse_into_sections(markdown)

      assert length(sections) == 3
      assert Enum.at(sections, 0)["content"] == "Paragraph before."

      code_section = Enum.at(sections, 1)
      assert code_section["content"] =~ "```elixir"
      assert code_section["content"] =~ "def hello do"
      assert code_section["content"] =~ "IO.puts(\"Multiple lines\")"
      assert code_section["content"] =~ "```"

      assert Enum.at(sections, 2)["content"] == "Paragraph after."
    end

    test "preserves code blocks without language specifier" do
      markdown = """
      Text before.

      ```
      some code here

      with blank lines
      ```

      Text after.
      """

      sections = IssueSection.parse_into_sections(markdown)

      assert length(sections) == 3
      assert Enum.at(sections, 0)["content"] == "Text before."

      code_section = Enum.at(sections, 1)
      assert code_section["content"] =~ "```"
      assert code_section["content"] =~ "some code here"
      assert code_section["content"] =~ "with blank lines"

      assert Enum.at(sections, 2)["content"] == "Text after."
    end

    test "preserves multiple code blocks in same markdown" do
      markdown = """
      First paragraph.

      ```javascript
      console.log("First block");

      console.log("More code");
      ```

      Middle paragraph.

      ```python
      print("Second block")

      print("With newlines")
      ```

      Last paragraph.
      """

      sections = IssueSection.parse_into_sections(markdown)

      assert length(sections) == 5
      assert Enum.at(sections, 0)["content"] == "First paragraph."

      first_code = Enum.at(sections, 1)
      assert first_code["content"] =~ "```javascript"
      assert first_code["content"] =~ "First block"

      assert Enum.at(sections, 2)["content"] == "Middle paragraph."

      second_code = Enum.at(sections, 3)
      assert second_code["content"] =~ "```python"
      assert second_code["content"] =~ "Second block"

      assert Enum.at(sections, 4)["content"] == "Last paragraph."
    end

    test "preserves inline code with backticks (not code blocks)" do
      markdown = """
      This paragraph has `inline code` in it.

      Another paragraph with `more inline code`.
      """

      sections = IssueSection.parse_into_sections(markdown)

      assert length(sections) == 2
      assert Enum.at(sections, 0)["content"] == "This paragraph has `inline code` in it."
      assert Enum.at(sections, 1)["content"] == "Another paragraph with `more inline code`."
    end

    test "preserves code blocks with mixed content (HTML, details, and code)" do
      markdown = """
      Introduction.

      <!-- Comment with

      newlines -->

      ```ruby
      def test

        puts "code"
      end
      ```

      <details>
      <summary>Details</summary>

      Content here.
      </details>

      Conclusion.
      """

      sections = IssueSection.parse_into_sections(markdown)

      assert length(sections) == 5
      assert Enum.at(sections, 0)["content"] == "Introduction."

      comment_section = Enum.at(sections, 1)
      assert comment_section["content"] =~ "<!--"

      code_section = Enum.at(sections, 2)
      assert code_section["content"] =~ "```ruby"
      assert code_section["content"] =~ "def test"

      details_section = Enum.at(sections, 3)
      assert details_section["content"] =~ "<details>"

      assert Enum.at(sections, 4)["content"] == "Conclusion."
    end
  end

  describe "lock_section/3" do
    setup do
      sections = [
        %{"id" => "section-1", "content" => "Test", "locked_by" => nil, "position" => 0},
        %{"id" => "section-2", "content" => "Test 2", "locked_by" => nil, "position" => 1}
      ]

      {:ok, sections: sections}
    end

    test "locks an unlocked section", %{sections: sections} do
      {:ok, updated} = IssueSection.lock_section(sections, "section-1", user("user-123"))

      section = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section["locked_by"]["id"] == "user-123"
    end

    test "preserves content when locking", %{sections: sections} do
      {:ok, updated} = IssueSection.lock_section(sections, "section-1", user("user-123"))

      section = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section["content_at_lock"] == "Test"
    end

    test "allows same user to lock already locked section", %{sections: sections} do
      {:ok, sections} = IssueSection.lock_section(sections, "section-1", user("user-123"))
      {:ok, updated} = IssueSection.lock_section(sections, "section-1", user("user-123"))

      section = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section["locked_by"]["id"] == "user-123"
    end

    test "prevents locking section locked by another user", %{sections: sections} do
      {:ok, sections} = IssueSection.lock_section(sections, "section-1", user("user-123"))
      result = IssueSection.lock_section(sections, "section-1", user("user-456"))

      assert result == {:error, :section_locked}
    end

    test "returns error for non-existent section", %{sections: sections} do
      result = IssueSection.lock_section(sections, "non-existent", user("user-123"))

      assert result == {:error, :section_not_found}
    end
  end

  describe "unlock_section/3" do
    setup do
      sections = [
        %{
          "id" => "section-1",
          "content" => "Test",
          "locked_by" => user("user-123"),
          "position" => 0,
          "content_at_lock" => "Original"
        },
        %{"id" => "section-2", "content" => "Test 2", "locked_by" => nil, "position" => 1}
      ]

      {:ok, sections: sections}
    end

    test "unlocks a section locked by the user", %{sections: sections} do
      {:ok, updated} = IssueSection.unlock_section(sections, "section-1", "user-123")

      section = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section["locked_by"] == nil
    end

    test "clears content_at_lock when unlocking", %{sections: sections} do
      {:ok, updated} = IssueSection.unlock_section(sections, "section-1", "user-123")

      section = Enum.find(updated, &(&1["id"] == "section-1"))
      refute Map.has_key?(section, "content_at_lock")
    end

    test "prevents unlocking section locked by another user", %{sections: sections} do
      result = IssueSection.unlock_section(sections, "section-1", "user-456")

      assert result == {:error, :not_lock_owner}
    end

    test "succeeds for already unlocked section", %{sections: sections} do
      {:ok, updated} = IssueSection.unlock_section(sections, "section-2", "user-123")

      section = Enum.find(updated, &(&1["id"] == "section-2"))
      assert section["locked_by"] == nil
    end

    test "returns error for non-existent section", %{sections: sections} do
      result = IssueSection.unlock_section(sections, "non-existent", "user-123")

      assert result == {:error, :section_not_found}
    end

    test "splits section on double newlines when unlocking" do
      sections = [
        %{
          "id" => "section-0",
          "content" => "My content\n\nHello World",
          "original_content" => "My content",
          "locked_by" => user("user-123"),
          "position" => 0,
          "deleted" => false
        }
      ]

      {:ok, updated} = IssueSection.unlock_section(sections, "section-0", "user-123")

      assert length(updated) == 2
      assert Enum.at(updated, 0)["content"] == "My content"
      assert Enum.at(updated, 1)["content"] == "Hello World"
    end

    test "splits section into three parts on multiple double newlines" do
      sections = [
        %{
          "id" => "section-0",
          "content" => "Part A\n\nPart B\n\nPart C",
          "original_content" => "Part A",
          "locked_by" => user("user-123"),
          "position" => 0,
          "deleted" => false
        }
      ]

      {:ok, updated} = IssueSection.unlock_section(sections, "section-0", "user-123")

      assert length(updated) == 3
      assert Enum.at(updated, 0)["content"] == "Part A"
      assert Enum.at(updated, 1)["content"] == "Part B"
      assert Enum.at(updated, 2)["content"] == "Part C"
    end

    test "filters out empty segments when splitting" do
      sections = [
        %{
          "id" => "section-0",
          "content" => "Part A\n\n\n\nPart B",
          "original_content" => "Part A",
          "locked_by" => user("user-123"),
          "position" => 0,
          "deleted" => false
        }
      ]

      {:ok, updated} = IssueSection.unlock_section(sections, "section-0", "user-123")

      # Should only create 2 sections, not 3 (empty segment filtered)
      assert length(updated) == 2
      assert Enum.at(updated, 0)["content"] == "Part A"
      assert Enum.at(updated, 1)["content"] == "Part B"
    end

    test "marks new sections as modified after splitting" do
      sections = [
        %{
          "id" => "section-0",
          "content" => "Original\n\nNew content",
          "original_content" => "Original",
          "locked_by" => user("user-123"),
          "position" => 0,
          "deleted" => false
        }
      ]

      {:ok, updated} = IssueSection.unlock_section(sections, "section-0", "user-123")

      # New section should have original_content = nil to mark as modified
      new_section = Enum.at(updated, 1)
      assert new_section["original_content"] == nil
      assert new_section["content"] == "New content"
    end

    test "renumbers all sections sequentially after splitting" do
      sections = [
        %{
          "id" => "section-0",
          "content" => "First\n\nSecond",
          "original_content" => "First",
          "locked_by" => user("user-123"),
          "position" => 0,
          "deleted" => false
        }
      ]

      {:ok, updated} = IssueSection.unlock_section(sections, "section-0", "user-123")

      assert Enum.at(updated, 0)["id"] == "section-0"
      assert Enum.at(updated, 0)["position"] == 0
      assert Enum.at(updated, 1)["id"] == "section-1"
      assert Enum.at(updated, 1)["position"] == 1
    end

    test "does not split when content has no double newlines" do
      sections = [
        %{
          "id" => "section-0",
          "content" => "Single line content",
          "original_content" => "Original",
          "locked_by" => user("user-123"),
          "position" => 0,
          "deleted" => false
        }
      ]

      {:ok, updated} = IssueSection.unlock_section(sections, "section-0", "user-123")

      assert length(updated) == 1
      assert Enum.at(updated, 0)["content"] == "Single line content"
    end

    test "splits middle section and renumbers subsequent sections" do
      sections = [
        %{
          "id" => "section-0",
          "content" => "Before",
          "original_content" => "Before",
          "locked_by" => nil,
          "position" => 0,
          "deleted" => false
        },
        %{
          "id" => "section-1",
          "content" => "Split A\n\nSplit B",
          "original_content" => "Split A",
          "locked_by" => user("user-123"),
          "position" => 1,
          "deleted" => false
        },
        %{
          "id" => "section-2",
          "content" => "After",
          "original_content" => "After",
          "locked_by" => nil,
          "position" => 2,
          "deleted" => false
        }
      ]

      {:ok, updated} = IssueSection.unlock_section(sections, "section-1", "user-123")

      assert length(updated) == 4
      assert Enum.at(updated, 0)["content"] == "Before"
      assert Enum.at(updated, 0)["id"] == "section-0"
      assert Enum.at(updated, 1)["content"] == "Split A"
      assert Enum.at(updated, 1)["id"] == "section-1"
      assert Enum.at(updated, 2)["content"] == "Split B"
      assert Enum.at(updated, 2)["id"] == "section-2"
      assert Enum.at(updated, 3)["content"] == "After"
      assert Enum.at(updated, 3)["id"] == "section-3"
    end
  end

  describe "cancel_section_edit/3" do
    setup do
      sections = [
        %{
          "id" => "section-1",
          "content" => "Modified content",
          "content_at_lock" => "Original content",
          "locked_by" => user("user-123"),
          "position" => 0
        },
        %{
          "id" => "section-2",
          "content" => "Test 2",
          "locked_by" => nil,
          "position" => 1
        }
      ]

      {:ok, sections: sections}
    end

    test "restores content to content_at_lock and unlocks", %{sections: sections} do
      {:ok, updated} = IssueSection.cancel_section_edit(sections, "section-1", "user-123")

      section = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section["content"] == "Original content"
      assert section["locked_by"] == nil
      refute Map.has_key?(section, "content_at_lock")
    end

    test "preserves content if content_at_lock is missing" do
      sections = [
        %{
          "id" => "section-1",
          "content" => "Current content",
          "locked_by" => user("user-123"),
          "position" => 0
        }
      ]

      {:ok, updated} = IssueSection.cancel_section_edit(sections, "section-1", "user-123")

      section = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section["content"] == "Current content"
    end

    test "prevents canceling section locked by another user", %{sections: sections} do
      result = IssueSection.cancel_section_edit(sections, "section-1", "user-456")

      assert result == {:error, :not_lock_owner}
    end

    test "succeeds for already unlocked section", %{sections: sections} do
      {:ok, updated} = IssueSection.cancel_section_edit(sections, "section-2", "user-123")

      section = Enum.find(updated, &(&1["id"] == "section-2"))
      assert section["locked_by"] == nil
    end

    test "returns error for non-existent section", %{sections: sections} do
      result = IssueSection.cancel_section_edit(sections, "non-existent", "user-123")

      assert result == {:error, :section_not_found}
    end
  end

  describe "update_section_content/4" do
    setup do
      sections = [
        %{
          "id" => "section-1",
          "content" => "Old content",
          "locked_by" => user("user-123"),
          "position" => 0
        }
      ]

      {:ok, sections: sections}
    end

    test "updates content when user owns the lock", %{sections: sections} do
      {:ok, updated} =
        IssueSection.update_section_content(sections, "section-1", "New content", "user-123")

      section = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section["content"] == "New content"
    end

    test "prevents update when user does not own the lock", %{sections: sections} do
      result =
        IssueSection.update_section_content(sections, "section-1", "New content", "user-456")

      assert result == {:error, :not_lock_owner}
    end

    test "prevents update when section is not locked" do
      sections = [
        %{"id" => "section-1", "content" => "Old content", "locked_by" => nil, "position" => 0}
      ]

      result =
        IssueSection.update_section_content(sections, "section-1", "New content", "user-123")

      assert result == {:error, :section_not_locked}
    end

    test "returns error for non-existent section", %{sections: sections} do
      result =
        IssueSection.update_section_content(sections, "non-existent", "New content", "user-123")

      assert result == {:error, :section_not_found}
    end
  end

  describe "mark_section_deleted/3" do
    setup do
      sections = [
        %{
          "id" => "section-1",
          "content" => "Test content",
          "locked_by" => user("user-123"),
          "position" => 0,
          "deleted" => false
        }
      ]

      {:ok, sections: sections}
    end

    test "marks section as deleted when user owns the lock", %{sections: sections} do
      {:ok, updated} = IssueSection.mark_section_deleted(sections, "section-1", "user-123")

      section = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section["deleted"] == true
    end

    test "unlocks section when marking as deleted", %{sections: sections} do
      {:ok, updated} = IssueSection.mark_section_deleted(sections, "section-1", "user-123")

      section = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section["locked_by"] == nil
    end

    test "prevents deletion when user does not own the lock", %{sections: sections} do
      result = IssueSection.mark_section_deleted(sections, "section-1", "user-456")

      assert result == {:error, :not_lock_owner}
    end

    test "prevents deletion when section is not locked" do
      sections = [
        %{
          "id" => "section-1",
          "content" => "Test",
          "locked_by" => nil,
          "position" => 0,
          "deleted" => false
        }
      ]

      result = IssueSection.mark_section_deleted(sections, "section-1", "user-123")

      assert result == {:error, :section_not_locked}
    end

    test "returns error for non-existent section", %{sections: sections} do
      result = IssueSection.mark_section_deleted(sections, "non-existent", "user-123")

      assert result == {:error, :section_not_found}
    end
  end

  describe "restore_section/2" do
    setup do
      sections = [
        %{
          "id" => "section-1",
          "content" => "Test content",
          "locked_by" => nil,
          "position" => 0,
          "deleted" => true
        }
      ]

      {:ok, sections: sections}
    end

    test "restores a deleted section", %{sections: sections} do
      {:ok, updated} = IssueSection.restore_section(sections, "section-1")

      section = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section["deleted"] == false
    end

    test "succeeds when section is already not deleted" do
      sections = [
        %{
          "id" => "section-1",
          "content" => "Test",
          "locked_by" => nil,
          "position" => 0,
          "deleted" => false
        }
      ]

      {:ok, updated} = IssueSection.restore_section(sections, "section-1")
      section = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section["deleted"] == false
    end

    test "returns error for non-existent section", %{sections: sections} do
      result = IssueSection.restore_section(sections, "non-existent")

      assert result == {:error, :section_not_found}
    end
  end

  describe "has_modifications?/1" do
    test "returns false when no sections exist" do
      refute IssueSection.has_modifications?([])
    end

    test "returns false when sections are unchanged" do
      sections = [
        %{
          "content" => "Same content",
          "original_content" => "Same content",
          "deleted" => false
        }
      ]

      refute IssueSection.has_modifications?(sections)
    end

    test "returns true when section content is modified" do
      sections = [
        %{
          "content" => "New content",
          "original_content" => "Old content",
          "deleted" => false
        }
      ]

      assert IssueSection.has_modifications?(sections)
    end

    test "returns true when section is deleted" do
      sections = [
        %{
          "content" => "Content",
          "original_content" => "Content",
          "deleted" => true
        }
      ]

      assert IssueSection.has_modifications?(sections)
    end

    test "returns true when section is newly added" do
      sections = [
        %{
          "content" => "New section",
          "original_content" => nil,
          "deleted" => false
        }
      ]

      assert IssueSection.has_modifications?(sections)
    end

    test "returns true when any section is modified among multiple sections" do
      sections = [
        %{
          "content" => "Unchanged",
          "original_content" => "Unchanged",
          "deleted" => false
        },
        %{
          "content" => "Modified",
          "original_content" => "Original",
          "deleted" => false
        }
      ]

      assert IssueSection.has_modifications?(sections)
    end

    test "returns false for nil input" do
      refute IssueSection.has_modifications?(nil)
    end

    test "returns false for non-list input" do
      refute IssueSection.has_modifications?("not a list")
    end
  end

  describe "sections_to_markdown/1" do
    test "reassembles sections into markdown" do
      sections = [
        %{
          "id" => "section-1",
          "content" => "First paragraph",
          "locked_by" => nil,
          "position" => 0,
          "deleted" => false
        },
        %{
          "id" => "section-2",
          "content" => "Second paragraph",
          "locked_by" => nil,
          "position" => 1,
          "deleted" => false
        }
      ]

      markdown = IssueSection.sections_to_markdown(sections)

      assert markdown == "First paragraph\n\nSecond paragraph"
    end

    test "sorts sections by position before reassembling" do
      sections = [
        %{
          "id" => "section-2",
          "content" => "Second",
          "locked_by" => nil,
          "position" => 1,
          "deleted" => false
        },
        %{
          "id" => "section-1",
          "content" => "First",
          "locked_by" => nil,
          "position" => 0,
          "deleted" => false
        }
      ]

      markdown = IssueSection.sections_to_markdown(sections)

      assert markdown == "First\n\nSecond"
    end

    test "filters out deleted sections" do
      sections = [
        %{
          "id" => "section-1",
          "content" => "First paragraph",
          "locked_by" => nil,
          "position" => 0,
          "deleted" => false
        },
        %{
          "id" => "section-2",
          "content" => "Deleted paragraph",
          "locked_by" => nil,
          "position" => 1,
          "deleted" => true
        },
        %{
          "id" => "section-3",
          "content" => "Third paragraph",
          "locked_by" => nil,
          "position" => 2,
          "deleted" => false
        }
      ]

      markdown = IssueSection.sections_to_markdown(sections)

      assert markdown == "First paragraph\n\nThird paragraph"
      refute markdown =~ "Deleted paragraph"
    end

    test "returns empty string when all sections are deleted" do
      sections = [
        %{
          "id" => "section-1",
          "content" => "Deleted",
          "locked_by" => nil,
          "position" => 0,
          "deleted" => true
        }
      ]

      markdown = IssueSection.sections_to_markdown(sections)

      assert markdown == ""
    end
  end
end
