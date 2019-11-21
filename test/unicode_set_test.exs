defmodule UnicodeSetTest do
  use ExUnit.Case
  doctest Unicode.Set

  test "intersection when one list is a true subset of another" do
    l = Unicode.Category.get(:L)
    ll = Unicode.Category.get(:Ll)
    assert Unicode.Set.intersect(l, ll) == ll
  end

  test "intersection when the two lists are disjoint" do
    assert Unicode.Set.intersect([{1,1},{2,2},{3,3}], [{4,4},{5,5},{6,6}]) == []
    assert Unicode.Set.intersect([{4,4},{5,5},{6,6}], [{1,1},{2,2},{3,3}]) == []
  end

  test "union" do
    assert Unicode.Set.union([2,3,4], [1,2,3]) == [1, 2, 3, 4]
    assert Unicode.Set.union([1,2,3], [2,3,4]) == [1, 2, 3, 4]
    assert Unicode.Set.union([1,2,3], [4,5,6]) == [1, 2, 3, 4, 5, 6]
  end

  test "difference" do
    assert Unicode.Set.difference([{1,1},{2,2},{3,3}], [{1,1},{2,2},{3,3}]) == []
    assert Unicode.Set.difference([{1,1},{2,2},{3,3}], [{1,1}]) == [{2,2},{3,3}]
    assert Unicode.Set.difference([{1,1},{2,2},{3,3}], [{2,3}]) == [{1,1}]
    assert Unicode.Set.difference([{1,3},{4,10},{20,40}], [{5,9}]) == [{1,3},{4,4},{10,10},{20,40}]
  end
end
