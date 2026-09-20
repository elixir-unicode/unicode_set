defmodule Unicode.Set.Sigil do
  @moduledoc """
  Provides the `~u` sigil, which parses a Unicode Set
  expression at compile time into a `t:Unicode.Set.t/0`.

  `import Unicode.Set.Sigil` to use it.

  """

  @doc """
  Parses a Unicode Set expression at compile time.

  ### Arguments

  * `string` is a Unicode Set expression. It must be a literal
    binary, since the set is parsed when the enclosing module
    is compiled.

  ### Returns

  * A `t:Unicode.Set.t/0`, or

  * raises `Unicode.Set.ParseError` at compile time if the
    expression is not a valid Unicode Set.

  ### Examples

      iex> import Unicode.Set.Sigil
      iex> ~u"[[:Lu:]&[:thai:]]"
      #Unicode.Set<[[:Lu:]&[:thai:]]>

  """
  defmacro sigil_u({:<<>>, _meta, [string]}, []) when is_binary(string) do
    string
    |> Unicode.Set.parse!()
    |> Macro.escape()
  end
end
