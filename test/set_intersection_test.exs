defmodule Unicode.Set.IntersectionTest do
  use ExUnit.Case

  for {category, _} <- Unicode.GeneralCategory.categories() do
    test "Check intersection of a set and its complement for #{category} is always []" do
      cat = unquote(category)
      set = "[[:#{cat}:]&[:^#{cat}:]]"
      assert Unicode.Set.to_utf8_char(set) == []
    end

    test "Check difference of a set and its complement for #{category} is always the set" do
      cat = unquote(category)
      set = "[:#{cat}:]"
      difference = "[[:#{cat}:]-[:^#{cat}:]]"
      assert Unicode.Set.to_utf8_char(difference) == Unicode.Set.to_utf8_char(set)
    end

    test "Check complement of a complement round trips for category #{category}" do
      cat = unquote(category)
      set = "[:#{cat}:]"
      double_complement = "[^[:^#{cat}:]]"

      assert Unicode.Set.to_utf8_char(double_complement) == Unicode.Set.to_utf8_char(set)
    end

    test "Check union of a set and its complement for #{category} is always the unicode set" do
      cat = unquote(category)
      union = "[[:#{cat}:][:^#{cat}:]]"

      {:ok, union} = Unicode.Set.parse(union)
      union_ranges = Unicode.Set.Operation.expand(union)

      assert union_ranges.parsed == Unicode.all()
    end
  end
end