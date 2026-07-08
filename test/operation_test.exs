defmodule Unicode.Set.OperationTest do
  use ExUnit.Case, async: true

  alias Unicode.Set.Operation

  describe "reduce/1" do
    test "is idempotent on an already reduced set" do
      reduced = Unicode.Set.parse_and_reduce!("[abc]")
      assert Operation.reduce(reduced) == reduced
    end

    test "is a no-op on an expanded set" do
      expanded = Unicode.Set.parse!("[abc]") |> Operation.expand()
      assert Operation.reduce(expanded) == expanded
    end
  end

  describe "expand/1" do
    test "is idempotent on an already expanded set" do
      expanded = Unicode.Set.parse!("[abc]") |> Operation.expand()
      assert Operation.expand(expanded) == expanded
    end

    test "expands a union of ranges" do
      set = Unicode.Set.parse!("[[abc][xyz]]") |> Operation.expand()
      assert [{97, 99}, {120, 122}] = set.parsed
    end

    test "expands a difference of ranges" do
      set = Unicode.Set.parse!("[[a-z]-[aeiou]]") |> Operation.expand()
      ranges = set.parsed
      refute Enum.any?(ranges, fn {f, l} -> f <= ?a and ?a <= l end)
    end

    test "expands an intersection of ranges" do
      set = Unicode.Set.parse!("[[a-m]&[h-z]]") |> Operation.expand()
      assert [{?h, ?m}] = set.parsed
    end
  end

  describe "union/2" do
    test "merges overlapping and adjacent ranges, sorts and dedups" do
      # {2, 2} is already inside {1, 3}, and {5, 5} is duplicated.
      assert Operation.union([{1, 3}, {5, 5}], [{2, 2}, {5, 5}]) == [{1, 3}, {5, 5}]
      # adjacent ranges coalesce
      assert Operation.union([{1, 3}], [{4, 6}]) == [{1, 6}]
    end
  end

  describe "intersect/2" do
    test "empty when either list is empty" do
      assert Operation.intersect([{1, 5}], []) == []
      assert Operation.intersect([], [{1, 5}]) == []
    end

    test "overlapping ranges to the left and right" do
      assert Operation.intersect([{1, 10}], [{5, 15}]) == [{5, 10}]
      assert Operation.intersect([{5, 15}], [{1, 10}]) == [{5, 10}]
    end

    test "enclosed range" do
      assert Operation.intersect([{1, 20}], [{5, 10}]) == [{5, 10}]
    end
  end

  describe "difference/2" do
    test "identical single elements cancel" do
      assert Operation.difference([{1, 1}], [{1, 1}]) == []
    end

    test "list-b entirely after list-a head" do
      assert Operation.difference([{1, 3}], [{10, 12}]) == [{1, 3}]
    end

    test "list-b entirely before list-a head" do
      assert Operation.difference([{10, 12}], [{1, 3}]) == [{10, 12}]
    end

    test "empty first list" do
      assert Operation.difference([], [{1, 3}]) == []
    end
  end

  describe "symmetric_difference/2" do
    test "returns codepoints in either but not both" do
      assert Operation.symmetric_difference([{1, 3}], [{5, 8}]) ==
               [{1, 3}, {5, 8}]
    end
  end

  describe "complement/1" do
    test "flips :in to :not_in on a reduced struct" do
      set = Unicode.Set.parse_and_reduce!("[abc]")
      complemented = Operation.complement(set)
      assert {:not_in, _} = complemented.parsed
    end

    test "flips :not_in back to :in" do
      set = Unicode.Set.parse_and_reduce!("[^abc]")
      complemented = Operation.complement(set)
      assert {:in, _} = complemented.parsed
    end

    test "reduces a parsed struct before complementing" do
      set = Unicode.Set.parse!("[abc]")
      assert %Unicode.Set{} = Operation.complement(set)
    end

    test "complement of a range list is its difference from all codepoints" do
      complemented = Operation.complement([{?a, ?z}])
      refute Enum.any?(complemented, fn {f, l} -> f == ?a and l == ?z end)
    end
  end

  describe "combine/1" do
    test "flattens a union tree" do
      assert Operation.combine({:union, [{:in, [{1, 1}]}, {:in, [{2, 2}]}]}) ==
               [{:in, [{1, 1}]}, {:in, [{2, 2}]}]
    end

    test "returns non-union nodes unchanged" do
      assert Operation.combine({:in, [{1, 1}]}) == {:in, [{1, 1}]}
    end
  end

  describe "has_difference_or_intersection?/1" do
    test "true for difference and intersection" do
      assert Operation.has_difference_or_intersection?({:difference, [{:in, []}, {:in, []}]})
      assert Operation.has_difference_or_intersection?({:intersection, [{:in, []}, {:in, []}]})
    end

    test "false for a plain union of ranges" do
      refute Operation.has_difference_or_intersection?({:union, [{:in, []}, {:in, []}]})
    end
  end
end
