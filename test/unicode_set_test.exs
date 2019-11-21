defmodule UnicodeSetTest do
  use ExUnit.Case
  doctest Unicode.Set

  test "intersection" do
    l = Unicode.Category.get(:L)
    ll = Unicode.Category.get(:Ll)
    assert Unicode.Set.intersect(l, ll) == ll
  end

  test "union" do
    assert Unicode.Set.union([2,3,4], [1,2,3]) == [1, 2, 3, 4]
    assert Unicode.Set.union([1,2,3], [2,3,4]) == [1, 2, 3, 4]
    assert Unicode.Set.union([1,2,3], [4,5,6]) == [1, 2, 3, 4, 5, 6]
  end

  test "subtraction" do

  end
end
