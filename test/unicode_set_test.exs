defmodule UnicodeSetTest do
  use ExUnit.Case
  alias Unicode.Set.Operation
  doctest Operation

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

    assert Unicode.Set.match?(?๓, "[[:digit:]-[:thai:]]") == false
    assert Unicode.Set.match?(?๓, "[[:digit:]]") == true
  end

  test "traverse/3" do
    {:ok, parsed, "", _, _, _} = Unicode.Set.parse("[abc]")
    fun = fn a, b, c -> {a, b, c} end

    result =
      parsed
      |> Unicode.Set.Operation.expand()
      |> Unicode.Set.Operation.traverse(fun)

    assert result == {{97, 99}, {[], [], nil}, nil}
  end

  test "compile_pattern/1" do
    require Unicode.Set

    pattern = Unicode.Set.compile_pattern("[[:digit:]]")
    list = String.split("abc1def2ghi3jkl", pattern)
    assert list == ["abc", "def", "ghi", "jkl"]
  end

  test "utf8_char/1" do
    assert Unicode.Set.utf8_char("[[^abcd][mnb]]") ==
             [{:not, 97}, {:not, 98}, {:not, 99}, {:not, 100}, 98, 109, 110]
  end

  test "string ranges" do
    assert Unicode.Set.pattern("[{ab}-{cd}]") ==
             ["ab", "ac", "ad", "bb", "bc", "bd", "cb", "cc", "cd"]

    assert Unicode.Set.pattern("[{ab}-{cd}abc]") ==
             ["a", "b", "c", "ab", "ac", "ad", "bb", "bc", "bd", "cb", "cc", "cd"]
  end

  test "nested sets" do
    assert Unicode.Set.pattern("[[[ab]-[b]][def]]") ==
             ["a", "d", "e", "f"]

    assert Unicode.Set.pattern("[{👦🏻}-{👦🏿}]") ==
             ["👦🏻", "👦🏼", "👦🏽", "👦🏾", "👦🏿"]
  end

  test "Sets of whitespace" do
    require Unicode.Set

    assert Unicode.Set.match?(?\n, "[\n]") == true
    assert Unicode.Set.match?(?\t, "[\t]") == true
    assert Unicode.Set.match?(?\r, "[\r]") == true
    assert Unicode.Set.match?(?\n, "[\r\t\n]") == true
  end

  test "is_whitespace matching with regex plus unicode separators" do
    require Unicode.Set

    assert Unicode.Set.match?(?\n, "[[\u0009-\u000d][:Zs:]]") == true
    assert Unicode.Set.match?(?\t, "[[\u0009-\u000d][:Zs:]]") == true
    assert Unicode.Set.match?(?\r, "[[\u0009-\u000d][:Zs:]]") == true
    assert Unicode.Set.match?(?\s, "[[\u0009-\u000d][:Zs:]]") == true
    assert Unicode.Set.match?(?a, "[[\u0009-\u000d][:Zs:]]") == false
  end

  test "quote marks category" do
    require Unicode.Set

    assert Unicode.Set.match?(?', "[[:QuoteMark:]]") == true
    assert Unicode.Set.match?(?', "[[:quote_mark:]]") == true
    assert Unicode.Set.match?(?', "[[:quote_mark_left:]]") == false
    assert Unicode.Set.match?(?', "[[:quote_mark_ambidextrous:]]") == true
  end
end
