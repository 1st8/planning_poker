defmodule PlanningPoker.IssueSection do
  @moduledoc """
  Handles parsing and managing issue description sections for collaborative editing.

  Sections are created by splitting markdown text on double newlines (paragraph boundaries).
  Each section gets a unique ID and can be locked by a single user during editing.
  """

  @doc """
  Parses markdown text into sections.

  Splits on double newlines and creates a section for each paragraph.
  Empty sections are filtered out.

  ## Examples

      iex> parse_into_sections("First paragraph\\n\\nSecond paragraph")
      [
        %{"id" => "section-0", "content" => "First paragraph", "locked_by" => nil, "position" => 0},
        %{"id" => "section-1", "content" => "Second paragraph", "locked_by" => nil, "position" => 1}
      ]
  """
  def parse_into_sections(nil), do: []
  def parse_into_sections(""), do: []

  def parse_into_sections(markdown) when is_binary(markdown) do
    markdown
    |> String.split("\n\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.with_index()
    |> Enum.map(fn {content, index} ->
      %{
        "id" => "section-#{index}",
        "content" => content,
        "original_content" => content,
        "locked_by" => nil,
        "position" => index,
        "deleted" => false
      }
    end)
  end

  @doc """
  Locks a section for a specific user.

  Returns `{:ok, updated_sections}` if the section was successfully locked,
  or `{:error, reason}` if the section is already locked by another user.
  """
  def lock_section(sections, section_id, user_id) do
    case find_section(sections, section_id) do
      nil ->
        {:error, :section_not_found}

      section ->
        case section["locked_by"] do
          nil ->
            updated_sections = update_section(sections, section_id, fn s ->
              s
              |> Map.put("locked_by", user_id)
              |> Map.put("content_at_lock", s["content"])
            end)
            {:ok, updated_sections}

          ^user_id ->
            {:ok, sections}  # Already locked by this user

          _other_user ->
            {:error, :section_locked}
        end
    end
  end

  @doc """
  Unlocks a section.

  Only the user who locked the section can unlock it.
  Clears the content_at_lock field when unlocking.
  """
  def unlock_section(sections, section_id, user_id) do
    case find_section(sections, section_id) do
      nil ->
        {:error, :section_not_found}

      section ->
        case section["locked_by"] do
          ^user_id ->
            updated_sections = update_section(sections, section_id, fn s ->
              s
              |> Map.put("locked_by", nil)
              |> Map.delete("content_at_lock")
            end)
            {:ok, updated_sections}

          nil ->
            {:ok, sections}  # Already unlocked

          _other_user ->
            {:error, :not_lock_owner}
        end
    end
  end

  @doc """
  Cancels editing a section and restores the original content.

  Restores content to what it was when the section was locked,
  then unlocks the section. Only the user who locked it can cancel.
  """
  def cancel_section_edit(sections, section_id, user_id) do
    case find_section(sections, section_id) do
      nil ->
        {:error, :section_not_found}

      section ->
        case section["locked_by"] do
          ^user_id ->
            updated_sections = update_section(sections, section_id, fn s ->
              content_to_restore = s["content_at_lock"] || s["content"]
              s
              |> Map.put("content", content_to_restore)
              |> Map.put("locked_by", nil)
              |> Map.delete("content_at_lock")
            end)
            {:ok, updated_sections}

          nil ->
            {:ok, sections}  # Already unlocked

          _other_user ->
            {:error, :not_lock_owner}
        end
    end
  end

  @doc """
  Updates the content of a section.

  Only the user who has the section locked can update it.
  """
  def update_section_content(sections, section_id, content, user_id) do
    case find_section(sections, section_id) do
      nil ->
        {:error, :section_not_found}

      section ->
        case section["locked_by"] do
          ^user_id ->
            updated_sections = update_section(sections, section_id, fn s ->
              Map.put(s, "content", content)
            end)
            {:ok, updated_sections}

          nil ->
            {:error, :section_not_locked}

          _other_user ->
            {:error, :not_lock_owner}
        end
    end
  end


  @doc """
  Marks a section as deleted (soft delete).

  Only the user who has the section locked can mark it as deleted.
  Returns `{:ok, updated_sections}` on success.
  """
  def mark_section_deleted(sections, section_id, user_id) do
    case find_section(sections, section_id) do
      nil ->
        {:error, :section_not_found}

      section ->
        case section["locked_by"] do
          ^user_id ->
            updated_sections = update_section(sections, section_id, fn s ->
              s
              |> Map.put("deleted", true)
              |> Map.put("locked_by", nil)  # Unlock when deleting
            end)
            {:ok, updated_sections}

          nil ->
            {:error, :section_not_locked}

          _other_user ->
            {:error, :not_lock_owner}
        end
    end
  end

  @doc """
  Restores a deleted section.

  Unmarks a section as deleted, making it visible again.
  Returns `{:ok, updated_sections}` on success.
  """
  def restore_section(sections, section_id) do
    case find_section(sections, section_id) do
      nil ->
        {:error, :section_not_found}

      section ->
        if section["deleted"] do
          updated_sections = update_section(sections, section_id, fn s ->
            Map.put(s, "deleted", false)
          end)
          {:ok, updated_sections}
        else
          {:ok, sections}  # Already not deleted
        end
    end
  end

  @doc """
  Checks if any sections have been modified, added, or deleted.

  Returns true if:
  - Any section's content differs from original_content
  - Any section is marked as deleted
  - Any section has original_content == nil (newly added)
  """
  def has_modifications?(sections) when is_list(sections) do
    Enum.any?(sections, fn section ->
      section["deleted"] == true ||
      section["original_content"] == nil ||
      section["content"] != section["original_content"]
    end)
  end

  def has_modifications?(_), do: false

  @doc """
  Reassembles sections back into markdown text.

  Filters out deleted sections before joining.
  """
  def sections_to_markdown(sections) do
    sections
    |> Enum.reject(& &1["deleted"])
    |> Enum.sort_by(& &1["position"])
    |> Enum.map(& &1["content"])
    |> Enum.join("\n\n")
  end

  # Private helpers

  defp find_section(sections, section_id) do
    Enum.find(sections, fn s -> s["id"] == section_id end)
  end

  defp update_section(sections, section_id, update_fn) do
    Enum.map(sections, fn section ->
      if section["id"] == section_id do
        update_fn.(section)
      else
        section
      end
    end)
  end
end
