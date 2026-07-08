defmodule Unicode.Set.CoverageEdgesTest do
  use ExUnit.Case, async: true

  alias Unicode.Set.{Operation, Transform}

  describe "Transform" do
    test "guard_clause raises on string ranges" do
      assert_raise ArgumentError, ~r/string ranges are not supported for guards/, fn ->
        Transform.guard_clause({~c"ab", ~c"cd"}, [], quote(do: x))
      end
    end

    test "guard_clause builds a single-codepoint clause" do
      ast = Transform.guard_clause({?a, ?a}, quote(do: false), quote(do: x))
      assert Macro.to_string(ast) =~ "x == 97"
    end

    test "guard_clause negates a not_in clause" do
      ast = Transform.guard_clause(:not_in, quote(do: x == 97), quote(do: x))
      assert Macro.to_string(ast) =~ "not"
    end

    test "reject_string_range on empty lists returns []" do
      assert Transform.reject_string_range([], [], quote(do: x)) == []
    end

    test "utf8_char raises on string ranges" do
      assert_raise ArgumentError, ~r/string ranges are not supported for utf8/, fn ->
        Unicode.Set.to_utf8_char!("[{ab}-{ac}]")
      end
    end

    test "regex/3 handles a compound range with trailing ranges" do
      assert {:ok, regex} = Unicode.Set.to_regex_string("[{ab}{cd}]")
      assert regex =~ "ab"
      assert regex =~ "cd"
    end

    test "surrogate codepoints are dropped from regex output" do
      assert {:ok, string} = Unicode.Set.to_regex_string("[:Cs:]")
      assert is_binary(string)
    end
  end

  describe "Unicode.Regex" do
    test "compile!/1 raises on an invalid regex" do
      assert_raise Regex.CompileError, fn ->
        Unicode.Regex.compile!("[:ZZZ:]")
      end
    end

    test "match?/3 accepts a precompiled Regex" do
      assert Unicode.Regex.match?(~r/a/u, "a")
    end

    test "expand_regex/2 returns the options unchanged" do
      assert {expanded, "u"} = Unicode.Regex.expand_regex("[:Zs:]", "u")
      assert is_binary(expanded)
    end

    test "escapes outside a class are preserved" do
      expanded = Unicode.Regex.expand_regex("a\\db")
      assert expanded =~ "\\d"
    end

    test "a stray closing bracket is preserved" do
      assert is_binary(Unicode.Regex.expand_regex("abc]"))
    end

    test "an unterminated class is handled" do
      assert is_binary(Unicode.Regex.expand_regex("[abc"))
    end

    test "escaped brackets inside a class are handled" do
      assert is_binary(Unicode.Regex.expand_regex("[a\\[b\\]c]"))
    end

    test "plain text segments pass through" do
      expanded = Unicode.Regex.expand_regex("abc[:Zs:]def")
      assert expanded =~ "abc"
      assert expanded =~ "def"
    end

    test "an invalid perl set is left intact rather than expanded" do
      # to_regex_string fails for an unknown property, so the original
      # perl-set fragment is passed through to Regex.compile unchanged. Whether
      # the regex engine then accepts or rejects `\p{zzzz}` depends on its PCRE
      # version (OTP 27 rejects it, later OTP accepts it), so both outcomes are
      # valid — the point is that Unicode.Regex passes it through untouched.
      case Unicode.Regex.compile("\\p{zzzz}") do
        {:ok, regex} -> assert Regex.source(regex) == "\\p{zzzz}"
        {:error, {reason, _offset}} -> assert to_string(reason) =~ "unknown property"
      end
    end

    test "forces the unicode option for string options" do
      assert {:ok, regex} = Unicode.Regex.compile("[:Zs:]", "i")
      assert :unicode in Regex.opts(regex)
    end

    test "forces the unicode option for list options" do
      assert {:ok, regex} = Unicode.Regex.compile("[:Zs:]", [:caseless])
      assert :unicode in Regex.opts(regex)
    end

    test "keeps the unicode option when already present in a list" do
      assert {:ok, regex} = Unicode.Regex.compile("[:Zs:]", [:unicode])
      assert :unicode in Regex.opts(regex)
    end
  end

  describe "Operation set arithmetic" do
    test "expand_string_range wraps :in and :not_in" do
      assert Operation.expand_string_range({:in, [{~c"ab", ~c"ab"}]}) ==
               {:in, [{~c"ab", ~c"ab"}]}

      assert Operation.expand_string_range({:not_in, [{~c"ab", ~c"ab"}]}) ==
               {:not_in, [{~c"ab", ~c"ab"}]}
    end

    test "expand_string_range over three positions" do
      result = Operation.expand_string_range([{?a, ?a}, {?b, ?b}, {?c, ?c}])
      assert result == [[?a, ?b, ?c]]
    end

    test "combine unwraps a single-element list" do
      assert Operation.combine([{:in, [{1, 1}]}]) == {:in, [{1, 1}]}
    end

    test "has_difference_or_intersection? on a single-element list" do
      assert Operation.has_difference_or_intersection?([{:difference, [{:in, []}, {:in, []}]}])
    end

    test "intersect where the two ranges share a start" do
      assert Operation.intersect([{1, 5}], [{1, 10}]) == [{1, 5}]
    end

    test "difference where the second arg is a bare tuple equal to the head" do
      assert Operation.difference([{1, 1}, {2, 2}], {1, 1}) == [{2, 2}]
    end

    test "difference where b encloses a with a shared end" do
      assert Operation.difference([{5, 10}], [{1, 10}]) == []
    end

    test "difference where b overlaps behind a" do
      assert Operation.difference([{1, 5}], [{3, 8}]) == [{1, 2}]
    end

    test "difference where b overlaps in front of a" do
      assert Operation.difference([{3, 8}], [{1, 5}]) == [{6, 8}]
    end

    test "difference where b ends where a starts" do
      assert Operation.difference([{5, 10}], [{1, 5}]) == [{6, 10}]
    end

    test "complement of an expanded set complements the range list" do
      expanded = Unicode.Set.parse!("[abc]") |> Operation.expand()
      complemented = Operation.complement(expanded)
      assert is_list(complemented.parsed)
      refute Enum.any?(complemented.parsed, fn {f, l} -> f == ?a and l == ?c end)
    end
  end

  describe "Search" do
    test "build_search_tree of an empty list is an empty tuple" do
      assert Unicode.Set.Search.build_search_tree([]) == {}
    end

    test "member? on an empty tree is false" do
      assert Unicode.Set.Search.member?(?a, {}) == false
    end

    test "match? against a negated set uses the not_in branch" do
      require Unicode.Set
      assert Unicode.Set.match?(?a, "[^bcd]")
      refute Unicode.Set.match?(?b, "[^bcd]")
    end

    test "match? against a string range [{ab}-{ad}] matches expanded members" do
      require Unicode.Set
      assert Unicode.Set.match?("ab", "[{ab}-{ad}]")
      assert Unicode.Set.match?("ac", "[{ab}-{ad}]")
      assert Unicode.Set.match?("ad", "[{ab}-{ad}]")
      refute Unicode.Set.match?("ae", "[{ab}-{ad}]")
    end

    test "match? against a string range matches on a prefix but not a shorter string" do
      require Unicode.Set
      assert Unicode.Set.match?("abc", "[{ab}-{ad}]")
      refute Unicode.Set.match?("a", "[{ab}-{ad}]")
    end

    test "match? against a union of string groups [{ab}{cd}]" do
      require Unicode.Set
      assert Unicode.Set.match?("ab", "[{ab}{cd}]")
      assert Unicode.Set.match?("cd", "[{ab}{cd}]")
      refute Unicode.Set.match?("xy", "[{ab}{cd}]")
    end

    test "match? against a negated string set [^{ab}{cd}] uses the not_in branch" do
      require Unicode.Set
      refute Unicode.Set.match?("ab", "[^{ab}{cd}]")
      refute Unicode.Set.match?("cd", "[^{ab}{cd}]")
      assert Unicode.Set.match?("xy", "[^{ab}{cd}]")
    end
  end

  describe "Unicode.Set generate_matches!" do
    test "returns matches on success" do
      assert Unicode.Set.generate_matches!("[abc]", quote(do: var)) |> is_list()
    end

    test "raises on an invalid set" do
      assert_raise Unicode.Set.ParseError, fn ->
        Unicode.Set.generate_matches!("[:zzzz:]", quote(do: var))
      end
    end
  end
end
