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

  describe "add_section/3" do
    setup do
      sections = [
        %{"id" => "section-1", "content" => "First", "locked_by" => nil, "position" => 0},
        %{"id" => "section-2", "content" => "Second", "locked_by" => nil, "position" => 1}
      ]

      {:ok, sections: sections}
    end

    test "adds new section at specified position", %{sections: sections} do
      updated = IssueSection.add_section(sections, 1, "user-123")

      assert length(updated) == 3

      # Check the new section is at position 1
      new_section = Enum.find(updated, &(&1["position"] == 1 && &1["content"] == ""))
      assert new_section != nil
      assert new_section["locked_by"] == "user-123"
    end

    test "increments positions of sections at or after new position", %{sections: sections} do
      updated = IssueSection.add_section(sections, 1, "user-123")

      # Original section-2 should now be at position 2
      section_2 = Enum.find(updated, &(&1["id"] == "section-2"))
      assert section_2["position"] == 2
    end

    test "adds section at the beginning", %{sections: sections} do
      updated = IssueSection.add_section(sections, 0, "user-123")

      assert length(updated) == 3

      # Original sections should be shifted
      section_1 = Enum.find(updated, &(&1["id"] == "section-1"))
      assert section_1["position"] == 1
    end

    test "adds section at the end", %{sections: sections} do
      updated = IssueSection.add_section(sections, 2, "user-123")

      assert length(updated) == 3

      new_section = Enum.find(updated, &(&1["position"] == 2 && &1["content"] == ""))
      assert new_section != nil
    end

    test "locks new section for the creator", %{sections: sections} do
      updated = IssueSection.add_section(sections, 1, "user-123")

      new_section = Enum.find(updated, &(&1["position"] == 1 && &1["content"] == ""))
      assert new_section["locked_by"] == "user-123"
    end
  end

  describe "sections_to_markdown/1" do
    test "reassembles sections into markdown" do
      sections = [
        %{"id" => "section-1", "content" => "First paragraph", "locked_by" => nil, "position" => 0},
        %{"id" => "section-2", "content" => "Second paragraph", "locked_by" => nil, "position" => 1}
      ]

      markdown = IssueSection.sections_to_markdown(sections)

      assert markdown == "First paragraph\n\nSecond paragraph"
    end

    test "sorts sections by position before reassembling" do
      sections = [
        %{"id" => "section-2", "content" => "Second", "locked_by" => nil, "position" => 1},
        %{"id" => "section-1", "content" => "First", "locked_by" => nil, "position" => 0}
      ]

      markdown = IssueSection.sections_to_markdown(sections)

      assert markdown == "First\n\nSecond"
    end
  end
end
