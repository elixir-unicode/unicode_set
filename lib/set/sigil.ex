defmodule Unicode.Set.Sigil do
  @moduledoc false

  @doc """
  A convenience function to allow expressing
  unicode sets. For example:

     require Unicode.Set.Sigil
     ~u"[[:Lu:]&[:thai:]]"
     => ~u"[[:Lu:]&[:thai:]]"

  """
  defmacro sigil_u({:<<>>, _meta, [string]}, []) when is_binary(string) do
    string
    |> Unicode.Set.parse!()
    |> Macro.escape()
  end
end
