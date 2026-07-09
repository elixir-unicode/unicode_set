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
    # `[-\ ]` is the set of a literal (leading) hyphen and an escaped space; it
    # now parses as a Unicode set and expands to those two codepoints.
    regex = Unicode.Regex.compile!("[-\\ ]")
    assert regex.source == "[\\x{20}\\x{2D}]"
    assert regex.opts == [:unicode, :ucp]
    assert Regex.match?(regex, "-")
    assert Regex.match?(regex, " ")
    refute Regex.match?(regex, "x")
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
          "\\p{emoji=yes}",
          "[\\N{NOT A REAL NAME}]"
        ] do
      test "returns {:error, _} for #{set}" do
        assert {:error, {Unicode.Set.ParseError, _}} = Unicode.Set.parse(unquote(set))
      end
    end

    test "\\N{name} resolves when the unicode dependency provides names, else errors cleanly" do
      if Code.ensure_loaded?(Unicode.CharacterName) do
        assert Unicode.Set.parse_and_reduce!("[\\N{BULLET}]").parsed == {:in, [{0x2022, 0x2022}]}
      else
        assert {:error, {Unicode.Set.ParseError, _}} = Unicode.Set.parse("[\\N{BULLET}]")
      end
    end
  end

  defp cp!(set) do
    assert {:ok, %{parsed: [in: [{codepoint, codepoint}]]}} = Unicode.Set.parse(set)
    codepoint
  end

  defp members(set) do
    {:in, ranges} = Unicode.Set.parse_and_reduce!(set).parsed

    ranges
    |> Enum.flat_map(fn
      {from, to} when is_integer(from) and is_integer(to) -> Enum.to_list(from..to)
      _string -> []
    end)
    |> Enum.map(&<<&1::utf8>>)
  end

  defp contains?(set, codepoint) do
    {:in, ranges} = Unicode.Set.parse_and_reduce!(set).parsed

    Enum.any?(ranges, fn
      {from, to} when is_integer(from) and is_integer(to) -> codepoint in from..to
      _string -> false
    end)
  end

  defp compiled(set) do
    {:ok, regex_string} = Unicode.Set.to_regex_string(set)
    {:ok, regex} = Regex.compile(regex_string, "u")
    regex
  end

  defp same?(set_a, set_b) do
    Unicode.Set.parse_and_reduce!(set_a).parsed == Unicode.Set.parse_and_reduce!(set_b).parsed
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

  describe "set-operation precedence and correctness (Phase 3)" do
    test "operators bind left-to-right across a juxtaposition boundary (SOP-1)" do
      assert members("[[a-f]-[b][g]&[g-z]]") == ["g"]
      assert members("[[a-f]&[a-e][d-f]-[b]]") == ["a", "c", "d", "e", "f"]
      assert members("[[c][a-z]&[b]]") == ["b"]
      assert members("[[a-z]&[b][c]]") == ["b", "c"]
    end

    test "README precedence example matches its documented result" do
      require Unicode.Set
      refute Unicode.Set.match?(0x41, "[[:letter:] - [a-z] [:number:] & [\\u0100-\\u01FF]]")
      assert Unicode.Set.match?(0x100, "[[:letter:] - [a-z] [:number:] & [\\u0100-\\u01FF]]")
    end

    test "a bracket-grouped union feeding a difference subtracts correctly (SOC-1)" do
      refute contains?("[[\\P{L}[0-9]]-[5]]", ?5)
      refute contains?("[[[:^Lu:][a-z]]-[m]]", ?m)
    end

    test "reversed and mismatched-length ranges are rejected, not silently accepted" do
      assert {:error, {Unicode.Set.ParseError, _}} = Unicode.Set.parse("[z-a]")
      assert {:error, {Unicode.Set.ParseError, _}} = Unicode.Set.parse("[{abc}-{de}]")
    end
  end

  describe "regex emission (Phase 4)" do
    test "string members are PCRE-escaped so they match literally (RE-1)" do
      assert Unicode.Set.to_regex_string("[{a.c}]") == {:ok, "(?:a\\.c)"}
      refute Regex.match?(compiled("[{a.c}]"), "aXc")
      assert Regex.match?(compiled("[{a.c}]"), "a.c")
      # A metacharacter that would otherwise produce an uncompilable regex.
      assert Regex.match?(compiled("[x{a)b}]"), "a)b")
    end

    test "a set of multiple string members emits no empty character class (SR-1)" do
      {:ok, regex_string} = Unicode.Set.to_regex_string("[{ab}{cd}]")
      refute String.contains?(regex_string, "[]")
      assert Regex.match?(compiled("[{ab}{cd}]"), "ab")
      refute Regex.match?(compiled("[{ab}{cd}]"), "[")
    end

    test "string-range alternations are grouped so they compose when embedded (RE-4)" do
      assert Unicode.Regex.expand_regex("x[{ab}-{cd}]y") == "x(?:ab|ac|ad|bb|bc|bd|cb|cc|cd)y"
      regex = Unicode.Regex.compile!("x[{ab}-{cd}]y")
      refute Regex.match?(regex, "cdy")
      assert Regex.match?(regex, "xaby")
    end

    test "surrogate endpoints are clipped, not emitted as a dangling hyphen (RE-2)" do
      {:ok, regex_string} = Unicode.Set.to_regex_string("[[\\uD000-\\uE7FF]-[\\uD500-\\uD600]]")
      refute String.starts_with?(regex_string, "[-")
      assert {:ok, _} = Regex.compile(regex_string, "u")
    end

    test "a set of only surrogates yields a never-matching regex, not [] (RE-5)" do
      assert Unicode.Set.to_regex_string("[\\uD800]") == {:ok, "(?!)"}
    end

    test "a class containing an escaped backslash is split correctly (RS-2)" do
      assert Unicode.Regex.split_character_classes("[a\\\\]xyz") == ["", "[a\\\\]", "xyz"]
    end
  end

  describe "property name resolution (Phase 5)" do
    test "hyphens in property names are ignored (PS-1)" do
      assert same?("[\\p{White-Space}]", "[\\p{Whitespace}]")
      assert {:ok, _} = Unicode.Set.parse("[[:Quotation-Mark:]]")
    end

    test "Is<name> resolves as script/category/property before block (GAP-ISPREFIX)" do
      assert same?("[\\p{IsAlphabetic}]", "[\\p{Alphabetic}]")
      assert same?("[[:IsLowercase:]]", "[\\p{Lowercase}]")
      assert same?("[\\p{IsLatin}]", "[\\p{Latin}]")
      assert same?("[\\p{IsGreek}]", "[\\p{Greek}]")
    end

    test "Is<Block> still resolves to a block when the name is not a script/category/property" do
      assert same?("[\\p{IsBasicLatin}]", "[\\p{block=BasicLatin}]")

      assert Unicode.Regex.compile!("[[:^IsBasicLatin:]]").source ==
               Unicode.Regex.compile!("[[:^block=BasicLatin:]]").source
    end

    test "digit-bearing block names resolve (PS-7 workaround)" do
      assert {:in, [{128, 255}]} =
               Unicode.Set.parse_and_reduce!("[\\p{block=Latin-1 Supplement}]").parsed

      assert same?("[\\p{IsLatin1Supplement}]", "[\\p{block=Latin-1 Supplement}]")
    end

    test "Java-style In<Block> prefix resolves as a block, leaving In... names alone (PS-8)" do
      assert same?("[\\p{InBasicLatin}]", "[\\p{block=BasicLatin}]")
      assert {:ok, _} = Unicode.Set.parse("[\\p{Inherited}]")
    end

    test "the LC / Cased_Letter group category resolves to Lu|Ll|Lt (GAP-LC)" do
      assert same?("[\\p{Cased_Letter}]", "[\\p{Lu}\\p{Ll}\\p{Lt}]")
      assert same?("[\\p{gc=LC}]", "[\\p{Lu}\\p{Ll}\\p{Lt}]")
      assert same?("[\\p{gc=Cased_Letter}]", "[\\p{gc=LC}]")
      assert {:ok, _} = Unicode.Set.parse("[[:gc=LC:]]")
    end

    test "an empty property value errors instead of silently mis-parsing (GAP-PROPEXPR-SET)" do
      assert {:error, {Unicode.Set.ParseError, _}} = Unicode.Set.parse("[\\p{gc=}]")
      assert {:error, {Unicode.Set.ParseError, _}} = Unicode.Set.parse("[\\p{scx=}]")
    end
  end

  describe "empty set and boundary hyphens (Phase 6)" do
    test "[] and [-] are the empty set" do
      assert Unicode.Set.parse_and_reduce!("[]").parsed == {:in, []}
      assert Unicode.Set.parse_and_reduce!("[-]").parsed == {:in, []}
    end

    test "a hyphen at the start or end of a set is a literal hyphen" do
      assert members("[-a]") == ["-", "a"]
      assert members("[a-]") == ["-", "a"]
      assert members("[-abc]") == ["-", "a", "b", "c"]
      assert members("[a-z-]") == ["-" | Enum.map(?a..?z, &<<&1::utf8>>)]
    end

    test "a leading hyphen is honoured under negation" do
      assert Unicode.Set.parse_and_reduce!("[^-a]").parsed == {:not_in, [{?-, ?-}, {?a, ?a}]}
    end

    test "the range and difference operators are unaffected" do
      assert members("[a-c]") == ["a", "b", "c"]
      refute "-" in members("[a-c]")
      assert members("[[a-f][d-k]-[c-g]]") == ["a", "b", "h", "i", "j", "k"]
    end
  end

  describe "additional escapes and quoting (Phase 7)" do
    test "octal \\0ooo escapes" do
      assert cp!("[\\0]") == 0x00
      assert cp!("[\\010]") == 0x08
      assert cp!("[\\0101]") == ?A
    end

    test "\\cX control escapes" do
      assert cp!("[\\cH]") == 0x08
      assert cp!("[\\ca]") == 0x01
      assert cp!("[\\cZ]") == 0x1A
    end

    test "single-quote quoting makes the enclosed text literal" do
      assert members("['a-z']") == ["-", "a", "z"]
      assert members("['']") == ["'"]
      assert members("['[]']") == ["[", "]"]
    end

    test "the empty-string member [{}] is supported" do
      assert Unicode.Set.parse_and_reduce!("[{}]").parsed == {:in, [{~c"", ~c""}]}
    end

    test "multi-codepoint bracketed hex is a string member" do
      assert Unicode.Set.parse_and_reduce!("[\\u{41 42 43}]").parsed ==
               {:in, [{~c"ABC", ~c"ABC"}]}
    end

    test "\\Q..\\E literal spans are not expanded by the regex splitter" do
      assert Unicode.Regex.expand_regex("^\\Qa[b]c\\E$") == "^\\Qa[b]c\\E$"
      assert Regex.match?(Unicode.Regex.compile!("^\\Qa[b]c\\E$"), "a[b]c")
    end

    test "(?#..) comments are not expanded by the regex splitter" do
      assert Unicode.Regex.expand_regex("x(?#a[:L:]b)y") == "x(?#a[:L:]b)y"
    end
  end
end
