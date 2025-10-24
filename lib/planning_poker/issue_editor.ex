defmodule PlanningPoker.IssueEditor do
  @moduledoc """
  Handles collaborative editing of issue descriptions by splitting them into
  sections (separated by double newlines) with unique IDs.
  """

  @doc """
  Parses markdown into sections, each with a unique ID.

  Sections are split on double newlines (\\n\\n) to preserve natural markdown boundaries.

  ## Examples

      iex> parse_markdown("# Title\\n\\nParagraph 1\\n\\nParagraph 2")
      [
        %{id: "sec_...", content: "# Title", order: 0},
        %{id: "sec_...", content: "Paragraph 1", order: 1},
        %{id: "sec_...", content: "Paragraph 2", order: 2}
      ]
  """
  def parse_markdown(nil), do: []
  def parse_markdown(""), do: []

  def parse_markdown(markdown) when is_binary(markdown) do
    markdown
    |> String.split("\n\n")
    |> Enum.with_index()
    |> Enum.map(fn {content, index} ->
      %{
        id: generate_section_id(),
        content: String.trim(content),
        order: index
      }
    end)
    |> Enum.reject(fn section -> section.content == "" end)
  end

  @doc """
  Converts sections back to markdown by joining with double newlines.

  ## Examples

      iex> sections_to_markdown([
      ...>   %{id: "sec_1", content: "# Title", order: 0},
      ...>   %{id: "sec_2", content: "Paragraph 1", order: 1}
      ...> ])
      "# Title\\n\\nParagraph 1"
  """
  def sections_to_markdown(sections) do
    sections
    |> Enum.sort_by(& &1.order)
    |> Enum.map(& &1.content)
    |> Enum.join("\n\n")
  end

  @doc """
  Generates a unique section ID.

  Format: "sec_" followed by 12 URL-safe random characters.
  """
  def generate_section_id do
    random_string =
      :crypto.strong_rand_bytes(9)
      |> Base.url_encode64(padding: false)

    "sec_#{random_string}"
  end

  @doc """
  Finds a section by ID.
  """
  def find_section(sections, section_id) do
    Enum.find(sections, fn section -> section.id == section_id end)
  end

  @doc """
  Updates a section's content by ID.
  """
  def update_section(sections, section_id, new_content) do
    Enum.map(sections, fn section ->
      if section.id == section_id do
        %{section | content: new_content}
      else
        section
      end
    end)
  end

  @doc """
  Inserts a new empty section after the given section ID.
  """
  def insert_section_after(sections, after_section_id) do
    after_index = Enum.find_index(sections, fn s -> s.id == after_section_id end)

    case after_index do
      nil ->
        # Section not found, append to end
        sections ++ [%{id: generate_section_id(), content: "", order: length(sections)}]

      index ->
        # Insert after the found section and reorder
        {before, after_list} = Enum.split(sections, index + 1)
        new_section = %{id: generate_section_id(), content: "", order: index + 1}

        (before ++ [new_section] ++ after_list)
        |> reorder_sections()
    end
  end

  @doc """
  Deletes a section by ID.
  """
  def delete_section(sections, section_id) do
    sections
    |> Enum.reject(fn s -> s.id == section_id end)
    |> reorder_sections()
  end

  @doc """
  Reorders sections sequentially based on their current position in the list.
  """
  def reorder_sections(sections) do
    sections
    |> Enum.with_index()
    |> Enum.map(fn {section, index} ->
      %{section | order: index}
    end)
  end

  @doc """
  Converts markdown content to HTML.
  """
  def markdown_to_html(markdown) when is_binary(markdown) do
    case Earmark.as_html(markdown) do
      {:ok, html, _} -> html
      _ -> markdown
    end
  end

  def markdown_to_html(_), do: ""
end
