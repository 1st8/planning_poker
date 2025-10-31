defmodule PlanningPoker.IssueSectionTest do
  use ExUnit.Case, async: true

  alias PlanningPoker.IssueSection

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
      {:ok, updated} = IssueSection.lock_section(sections, "section-1", "user-123")

      section = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section["locked_by"] == "user-123"
    end

    test "allows same user to lock already locked section", %{sections: sections} do
      {:ok, sections} = IssueSection.lock_section(sections, "section-1", "user-123")
      {:ok, updated} = IssueSection.lock_section(sections, "section-1", "user-123")

      section = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section["locked_by"] == "user-123"
    end

    test "prevents locking section locked by another user", %{sections: sections} do
      {:ok, sections} = IssueSection.lock_section(sections, "section-1", "user-123")
      result = IssueSection.lock_section(sections, "section-1", "user-456")

      assert result == {:error, :section_locked}
    end

    test "returns error for non-existent section", %{sections: sections} do
      result = IssueSection.lock_section(sections, "non-existent", "user-123")

      assert result == {:error, :section_not_found}
    end
  end

  describe "unlock_section/3" do
    setup do
      sections = [
        %{"id" => "section-1", "content" => "Test", "locked_by" => "user-123", "position" => 0},
        %{"id" => "section-2", "content" => "Test 2", "locked_by" => nil, "position" => 1}
      ]

      {:ok, sections: sections}
    end

    test "unlocks a section locked by the user", %{sections: sections} do
      {:ok, updated} = IssueSection.unlock_section(sections, "section-1", "user-123")

      section = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section["locked_by"] == nil
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
  end

  describe "update_section_content/4" do
    setup do
      sections = [
        %{"id" => "section-1", "content" => "Old content", "locked_by" => "user-123", "position" => 0}
      ]

      {:ok, sections: sections}
    end

    test "updates content when user owns the lock", %{sections: sections} do
      {:ok, updated} = IssueSection.update_section_content(sections, "section-1", "New content", "user-123")

      section = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section["content"] == "New content"
    end

    test "prevents update when user does not own the lock", %{sections: sections} do
      result = IssueSection.update_section_content(sections, "section-1", "New content", "user-456")

      assert result == {:error, :not_lock_owner}
    end

    test "prevents update when section is not locked" do
      sections = [
        %{"id" => "section-1", "content" => "Old content", "locked_by" => nil, "position" => 0}
      ]

      result = IssueSection.update_section_content(sections, "section-1", "New content", "user-123")

      assert result == {:error, :section_not_locked}
    end

    test "returns error for non-existent section", %{sections: sections} do
      result = IssueSection.update_section_content(sections, "non-existent", "New content", "user-123")

      assert result == {:error, :section_not_found}
    end
  end

  describe "mark_section_deleted/3" do
    setup do
      sections = [
        %{
          "id" => "section-1",
          "content" => "Test content",
          "locked_by" => "user-123",
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
