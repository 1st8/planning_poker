defmodule PlanningPoker.MagicEstimation.NoteParser do
  @moduledoc """
  Pure parser for free-form estimation notes written by voters.

  The parser converts a human-authored string (from the "note" field of a
  planning-poker vote) into one of three outcomes:

    * `{:ok, float}` — a numeric estimate could be extracted
    * `:abstain`     — the note is blank or consists only of question marks
    * `:unparseable` — the note contains something the parser cannot interpret

  This module is deliberately free of side effects, PubSub, I/O and process
  state. It is intended to be called both from the authoritative server-side
  code (e.g. the `PlanningSession` state machine) and, eventually, ported
  verbatim to a JavaScript hook sharing identical semantics.

  ## Rules (applied in order)

  1. `nil` or the empty string (after `String.trim/1`) is `:abstain`.
  2. Any run of `?` (e.g. `"?"`, `"??"`, `"???"`) after trimming is `:abstain`.
  3. An exact non-negative integer or decimal (with `.` or `,` as decimal
     separator) returns `{:ok, float}`.
  4. A range `<a><dash><b>` — where `<dash>` is `-`, `–` (en-dash),
     `—` (em-dash), or `‒` (figure dash), optionally surrounded by spaces —
     returns `{:ok, (a + b) / 2}`. Reversed ranges (`"5-3"`) still produce the
     same average.
  5. Leading fuzz tokens (`~`, `≈`, `ca.`, `about `) followed by an otherwise
     valid number return the number.
  6. A leading non-negative number followed by whitespace, `(`, or `,` and
     arbitrary commentary returns the leading number.
  7. Anything else (non-numeric leading token, negative numbers, hexadecimal,
     words, …) returns `:unparseable`.

  ## Examples

      iex> NoteParser.parse(nil)
      :abstain

      iex> NoteParser.parse("   ")
      :abstain

      iex> NoteParser.parse("??")
      :abstain

      iex> NoteParser.parse("5")
      {:ok, 5.0}

      iex> NoteParser.parse("5,5")
      {:ok, 5.5}

      iex> NoteParser.parse("3-5")
      {:ok, 4.0}

      iex> NoteParser.parse("3–5")
      {:ok, 4.0}

      iex> NoteParser.parse("5-3")
      {:ok, 4.0}

      iex> NoteParser.parse("~5")
      {:ok, 5.0}

      iex> NoteParser.parse("ca. 8")
      {:ok, 8.0}

      iex> NoteParser.parse("about 13")
      {:ok, 13.0}

      iex> NoteParser.parse("5 (gut)")
      {:ok, 5.0}

      iex> NoteParser.parse("5, schaut euch das an")
      {:ok, 5.0}

      iex> NoteParser.parse("5 SP")
      {:ok, 5.0}

      iex> NoteParser.parse("-5")
      :unparseable

      iex> NoteParser.parse("foo")
      :unparseable
  """

  # All dash variants that are treated as range separators.
  @dashes ["-", "\u2010", "\u2011", "\u2012", "\u2013", "\u2014", "\u2015"]

  # Non-negative decimal with optional `.` or `,` fraction.
  @number_source "\\d+(?:[.,]\\d+)?"
  @number_only_regex Regex.compile!("^#{@number_source}$")

  # Range: <num> [space] <dash> [space] <num>
  # We use an alternation rather than a character class so multi-byte dashes
  # (en-dash, em-dash, figure dash, …) are matched as whole code points under
  # Unicode mode.
  @dash_alt Enum.map_join(@dashes, "|", &Regex.escape/1)
  @range_regex Regex.compile!(
                 "^(#{@number_source})\\s*(?:#{@dash_alt})\\s*(#{@number_source})$",
                 "u"
               )

  # Number followed by commentary that starts with whitespace, `(` or `,`.
  @number_with_commentary_regex Regex.compile!("^(#{@number_source})(?:[\\s(,].*)$")

  # Leading fuzz tokens. These are stripped in order before re-parsing as a
  # number. Note: we only accept fuzz with a plain number after it, not a range
  # (per spec: rule 5 says "followed by a valid number").
  @fuzz_prefixes [
    {"~", ""},
    {"\u2248", ""},
    {"ca.", ""},
    {"about ", ""}
  ]

  @typedoc "The three possible outcomes of `parse/1`."
  @type result :: {:ok, float()} | :abstain | :unparseable

  @doc """
  Parses a free-form note into a numeric estimate, `:abstain`, or `:unparseable`.

  See the module documentation for the ordered set of rules.
  """
  @spec parse(String.t() | nil) :: result()
  def parse(nil), do: :abstain

  def parse(note) when is_binary(note) do
    trimmed = String.trim(note)

    cond do
      trimmed == "" ->
        :abstain

      only_question_marks?(trimmed) ->
        :abstain

      true ->
        parse_trimmed(trimmed)
    end
  end

  # -- internal -------------------------------------------------------------

  defp only_question_marks?(str) do
    str != "" and String.replace(str, "?", "") == ""
  end

  defp parse_trimmed(str) do
    with :error <- try_exact_number(str),
         :error <- try_range(str),
         :error <- try_fuzz(str),
         :error <- try_number_with_commentary(str) do
      :unparseable
    end
  end

  defp try_exact_number(str) do
    if Regex.match?(@number_only_regex, str) do
      {:ok, to_float(str)}
    else
      :error
    end
  end

  defp try_range(str) do
    case Regex.run(@range_regex, str, capture: :all_but_first) do
      [a_str, b_str] ->
        a = to_float(a_str)
        b = to_float(b_str)
        {:ok, (a + b) / 2}

      _ ->
        :error
    end
  end

  defp try_fuzz(str) do
    case strip_fuzz(str) do
      {:ok, rest} ->
        # After stripping fuzz, accept a plain number (rule 5). We also allow
        # the commentary form (rule 6) so `"~5 (gut)"` parses like `"5 (gut)"`.
        with :error <- try_exact_number(rest),
             :error <- try_number_with_commentary(rest) do
          :error
        end

      :error ->
        :error
    end
  end

  defp strip_fuzz(str) do
    Enum.find_value(@fuzz_prefixes, :error, fn {prefix, _} ->
      if String.starts_with?(str, prefix) do
        rest = String.trim_leading(String.replace_prefix(str, prefix, ""))
        {:ok, rest}
      else
        nil
      end
    end)
  end

  defp try_number_with_commentary(str) do
    case Regex.run(@number_with_commentary_regex, str, capture: :all_but_first) do
      [num_str] -> {:ok, to_float(num_str)}
      _ -> :error
    end
  end

  defp to_float(str) do
    {float, ""} =
      str
      |> String.replace(",", ".")
      |> then(fn s ->
        if String.contains?(s, ".") do
          Float.parse(s)
        else
          Float.parse(s <> ".0")
        end
      end)

    float
  end

  # -- markers --------------------------------------------------------------

  @default_markers [0.5, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89]

  @doc """
  Returns the marker from `options[:markers]` that is closest to `value`.

  Ties (where `value` is equidistant between two markers) go **up** to the
  larger marker — the intentional bias for planning-poker estimation.

  The `markers` option, if given, must be a non-empty list of numbers. It will
  be sorted internally, so order doesn't matter. If omitted, a sensible default
  Fibonacci-like scale is used:

      #{inspect(@default_markers)}

  Returns `nil` when `value` is not a number.

  ## Options

    * `:markers` — list of numeric marker values. Default: `#{inspect(@default_markers)}`.

  ## Examples

      iex> NoteParser.nearest_marker(4.0, [])
      5

      iex> NoteParser.nearest_marker(4.0, markers: [1, 2, 3, 5, 8])
      5

      iex> NoteParser.nearest_marker(6.5, markers: [5, 8])
      8

      iex> NoteParser.nearest_marker(6.4, markers: [5, 8])
      5

      iex> NoteParser.nearest_marker(100, markers: [1, 2, 3])
      3

      iex> NoteParser.nearest_marker(nil, [])
      nil
  """
  @spec nearest_marker(number() | nil, keyword()) :: number() | nil
  def nearest_marker(value, options \\ [])

  def nearest_marker(nil, _options), do: nil

  def nearest_marker(value, options) when is_number(value) do
    markers =
      options
      |> Keyword.get(:markers, @default_markers)
      |> Enum.sort()

    case markers do
      [] ->
        nil

      [_ | _] ->
        Enum.reduce(markers, nil, fn marker, best ->
          cond do
            best == nil ->
              marker

            abs(marker - value) < abs(best - value) ->
              marker

            abs(marker - value) == abs(best - value) and marker > best ->
              # Tie goes up to the larger marker.
              marker

            true ->
              best
          end
        end)
    end
  end

  @doc """
  The default list of markers used by `nearest_marker/2` when no `:markers`
  option is provided.
  """
  @spec default_markers() :: [number()]
  def default_markers, do: @default_markers
end
