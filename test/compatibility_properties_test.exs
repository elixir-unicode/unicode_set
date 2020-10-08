defmodule Unicode.Set.CompatibilityTest do
  use ExUnit.Case

  @compatibility_properties [
    :alpha, :lower, :upper, :punct,
    :digit, :xdigit, :alnum, :space, :blank,
    :cntrl, :graph, :print, :word
  ]

  test "Compiling compatibility classes" do
    for property <- @compatibility_properties do
      assert match?({:ok, _any}, Unicode.Set.Property.property(:script_or_category, property))
    end
  end

end


