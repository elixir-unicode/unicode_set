defmodule Unicode.Set.IntersectionTest do
  use ExUnit.Case

  for {category, _} <- Unicode.GeneralCategory.categories do
    test "Check intersection of positive and negative for category #{category}" do
      cat = unquote(category)
      set = "[[:#{cat}:]&[:^#{cat}:]]"
      assert Unicode.Set.to_utf8_char(set) == []
    end
  end
end