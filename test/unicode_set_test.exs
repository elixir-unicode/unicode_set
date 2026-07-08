defmodule UnicodeSetTest do
  use ExUnit.Case
  alias Unicode.Set.{Operation, Parser, Property, Sigil, Transform}
  doctest Operation
  doctest Transform
  doctest Property
  doctest Parser
  doctest Sigil
  doctest Unicode.Regex

  test "basic character range" do
    assert Unicode.Regex.compile!("[-\\ ]").source == "[-\\ ]"
    assert Unicode.Regex.compile!("[-\\ ]").opts == [:unicode, :ucp]
  end

  test "set intersection when one list is a true subset of another" do
    l = Unicode.GeneralCategory.get(:L)
    ll = Unicode.GeneralCategory.get(:Ll)
    assert Operation.intersect(l, ll) == ll
  end

  test "set intersection when the two lists are disjoint" do
    assert Operation.intersect([{1, 1}, {2, 2}, {3, 3}], [{4, 4}, {5, 5}, {6, 6}]) == []
    assert Operation.intersect([{4, 4}, {5, 5}, {6, 6}], [{1, 1}, {2, 2}, {3, 3}]) == []
  end

  test "set union" do
    assert Operation.union([2, 3, 4], [1, 2, 3]) == [1, 2, 3, 4]
    assert Operation.union([1, 2, 3], [2, 3, 4]) == [1, 2, 3, 4]
    assert Operation.union([1, 2, 3], [4, 5, 6]) == [1, 2, 3, 4, 5, 6]
  end

  test "set difference" do
    assert Operation.difference([{1, 1}, {2, 2}, {3, 3}], [{1, 1}, {2, 2}, {3, 3}]) == []
    assert Operation.difference([{1, 1}, {2, 2}, {3, 3}], [{1, 1}]) == [{2, 2}, {3, 3}]
    assert Operation.difference([{1, 1}, {2, 2}, {3, 3}], [{2, 3}]) == [{1, 1}]

    assert Operation.difference([{1, 3}, {4, 10}, {20, 40}], [{5, 9}]) == [
             {1, 3},
             {4, 4},
             {10, 10},
             {20, 40}
           ]

    assert {:ok, _} = Unicode.Set.parse("[\\p{Grapheme_Cluster_Break=Extend}-\\p{ccc=0}]")
  end

  test "Difference when one set is wholly within another" do
    s1 = [{1, 10}]
    s2 = [{2, 3}, {7, 9}]

    assert Operation.difference(s1, s2) == [{1, 1}, {4, 6}, {10, 10}]
  end

  test "a guard module with match?/2" do
    defmodule Guards do
      require Unicode.Set

      # Define a guard that checks if a codepoint is a unicode digit
      defguard digit?(x) when Unicode.Set.match?(x, "[[:Nd:]]")
    end

    defmodule MyModule do
      require Unicode.Set
      require Guards

      # Define a function using the previously defined guard
      def my_function(<<x::utf8, _rest::binary>>) when Guards.digit?(x) do
        :digit
      end

      # Define a guard directly on the function
      def my_other_function(<<x::utf8, _rest::binary>>)
          when Unicode.Set.match?(x, "[[:Nd:]]") do
        :digit
      end
    end

    assert MyModule.my_function("3") == :digit
    assert MyModule.my_other_function("3") == :digit
  end

  test "matching on a set as a struct" do
    require Unicode.Set

    assert Unicode.Set.match?(?L, %Unicode.Set{set: "[:Lu:]"})
  end

  test "set intersection matching" do
    require Unicode.Set

    refute Unicode.Set.match?(?๓, "[[:digit:]-[:thai:]]")
    assert Unicode.Set.match?(?๓, "[[:digit:]]")
  end

  test "traverse/3" do
    {:ok, parsed} = Unicode.Set.parse("[abc]")
    fun = fn a, b, c -> {a, b, c} end

    result =
      parsed
      |> Unicode.Set.Operation.reduce()
      |> Unicode.Set.Operation.traverse(fun)

    assert result == {{97, 99}, {[], [], nil}, nil}
  end

  test "compile_pattern/1" do
    require Unicode.Set

    {:ok, pattern} = Unicode.Set.compile_pattern("[[:digit:]]")
    list = String.split("abc1def2ghi3jkl", pattern)
    assert list == ["abc", "def", "ghi", "jkl"]
  end

  test "utf8_char/1" do
    assert Unicode.Set.to_utf8_char("[[^abcd][mnb]]") == {:ok, [98, 109..110, {:not, 97..100}]}
  end

  test "string ranges" do
    assert Unicode.Set.to_pattern("[{ab}-{cd}]") ==
             {:ok, ["ab", "ac", "ad", "bb", "bc", "bd", "cb", "cc", "cd"]}

    assert Unicode.Set.to_pattern("[{ab}-{cd}abc]") ==
             {:ok, ["a", "b", "c", "ab", "ac", "ad", "bb", "bc", "bd", "cb", "cc", "cd"]}
  end

  test "nested sets" do
    assert Unicode.Set.to_pattern("[[[ab]-[b]][def]]") ==
             {:ok, ["a", "d", "e", "f"]}

    assert Unicode.Set.to_pattern("[{👦🏻}-{👦🏿}]") ==
             {:ok, ["👦🏻", "👦🏼", "👦🏽", "👦🏾", "👦🏿"]}
  end

  test "Sets of whitespace" do
    require Unicode.Set

    assert Unicode.Set.match?(?\n, "[\\n]") == true
    assert Unicode.Set.match?(?\t, "[\\t]") == true
    assert Unicode.Set.match?(?\r, "[\\r]") == true
    assert Unicode.Set.match?(?\n, "[\\r\\t\\n]") == true
  end

  test "is_whitespace matching with regex plus unicode separators" do
    require Unicode.Set

    assert Unicode.Set.match?(?\n, "[[\\u0009-\\u000d][:Zs:]]") == true
    assert Unicode.Set.match?(?\t, "[[\\u0009-\\u000d][:Zs:]]") == true
    assert Unicode.Set.match?(?\r, "[[\\u0009-\\u000d][:Zs:]]") == true
    assert Unicode.Set.match?(?\s, "[[\\u0009-\\u000d][:Zs:]]") == true
    assert Unicode.Set.match?(?a, "[[\\u0009-\\u000d][:Zs:]]") == false
  end

  test "quote marks category" do
    require Unicode.Set

    assert Unicode.Set.match?(?', "[[:QuoteMark:]]") == true
    assert Unicode.Set.match?(?', "[[:quote_mark:]]") == true
    assert Unicode.Set.match?(?', "[[:quote_mark_left:]]") == false
    assert Unicode.Set.match?(?', "[[:quote_mark_ambidextrous:]]") == true
  end

  test "printable category" do
    require Unicode.Set

    assert Unicode.Set.match?(?', "[[:printable:]]") == true
    assert Unicode.Set.match?(0, "[[:printable:]]") == false
  end

  # From TR35
  # The binary operators '&', '-', and the implicit union have equal
  # precedence and bind left-to-right. Thus [[:letter:]-[a-z]-[\u0100-\u01FF]]
  # is equal to [[[:letter:]-[a-z]]-[\u0100-\u01FF]].
  test "set oparations associativity" do
    {:ok, result1} = Unicode.Set.parse("[[:letter:]-[a-z]-[\u0100-\u01FF]]")
    {:ok, result2} = Unicode.Set.parse("[[[:letter:]-[a-z]]-[\u0100-\u01FF]]")
    assert result1.parsed == result2.parsed
  end

  # Another example is the set [[ace][bdf] - [abc][def]], which is not the
  # empty set, but instead equal to [[[[ace] [bdf]] - [abc]] [def]],
  # which equals [[[abcdef] - [abc]] [def]], which equals [[def] [def]],
  # which equals [def].
  test "set operations associativity too" do
    {:ok, result1} = Unicode.Set.parse_and_reduce("[[ace][bdf] - [abc][def]]")
    {:ok, result2} = Unicode.Set.parse_and_reduce("[[def]]")
    assert result1.parsed == result2.parsed
  end

  test "set difference operations with string ranges" do
    {:ok, parsed1} = Unicode.Set.parse_and_reduce("[[de{ef}fg]-[{ef}g]]")
    {:ok, parsed2} = Unicode.Set.parse_and_reduce("[[de{ef}fg]-[{ef}]]")

    assert {:in, [{100, 102}]} = parsed1.parsed
    assert {:in, [{100, 103}]} = parsed2.parsed
  end

  test "set intersection operations with string ranges" do
    {:ok, parsed1} = Unicode.Set.parse_and_reduce("[[de{ef}fg]&[{ef}g]]")
    {:ok, parsed2} = Unicode.Set.parse_and_reduce("[[de{ef}fg]&[{ef}]]")

    assert {:in, [{103, 103}, {~c"ef", ~c"ef"}]} = parsed1.parsed
    assert {:in, [{~c"ef", ~c"ef"}]} = parsed2.parsed
  end

  test "set intersection when set is not a Unicode set and they align" do
    {:ok, parsed} = Unicode.Set.parse_and_reduce("[[:Lu:]&[ABCD]]")
    assert {:in, [{65, 68}]} = parsed.parsed
  end

  test "parsing invalid regex" do
    assert {:error, {~c"unknown POSIX class name", _}} = Unicode.Regex.compile("[[:ZZZ:]]")
  end

  test "parsing an invalid unicode set returns the right error" do
    assert Unicode.Set.parse("[:ZZZZ:]") ==
             {:error,
              {Unicode.Set.ParseError,
               "Unable to parse \"[:ZZZZ:]\". The unicode script, category or property \"zzzz\" is not known."}}
  end

  test "parsing a single escaped character" do
    assert Unicode.Set.parse("[\\:]")
  end

  test "parsing perl and posix positive and negative regex" do
    assert Unicode.Regex.compile!("[:Zs:]").source ==
             "[\\x{20}\\x{A0}\\x{1680}\\x{2000}-\\x{200A}\\x{202F}\\x{205F}\\x{3000}]"

    assert Unicode.Regex.compile!("[:^Zs:]").source ==
             "[^\\x{20}\\x{A0}\\x{1680}\\x{2000}-\\x{200A}\\x{202F}\\x{205F}\\x{3000}]"

    assert Unicode.Regex.compile!("\\P{Zs}").source ==
             "[^\\x{20}\\x{A0}\\x{1680}\\x{2000}-\\x{200A}\\x{202F}\\x{205F}\\x{3000}]"

    assert Unicode.Regex.compile!("\\p{Zs}").source ==
             "[\\x{20}\\x{A0}\\x{1680}\\x{2000}-\\x{200A}\\x{202F}\\x{205F}\\x{3000}]"
  end

  test "union of two negated sets" do
    refute Unicode.Regex.match?("[[:^S:]&[:^Z:]]", "$")
    assert Unicode.Regex.match?("[[:^S:]&[:^Z:]]", "T")
  end

  test "to_regex_string/1 with negative sets" do
    assert Unicode.Set.to_regex_string("[[^dfd]]") == {:ok, "[^\\x{64}\\x{66}]"}

    assert Unicode.Set.to_regex_string("[[dfd][^abc{ac}][xyz{gg}]]") ==
             {:error,
              {Unicode.Set.ParseError, "Negative sets with string ranges are not supported"}}

    assert Unicode.Set.to_regex_string("[[dfd][^abc][xyz{gg}]]") ==
             {:ok, "(?:[\\x{0}-\\x{60}\\x{64}-\\x{10FFFF}]|gg)"}

    assert Unicode.Set.to_regex_string("[[dfd][^abc][xyz{gg}{hh}]]") ==
             {:ok, "(?:[\\x{0}-\\x{60}\\x{64}-\\x{10FFFF}]|hh|gg)"}
  end

  test "parse nested set with invalid property" do
    assert Unicode.Set.parse("[\\p{sdff}]") ==
             {:error,
              {Unicode.Set.ParseError,
               "Unable to parse \"[\\\\p{sdff}]\". The unicode script, category or property \"sdff\" is not known."}}
  end

  test "compile_pattern/1 returns a tagged error for negative (complement) sets" do
    error_message =
      "complement (inverse) unicode sets like [^...] are not supported for compiled patterns"

    assert {:error, {Unicode.Set.ParseError, ^error_message}} =
             Unicode.Set.compile_pattern("[^{ab}]")

    assert {:error, {Unicode.Set.ParseError, ^error_message}} =
             Unicode.Set.to_pattern("[^abc]")

    assert_raise Unicode.Set.ParseError, error_message, fn ->
      Unicode.Set.compile_pattern!("[^abc]")
    end
  end

  test "[[:IsBasicLatin:]] property syntax" do
    basic_latin = Unicode.Regex.compile!("[[:block=BasicLatin:]]")
    assert Unicode.Regex.compile!("[[:IsBasicLatin:]]").source == basic_latin.source
    assert Unicode.Regex.compile!("[[:Is BasicLatin:]]").source == basic_latin.source
    assert Unicode.Regex.compile!("[[:IsBasic_Latin:]]").source == basic_latin.source
    assert Unicode.Regex.compile!("[[:Is Basic_Latin:]]").source == basic_latin.source
    assert Unicode.Regex.compile!("[[:Is Basic Latin:]]").source == basic_latin.source
    assert Unicode.Regex.compile!("[[:is basic latin:]]").source == basic_latin.source
  end

  test "[[:^IsBasicLatin:]] property syntax" do
    basic_latin = Unicode.Regex.compile!("[[:^block=BasicLatin:]]")
    assert Unicode.Regex.compile!("[[:^IsBasicLatin:]]").source == basic_latin.source
    assert Unicode.Regex.compile!("[[:^Is BasicLatin:]]").source == basic_latin.source
    assert Unicode.Regex.compile!("[[:^IsBasic_Latin:]]").source == basic_latin.source
    assert Unicode.Regex.compile!("[[:^Is Basic_Latin:]]").source == basic_latin.source
    assert Unicode.Regex.compile!("[[:^Is Basic Latin:]]").source == basic_latin.source
    assert Unicode.Regex.compile!("[[:^is basic latin:]]").source == basic_latin.source
  end

  test "\\p{isBlockName} property syntax" do
    basic_latin = Unicode.Regex.compile!("[[:block=BasicLatin:]]")
    assert Unicode.Regex.compile!("\\p{IsBasicLatin}").source == basic_latin.source
    assert Unicode.Regex.compile!("\\p{Is BasicLatin}").source == basic_latin.source
    assert Unicode.Regex.compile!("\\p{IsBasic_Latin}").source == basic_latin.source
    assert Unicode.Regex.compile!("\\p{Is Basic_Latin}").source == basic_latin.source
    assert Unicode.Regex.compile!("\\p{Is Basic Latin}").source == basic_latin.source
    assert Unicode.Regex.compile!("\\p{is basic latin}").source == basic_latin.source
  end

  test "\\P{isBlockName} property syntax" do
    basic_latin = Unicode.Regex.compile!("[[:^block=BasicLatin:]]")
    assert Unicode.Regex.compile!("\\P{IsBasicLatin}").source == basic_latin.source
    assert Unicode.Regex.compile!("\\P{Is BasicLatin}").source == basic_latin.source
    assert Unicode.Regex.compile!("\\P{IsBasic_Latin}").source == basic_latin.source
    assert Unicode.Regex.compile!("\\P{Is Basic_Latin}").source == basic_latin.source
    assert Unicode.Regex.compile!("\\P{Is Basic Latin}").source == basic_latin.source
    assert Unicode.Regex.compile!("\\P{is basic latin}").source == basic_latin.source
  end

  # --- Phase 1: contract boundary / crash-stopping regressions ---

  describe "empty set [-]" do
    test "reduces to an empty :in set" do
      assert Unicode.Set.parse_and_reduce!("[-]").parsed == {:in, []}
    end

    test "produces empty pattern / utf8 lists and a never-matching regex" do
      assert Unicode.Set.to_pattern("[-]") == {:ok, []}
      assert Unicode.Set.to_utf8_char("[-]") == {:ok, []}
      assert Unicode.Set.to_regex_string("[-]") == {:ok, "(?!)"}
      assert Regex.match?(Unicode.Regex.compile!("(?!)"), "x") == false
    end
  end

  describe "parse/1 tagged-tuple contract (never raises)" do
    # Genuinely unsupported syntax must return a tagged error, never raise.
    for set <- [
          "[\\N{BULLET}]",
          "\\p{emoji=yes}",
          "[\\u{41 42 43}]"
        ] do
      test "returns {:error, _} for #{set}" do
        assert {:error, {Unicode.Set.ParseError, _}} = Unicode.Set.parse(unquote(set))
      end
    end
  end

  defp cp!(set) do
    assert {:ok, %{parsed: [in: [{codepoint, codepoint}]]}} = Unicode.Set.parse(set)
    codepoint
  end

  describe "backslash escapes (Phase 2)" do
    test "named control escapes map to control codes" do
      assert cp!("[\\a]") == 0x07
      assert cp!("[\\b]") == 0x08
      assert cp!("[\\e]") == 0x1B
      assert cp!("[\\f]") == 0x0C
      assert cp!("[\\v]") == 0x0B
      assert cp!("[\\t]") == 0x09
      assert cp!("[\\n]") == 0x0A
      assert cp!("[\\r]") == 0x0D
    end

    test "a backslash before a non-escape character yields that character" do
      assert cp!("[\\c]") == ?c
      assert cp!("[\\d]") == ?d
      assert cp!("[\\g]") == ?g
      assert cp!("[\\w]") == ?w
    end

    test "hex escapes decode to codepoints" do
      assert cp!("[\\x41]") == 0x41
      assert cp!("[\\x9]") == 0x09
      assert cp!("[\\u0041]") == 0x41
      assert cp!("[\\U0001F600]") == 0x1F600
      assert cp!("[\\u{1F600}]") == 0x1F600
      assert cp!("[\\x{1F600}]") == 0x1F600
    end

    test "leading whitespace after [ or [^ is ignored" do
      assert {:ok, %{parsed: [in: [{?a, ?a}, {?b, ?b}]]}} = Unicode.Set.parse("[ ab]")
      assert {:ok, %{parsed: [not_in: [{?a, ?a}, {?b, ?b}]]}} = Unicode.Set.parse("[^ ab]")
    end
  end

  describe "union of complements" do
    test "reduces without crashing and is semantically correct (De Morgan)" do
      # ¬a ∪ ¬b == ¬(a ∩ b) == everything, since {a} and {b} are disjoint.
      set = Unicode.Set.parse_and_reduce!("[[^a][^b]]")
      assert {:in, ranges} = set.parsed
      refute ranges == []

      tree = Unicode.Set.Search.build_search_tree(set)
      assert Unicode.Set.Search.member?(?a, tree)
      assert Unicode.Set.Search.member?(?b, tree)
      assert Unicode.Set.Search.member?(?z, tree)
    end

    test "emits a valid regex" do
      assert {:ok, regex_string} = Unicode.Set.to_regex_string("[[^a][^b][^c]]")
      assert {:ok, _} = Regex.compile(regex_string, "u")
    end
  end

  test "match? does not crash on an empty string" do
    reduced = Unicode.Set.parse_and_reduce!("[abc]")
    tree = Unicode.Set.Search.build_search_tree(reduced)
    refute Unicode.Set.Search.member?("", tree)
  end

  test "generate_matches/2 does not crash on a complement set" do
    assert {:ok, _} = Unicode.Set.generate_matches("[^abc]", Macro.var(:codepoint, nil))
  end
end
