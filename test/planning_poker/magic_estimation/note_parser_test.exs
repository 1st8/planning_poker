defmodule PlanningPoker.MagicEstimation.NoteParserTest do
  use ExUnit.Case, async: true

  alias PlanningPoker.MagicEstimation.NoteParser

  doctest PlanningPoker.MagicEstimation.NoteParser

  describe "parse/1 — abstain (rules 1 & 2)" do
    test "nil is abstain" do
      assert NoteParser.parse(nil) == :abstain
    end

    test "empty string is abstain" do
      assert NoteParser.parse("") == :abstain
    end

    test "whitespace-only is abstain" do
      assert NoteParser.parse("   ") == :abstain
      assert NoteParser.parse("\t\n") == :abstain
    end

    test "single question mark is abstain" do
      assert NoteParser.parse("?") == :abstain
    end

    test "multiple question marks are abstain" do
      assert NoteParser.parse("??") == :abstain
      assert NoteParser.parse("???") == :abstain
      assert NoteParser.parse("????") == :abstain
    end

    test "question marks surrounded by whitespace are abstain" do
      assert NoteParser.parse("  ??  ") == :abstain
    end
  end

  describe "parse/1 — exact numbers (rule 3)" do
    test "integers" do
      assert NoteParser.parse("0") == {:ok, 0.0}
      assert NoteParser.parse("1") == {:ok, 1.0}
      assert NoteParser.parse("5") == {:ok, 5.0}
      assert NoteParser.parse("13") == {:ok, 13.0}
      assert NoteParser.parse("100") == {:ok, 100.0}
    end

    test "decimal with dot" do
      assert NoteParser.parse("5.0") == {:ok, 5.0}
      assert NoteParser.parse("5.5") == {:ok, 5.5}
      assert NoteParser.parse("0.5") == {:ok, 0.5}
    end

    test "decimal with comma" do
      assert NoteParser.parse("5,5") == {:ok, 5.5}
      assert NoteParser.parse("0,5") == {:ok, 0.5}
      assert NoteParser.parse("13,25") == {:ok, 13.25}
    end

    test "trims surrounding whitespace" do
      assert NoteParser.parse(" 5 ") == {:ok, 5.0}
      assert NoteParser.parse("\t5\n") == {:ok, 5.0}
    end
  end

  describe "parse/1 — ranges (rule 4)" do
    test "ascii hyphen" do
      assert NoteParser.parse("3-5") == {:ok, 4.0}
      assert NoteParser.parse("1-3") == {:ok, 2.0}
    end

    test "ascii hyphen with spaces" do
      assert NoteParser.parse("3 - 5") == {:ok, 4.0}
      assert NoteParser.parse("5  -  8") == {:ok, 6.5}
    end

    test "en-dash (U+2013)" do
      assert NoteParser.parse("3\u20135") == {:ok, 4.0}
      assert NoteParser.parse("3 \u2013 5") == {:ok, 4.0}
    end

    test "em-dash (U+2014)" do
      assert NoteParser.parse("3\u20145") == {:ok, 4.0}
    end

    test "figure dash (U+2012)" do
      assert NoteParser.parse("3\u20125") == {:ok, 4.0}
    end

    test "reversed range still averages" do
      assert NoteParser.parse("5-3") == {:ok, 4.0}
      assert NoteParser.parse("8-5") == {:ok, 6.5}
    end

    test "decimals inside ranges" do
      assert NoteParser.parse("0.5-1.5") == {:ok, 1.0}
      assert NoteParser.parse("2,5-3,5") == {:ok, 3.0}
    end
  end

  describe "parse/1 — fuzz prefixes (rule 5)" do
    test "tilde prefix" do
      assert NoteParser.parse("~5") == {:ok, 5.0}
      assert NoteParser.parse("~ 5") == {:ok, 5.0}
      assert NoteParser.parse("~5.5") == {:ok, 5.5}
    end

    test "approx symbol prefix (≈)" do
      assert NoteParser.parse("\u22485") == {:ok, 5.0}
      assert NoteParser.parse("\u2248 8") == {:ok, 8.0}
    end

    test "ca. prefix" do
      assert NoteParser.parse("ca. 5") == {:ok, 5.0}
      assert NoteParser.parse("ca.5") == {:ok, 5.0}
      assert NoteParser.parse("ca. 13") == {:ok, 13.0}
    end

    test "about prefix" do
      assert NoteParser.parse("about 13") == {:ok, 13.0}
      assert NoteParser.parse("about 8") == {:ok, 8.0}
    end

    test "fuzz prefix with commentary still parses leading number" do
      assert NoteParser.parse("~5 (gut)") == {:ok, 5.0}
      assert NoteParser.parse("ca. 8, denke ich") == {:ok, 8.0}
    end
  end

  describe "parse/1 — number with trailing commentary (rule 6)" do
    test "number followed by parenthesized comment" do
      assert NoteParser.parse("5 (gut)") == {:ok, 5.0}
      assert NoteParser.parse("5(gut)") == {:ok, 5.0}
      assert NoteParser.parse("13 (unsure)") == {:ok, 13.0}
    end

    test "number followed by comma commentary" do
      assert NoteParser.parse("5, schaut euch das an") == {:ok, 5.0}
      assert NoteParser.parse("8,aber") == {:ok, 8.0}
    end

    test "number followed by whitespace and words" do
      assert NoteParser.parse("5 SP") == {:ok, 5.0}
      assert NoteParser.parse("13 story points") == {:ok, 13.0}
    end

    test "decimal followed by commentary" do
      assert NoteParser.parse("5.5 maybe") == {:ok, 5.5}
    end
  end

  describe "parse/1 — unparseable (rule 7)" do
    test "words are unparseable" do
      assert NoteParser.parse("foo") == :unparseable
      assert NoteParser.parse("unsure") == :unparseable
    end

    test "negative numbers are unparseable" do
      assert NoteParser.parse("-5") == :unparseable
      assert NoteParser.parse("-5.5") == :unparseable
      assert NoteParser.parse("-0") == :unparseable
    end

    test "hexadecimal is unparseable" do
      assert NoteParser.parse("0xFF") == :unparseable
      assert NoteParser.parse("0x10") == :unparseable
    end

    test "non-numeric leading token is unparseable" do
      assert NoteParser.parse("abc 5") == :unparseable
      assert NoteParser.parse("SP 5") == :unparseable
    end

    test "half-broken range is unparseable" do
      assert NoteParser.parse("3-") == :unparseable
      assert NoteParser.parse("-5") == :unparseable
      assert NoteParser.parse("3-foo") == :unparseable
      assert NoteParser.parse("foo-5") == :unparseable
    end

    test "bare dash is unparseable" do
      assert NoteParser.parse("-") == :unparseable
      assert NoteParser.parse("\u2013") == :unparseable
    end

    test "percent or other units without leading number are unparseable" do
      assert NoteParser.parse("%5") == :unparseable
    end
  end

  describe "nearest_marker/2" do
    test "returns the closest marker (default options)" do
      assert NoteParser.nearest_marker(4.0) == 5
      assert NoteParser.nearest_marker(1.4) == 1
      # 0.7 is 0.2 away from 0.5 and 0.3 away from 1, so 0.5 wins.
      assert NoteParser.nearest_marker(0.7) == 0.5
      assert NoteParser.nearest_marker(0.8) == 1
    end

    test "uses the provided marker list" do
      markers = [1, 2, 3, 5, 8]
      assert NoteParser.nearest_marker(4.0, markers: markers) == 5
      assert NoteParser.nearest_marker(2.4, markers: markers) == 2
      assert NoteParser.nearest_marker(2.5, markers: markers) == 3
    end

    test "ties go up" do
      # Halfway between 5 and 8 → 8
      assert NoteParser.nearest_marker(6.5, markers: [5, 8]) == 8
      # Halfway between 2 and 3 → 3
      assert NoteParser.nearest_marker(2.5, markers: [2, 3]) == 3
    end

    test "values beyond the highest marker snap to the highest" do
      assert NoteParser.nearest_marker(100, markers: [1, 2, 3]) == 3
    end

    test "values below the smallest marker snap to the smallest" do
      assert NoteParser.nearest_marker(0, markers: [1, 2, 3]) == 1
      assert NoteParser.nearest_marker(-5, markers: [1, 2, 3]) == 1
    end

    test "accepts unsorted marker lists" do
      assert NoteParser.nearest_marker(4.0, markers: [8, 1, 5, 3, 2]) == 5
    end

    test "nil value returns nil" do
      assert NoteParser.nearest_marker(nil) == nil
      assert NoteParser.nearest_marker(nil, markers: [1, 2, 3]) == nil
    end

    test "empty marker list returns nil" do
      assert NoteParser.nearest_marker(5, markers: []) == nil
    end

    test "works with decimal markers (e.g. 0.5 Fibonacci)" do
      assert NoteParser.nearest_marker(0.6, markers: [0.5, 1, 2]) == 0.5
      assert NoteParser.nearest_marker(0.8, markers: [0.5, 1, 2]) == 1
    end
  end

  describe "default_markers/0" do
    test "returns a non-empty sorted-friendly list" do
      markers = NoteParser.default_markers()
      assert is_list(markers)
      assert length(markers) > 0
      assert Enum.all?(markers, &is_number/1)
    end
  end
end
