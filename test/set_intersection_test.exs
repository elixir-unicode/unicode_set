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

    # test "Check union of positive and negative for category #{category} is always the unicode set" do
    #   cat = unquote(category)
    #   positive = "[:#{cat}:]"
    #   union = "[[:#{cat}:][:^#{cat}:]]"
    #   assert Unicode.Set.to_utf8_char(union) == Unicode.ranges()
    # end
  end
end