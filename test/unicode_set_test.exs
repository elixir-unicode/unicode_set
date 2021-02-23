defmodule UnicodeSetTest do
  use ExUnit.Case
  alias Unicode.Set.{Operation, Transform, Property, Parser, Sigil}
  doctest Operation
  doctest Transform
  doctest Property
  doctest Parser
  doctest Sigil
  doctest Unicode.Regex

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

    assert {:in, [{103, 103}, {'ef', 'ef'}]} = parsed1.parsed
    assert {:in, [{'ef', 'ef'}]} = parsed2.parsed
  end

  test "set intersection when set is not a Unicode set and they align" do
    {:ok, parsed} = Unicode.Set.parse_and_reduce("[[:Lu:]&[ABCD]]")
    assert {:in, [{65, 68}]} = parsed.parsed
  end

  test "parsing invalid regex" do
    assert Unicode.Regex.compile("[[:ZZZ:]]") ==
             {:error, {'unknown POSIX class name', 3}}
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
    assert Unicode.Regex.compile("[:Zs:]") ==
             {:ok, ~r/[\x{20}\x{A0}\x{1680}\x{2000}-\x{200A}\x{202F}\x{205F}\x{3000}]/u}

    assert Unicode.Regex.compile("[:^Zs:]") ==
             {:ok, ~r/[^\x{20}\x{A0}\x{1680}\x{2000}-\x{200A}\x{202F}\x{205F}\x{3000}]/u}

    assert Unicode.Regex.compile("\\P{Zs}") ==
             {:ok, ~r/[^\x{20}\x{A0}\x{1680}\x{2000}-\x{200A}\x{202F}\x{205F}\x{3000}]/u}

    assert Unicode.Regex.compile("\\p{Zs}") ==
             {:ok, ~r/[\x{20}\x{A0}\x{1680}\x{2000}-\x{200A}\x{202F}\x{205F}\x{3000}]/u}
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

  test "compile_string/1 raises with negative string classes" do
    error_message = "complement (inverse) unicode sets like [^...] are not supported for compiled patterns"

    assert_raise ArgumentError, error_message, fn ->
      Unicode.Set.compile_pattern("[^{ab}]")
    end
  end

  test "[[:IsBasicLatin:]] property syntax" do
    basic_latin = Unicode.Regex.compile!("[[:block=BasicLatin:]]")
    assert Unicode.Regex.compile!("[[:IsBasicLatin:]]") == basic_latin
    assert Unicode.Regex.compile!("[[:Is BasicLatin:]]") == basic_latin
    assert Unicode.Regex.compile!("[[:IsBasic_Latin:]]") == basic_latin
    assert Unicode.Regex.compile!("[[:Is Basic_Latin:]]") == basic_latin
    assert Unicode.Regex.compile!("[[:Is Basic Latin:]]") == basic_latin
    assert Unicode.Regex.compile!("[[:is basic latin:]]") == basic_latin
  end

  test "[[:^IsBasicLatin:]] property syntax" do
    basic_latin = Unicode.Regex.compile!("[[:^block=BasicLatin:]]")
    assert Unicode.Regex.compile!("[[:^IsBasicLatin:]]") == basic_latin
    assert Unicode.Regex.compile!("[[:^Is BasicLatin:]]") == basic_latin
    assert Unicode.Regex.compile!("[[:^IsBasic_Latin:]]") == basic_latin
    assert Unicode.Regex.compile!("[[:^Is Basic_Latin:]]") == basic_latin
    assert Unicode.Regex.compile!("[[:^Is Basic Latin:]]") == basic_latin
    assert Unicode.Regex.compile!("[[:^is basic latin:]]") == basic_latin
  end

  test "\\p{isBlockName} property syntax" do
    basic_latin = Unicode.Regex.compile!("[[:block=BasicLatin:]]")
    assert Unicode.Regex.compile!("\\p{IsBasicLatin}") == basic_latin
    assert Unicode.Regex.compile!("\\p{Is BasicLatin}") == basic_latin
    assert Unicode.Regex.compile!("\\p{IsBasic_Latin}") == basic_latin
    assert Unicode.Regex.compile!("\\p{Is Basic_Latin}") == basic_latin
    assert Unicode.Regex.compile!("\\p{Is Basic Latin}") == basic_latin
    assert Unicode.Regex.compile!("\\p{is basic latin}") == basic_latin
  end

  test "\\P{isBlockName} property syntax" do
    basic_latin = Unicode.Regex.compile!("[[:^block=BasicLatin:]]")
    assert Unicode.Regex.compile!("\\P{IsBasicLatin}") == basic_latin
    assert Unicode.Regex.compile!("\\P{Is BasicLatin}") == basic_latin
    assert Unicode.Regex.compile!("\\P{IsBasic_Latin}") == basic_latin
    assert Unicode.Regex.compile!("\\P{Is Basic_Latin}") == basic_latin
    assert Unicode.Regex.compile!("\\P{Is Basic Latin}") == basic_latin
    assert Unicode.Regex.compile!("\\P{is basic latin}") == basic_latin
  end
end
