defmodule Unicode.Set.Sigil do
  @moduledoc false

  @doc """
  A convenience function to allow expressing
  unicode sets. For example

  iex> require Unicode.Set.Sigil
  iex> ~z[[:Lu]&[:thai:]]

  """
  defmacro sigil_z(unicode_set, []) do
    "[" <> unicode_set <> "]"
  end

end