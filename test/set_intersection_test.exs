defmodule Unicode.Set.IntersectionTest do
  use ExUnit.Case

  for {category, _} <- Unicode.GeneralCategory.categories do
    test "Check intersection of positive and negative for category #{category} is always []" do
      cat = unquote(category)
      set = "[[:#{cat}:]&[:^#{cat}:]]"
      assert Unicode.Set.to_utf8_char(set) == []
    end

    test "Check difference of positive and negative for category #{category} is always the positive set" do
      cat = unquote(category)
      positive = "[:#{cat}:]"
      difference = "[[:#{cat}:]-[:^#{cat}:]]"
      assert Unicode.Set.to_utf8_char(difference) == Unicode.Set.to_utf8_char(positive)
    end

    # test "Check complement of complement round trips for category #{category}" do
    #   cat = unquote(category)
    #   positive = "[:#{cat}:]"
    #   double_complement = "[^[:^#{cat}:]]"
    #   assert Unicode.Set.to_utf8_char(double_complement) == Unicode.Set.to_utf8_char(positive)
    # end

    case category do
      category when category in [:Cn, :C] ->
        test "Check union of positive and negative for category #{category} is always the unicode set" do
          cat = unquote(category)
          union = "[[:#{cat}:][:^#{cat}:]]"

          {:ok, union} = Unicode.Set.parse_and_reduce(union)
          union_ranges = Unicode.Set.Operation.expand(union)

          assert union_ranges.parsed == [{0, 1114111}]
        end
      :Printable = category ->
        test "Check union of positive and negative for category #{category} is always the unicode set" do
          cat = unquote(category)
          union = "[[:#{cat}:][:^#{cat}:]]"

          {:ok, union} = Unicode.Set.parse_and_reduce(union)
          union_ranges = Unicode.Set.Operation.expand(union)

          assert union_ranges.parsed == [{0, 2159}, {2208, 12255}, {12272, 1114111}]
        end
      category ->
        test "Check union of positive and negative for category #{category} is always the unicode set" do
          cat = unquote(category)
          union = "[[:#{cat}:][:^#{cat}:]]"

          {:ok, union} = Unicode.Set.parse_and_reduce(union)
          union_ranges = Unicode.Set.Operation.expand(union)

          assert union_ranges.parsed == Unicode.ranges()
        end
    end
  end
end