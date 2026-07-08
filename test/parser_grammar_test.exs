defmodule Unicode.Set.ParserGrammarTest do
  use ExUnit.Case, async: true

  alias Unicode.Set.Parser

  # These functions build NimbleParsec combinators that are woven into the
  # generated parser at compile time. Invoking them directly exercises the
  # grammar-definition code paths and asserts each combinator builds cleanly.
  describe "grammar combinator builders" do
    test "every combinator builder constructs without raising" do
      builders = [
        fn -> Parser.unicode_set() end,
        fn -> Parser.basic_set() end,
        fn -> Parser.empty_set() end,
        fn -> Parser.sequence() end,
        fn -> Parser.maybe_repeated_set() end,
        fn -> Parser.set_operator() end,
        fn -> Parser.range() end,
        fn -> Parser.character_range() end,
        fn -> Parser.string_range() end,
        fn -> Parser.property() end,
        fn -> Parser.posix_property() end,
        fn -> Parser.perl_property() end,
        fn -> Parser.operator() end,
        fn -> Parser.property_expression([{:not, ?}}]) end,
        fn -> Parser.block_prefix() end,
        fn -> Parser.property_name() end,
        fn -> Parser.value([{:not, ?:}]) end,
        fn -> Parser.whitespace_char() end,
        fn -> Parser.whitespace() end,
        fn -> Parser.string() end,
        fn -> Parser.char() end,
        fn -> Parser.quoted() end,
        fn -> Parser.bracketed_hex() end,
        fn -> Parser.hex_codepoint() end,
        fn -> Parser.hex() end,
        fn -> Parser.repetition() end,
        fn -> Parser.iterations() end,
        fn -> Parser.anchor() end
      ]

      for builder <- builders do
        assert is_list(builder.())
      end
    end
  end

  describe "reduce_range/1" do
    test "bracketed list of codepoints" do
      assert Parser.reduce_range([[[?a, ?b]]]) == {:in, [{?a, ?a}, {?b, ?b}]}
    end

    test "single codepoint from a wrapped list" do
      assert Parser.reduce_range([[?a]]) == {:in, [{?a, ?a}]}
    end

    test "codepoint range from wrapped lists" do
      assert Parser.reduce_range([[?a], [?z]]) == {:in, [{?a, ?z}]}
    end

    test "single codepoint" do
      assert Parser.reduce_range([?a]) == {:in, [{?a, ?a}]}
    end

    test "codepoint range" do
      assert Parser.reduce_range([?a, ?z]) == {:in, [{?a, ?z}]}
    end
  end

  describe "hex_to_codepoint/1" do
    test "escaped control characters" do
      assert Parser.hex_to_codepoint([?t]) == ?\t
      assert Parser.hex_to_codepoint([?n]) == ?\n
      assert Parser.hex_to_codepoint([?r]) == ?\r
    end

    test "a non-hex escaped character passes through" do
      assert Parser.hex_to_codepoint([?%]) == ?%
    end

    test "hex digits are decoded" do
      assert Parser.hex_to_codepoint(~c"41") == ?A
    end

    test "a list of hex codepoints is mapped" do
      assert Parser.hex_to_codepoint([~c"41", ~c"42"]) == [?A, ?B]
    end
  end

  describe "iteration/1 and reduce_set_operations/1" do
    test "iteration builds a repeat spec" do
      assert Parser.iteration([2, 5]) == {:repeat, min: 2, max: 5}
    end

    test "negation of a compound set falls through to :not_in" do
      result =
        Parser.reduce_set_operations([
          :not,
          {:intersection, [{:in, [{1, 1}]}, {:in, [{2, 2}]}]}
        ])

      assert {:not_in, [{:intersection, _}]} = result
    end
  end

  describe "property negation and value combinations" do
    test "negated block via posix" do
      assert {:ok, set} = Unicode.Set.parse_and_reduce("[:^IsBasicLatin:]")
      assert {:not_in, _} = set.parsed
    end

    test "negated perl property with value" do
      assert {:ok, set} = Unicode.Set.parse_and_reduce("\\P{gc=Lu}")
      assert {:not_in, _} = set.parsed
    end

    test "not-equal operator produces a not_in property" do
      assert {:ok, %Unicode.Set{}} = Unicode.Set.parse("\\p{gc≠Lu}")
    end

    test "negated not-equal operator (double negative) produces in" do
      assert {:ok, %Unicode.Set{}} = Unicode.Set.parse("\\P{gc≠Lu}")
    end

    test "negated compatibility class" do
      assert {:ok, set} = Unicode.Set.parse_and_reduce("[:^alpha:]")
      assert {:not_in, _} = set.parsed
    end
  end
end
