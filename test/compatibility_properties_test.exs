defmodule Unicode.Set.CompatibilityTest do
  use ExUnit.Case

  @compatibility_properties [
    :alpha, :lower, :upper, :punct,
    :digit, :xdigit, :alnum, :space, :blank,
    :cntrl, :graph, :print, :word
  ]
  |> Enum.map(&Atom.to_string/1)

  for property <- @compatibility_properties do
    test "Compiling compatibility class #{property}" do
      assert match?({:ok, _any}, Unicode.Set.Property.fetch_property(:script_or_category, unquote(property)))
    end
  end

end


