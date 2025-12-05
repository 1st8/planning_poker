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
    |> smart_split_preserving_blocks()
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
  def lock_section(sections, section_id, user) do
    user_id = user["id"] || user[:id]

    case find_section(sections, section_id) do
      nil ->
        {:error, :section_not_found}

      section ->
        case section["locked_by"] do
          nil ->
            updated_sections =
              update_section(sections, section_id, fn s ->
                s
                |> Map.put("locked_by", user)
                |> Map.put("content_at_lock", s["content"])
              end)

            {:ok, updated_sections}

          %{"id" => ^user_id} ->
            # Already locked by this user
            {:ok, sections}

          _other_user ->
            {:error, :section_locked}
        end
    end
  end

  @doc """
  Unlocks a section.

  Only the user who locked the section can unlock it.
  Clears the content_at_lock field when unlocking.

  If the section content contains double newlines, it will be automatically
  split into multiple sections, with new sections marked as modified.
  """
  def unlock_section(sections, section_id, user_id) do
    case find_section(sections, section_id) do
      nil ->
        {:error, :section_not_found}

      section ->
        locked_by_id = get_in(section, ["locked_by", "id"])

        cond do
          locked_by_id == user_id ->
            updated_sections =
              update_section(sections, section_id, fn s ->
                s
                |> Map.put("locked_by", nil)
                |> Map.delete("content_at_lock")
              end)

            # Split section on double newlines after unlocking
            split_sections = split_section_on_newlines(updated_sections, section_id)
            {:ok, split_sections}

          locked_by_id == nil ->
            # Already unlocked
            {:ok, sections}

          true ->
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
        locked_by_id = get_in(section, ["locked_by", "id"])

        cond do
          locked_by_id == user_id ->
            updated_sections =
              update_section(sections, section_id, fn s ->
                content_to_restore = s["content_at_lock"] || s["content"]

                s
                |> Map.put("content", content_to_restore)
                |> Map.put("locked_by", nil)
                |> Map.delete("content_at_lock")
              end)

            {:ok, updated_sections}

          locked_by_id == nil ->
            # Already unlocked
            {:ok, sections}

          true ->
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
        locked_by_id = get_in(section, ["locked_by", "id"])

        cond do
          locked_by_id == user_id ->
            updated_sections =
              update_section(sections, section_id, fn s ->
                Map.put(s, "content", content)
              end)

            {:ok, updated_sections}

          locked_by_id == nil ->
            {:error, :section_not_locked}

          true ->
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
        locked_by_id = get_in(section, ["locked_by", "id"])

        cond do
          locked_by_id == user_id ->
            updated_sections =
              update_section(sections, section_id, fn s ->
                s
                |> Map.put("deleted", true)
                # Unlock when deleting
                |> Map.put("locked_by", nil)
              end)

            {:ok, updated_sections}

          locked_by_id == nil ->
            {:error, :section_not_locked}

          true ->
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
          updated_sections =
            update_section(sections, section_id, fn s ->
              Map.put(s, "deleted", false)
            end)

          {:ok, updated_sections}
        else
          # Already not deleted
          {:ok, sections}
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

  # Splits markdown on double newlines while preserving HTML comments, details tags, and code blocks.
  # HTML comments (<!-- ... -->), <details> tags, and fenced code blocks (```...```)
  # should not be split even if they contain double newlines internally.
  defp smart_split_preserving_blocks(markdown) do
    # Pattern to match HTML comments, details blocks, and code blocks
    # This regex captures:
    # 1. HTML comments: <!-- ... -->
    # 2. Details blocks: <details>...</details>
    # 3. Fenced code blocks: ```...``` (with optional language specifier)
    block_pattern = ~r/<!--[\s\S]*?-->|<details>[\s\S]*?<\/details>|```[\s\S]*?```/

    # Find all block matches with their positions
    blocks =
      Regex.scan(block_pattern, markdown, return: :index)
      |> Enum.map(fn [{start, length}] ->
        {start, length, String.slice(markdown, start, length)}
      end)

    # If no blocks found, use simple split
    if Enum.empty?(blocks) do
      String.split(markdown, "\n\n")
    else
      # Replace blocks with placeholders
      {marked_text, placeholder_map} =
        blocks
        |> Enum.with_index()
        |> Enum.reduce({markdown, %{}}, fn {{_start, _length, block}, index}, {text, map} ->
          placeholder = "___BLOCK_#{index}___"
          new_text = String.replace(text, block, placeholder, global: false)
          {new_text, Map.put(map, placeholder, block)}
        end)

      # Split the marked text
      marked_text
      |> String.split("\n\n")
      |> Enum.map(fn section ->
        # Restore placeholders with original blocks
        Enum.reduce(placeholder_map, section, fn {placeholder, block}, acc ->
          String.replace(acc, placeholder, block)
        end)
      end)
    end
  end

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

  defp split_section_on_newlines(sections, section_id) do
    case find_section(sections, section_id) do
      nil ->
        sections

      section ->
        # Split content on double newlines (preserving blocks)
        segments =
          section["content"]
          |> smart_split_preserving_blocks()
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        case segments do
          # No split needed - single segment or empty
          [] ->
            sections

          [_single] ->
            sections

          # Multiple segments - need to split
          [first_segment | remaining_segments] ->
            # Update the original section with first segment
            updated_original = %{section | "content" => first_segment}

            # Create new sections for remaining segments (all marked as modified)
            new_sections =
              Enum.map(remaining_segments, fn segment ->
                %{
                  "id" => "temp-#{:erlang.unique_integer([:positive])}",
                  "content" => segment,
                  # Mark as new/modified
                  "original_content" => nil,
                  "locked_by" => nil,
                  # Will be updated in renumbering
                  "position" => 0,
                  "deleted" => false
                }
              end)

            # Find the position to insert new sections
            original_position = section["position"]

            # Split sections into before and after
            {before, after_including_original} =
              Enum.split_while(sections, fn s -> s["position"] < original_position end)

            # Remove the original from the after list
            after_sections =
              Enum.reject(after_including_original, fn s -> s["id"] == section_id end)

            # Combine: before + updated_original + new_sections + after
            combined = before ++ [updated_original] ++ new_sections ++ after_sections

            # Renumber all sections sequentially
            combined
            |> Enum.with_index()
            |> Enum.map(fn {s, index} ->
              %{s | "id" => "section-#{index}", "position" => index}
            end)
        end
    end
  end
end
