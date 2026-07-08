defmodule Unicode.Set.Transform do
  @moduledoc false

  alias Unicode.Set.Operation

  @doc """
  Converts an expanded AST into a format that
  can be used as a guard clause.

  """
  def guard_clause({first, first}, ranges, var) when is_integer(first) do
    quote do
      unquote(var) == unquote(first) or unquote(ranges)
    end
  end

  def guard_clause({first, last}, ranges, var) when is_integer(first) and is_integer(last) do
    quote do
      unquote(var) in unquote(first)..unquote(last) or unquote(ranges)
    end
  end

  def guard_clause({first, last}, _ranges, _var) when is_list(first) and is_list(last) do
    raise ArgumentError, "[{...}] string ranges are not supported for guards"
  end

  def guard_clause(:not_in, ranges, _var) do
    quote do
      not unquote(ranges)
    end
  end

  def guard_clause([], [], _var) do
    quote do
      false
    end
  end

  def guard_clause(range_1, range_2, _var) do
    quote do
      unquote(range_1) or unquote(range_2)
    end
  end

  @doc """
  Remove string ranges from the AST

  """
  def reject_string_range({first, last}, ranges, _var) when is_list(first) and is_list(last) do
    ranges
  end

  def reject_string_range({first, last}, ranges, _var) do
    [{first, last}, ranges]
  end

  def reject_string_range([], [], _var) do
    []
  end

  def reject_string_range(:not_in, ranges, _var) do
    {:not_in, ranges}
  end

  # def reject_string_range({first, last}, nil, _var) do
  #   {first, last}
  # end

  @doc """
  Converts an expanded AST into a format that
  can be fed to `:binary.compile_pattern/1`.

  """
  def pattern({first, first}, ranges, _var) when is_integer(first) do
    [List.to_string([first]) | ranges]
  end

  def pattern({first, last}, ranges, _var) when is_integer(first) and is_integer(last) do
    Enum.map(first..last, fn c -> List.to_string([c]) end) ++ ranges
  end

  def pattern({first, first}, ranges, _var) when is_list(first) do
    [List.to_string(first) | ranges]
  end

  def pattern({first, last}, ranges, _var) when is_list(first) and is_list(last) do
    Operation.expand_string_range({first, last})
    |> Enum.map(&List.to_string(elem(&1, 0)))
    |> Kernel.++(ranges)
  end

  def pattern(:not_in, _ranges, _var) do
    raise ArgumentError,
          "complement (inverse) unicode sets like [^...] " <>
            "are not supported for compiled patterns"
  end

  def pattern(range_1, range_2, _var) do
    range_1 ++ range_2
  end

  @doc """
  Converts an expanded AST into a format that
  can be fed to `NimbleParsec.utf8_char`.

  """
  def utf8_char({first, first}, ranges, _var) when is_integer(first) do
    [first | ranges]
  end

  def utf8_char({first, last}, ranges, _var) when is_integer(first) and is_integer(last) do
    [first..last | ranges]
  end

  def utf8_char({first, last}, _ranges, _var) when is_list(first) and is_list(last) do
    raise ArgumentError, "[{...}] string ranges are not supported for utf8 ranges"
  end

  def utf8_char(:not_in, ranges, _var) do
    Enum.map(ranges, &{:not, &1})
  end

  def utf8_char(range_1, range_2, _var) do
    range_1 ++ range_2
  end

  # Regex doesn't all codepoints in this range so we just
  # omit them for now
  # D800..DB7F;SG     # Cs   [896] <surrogate-D800>..<surrogate-DB7F>
  # DB80..DBFF;SG     # Cs   [128] <surrogate-DB80>..<surrogate-DBFF>
  # DC00..DFFF;SG     # Cs  [1024] <surrogate-DC00>..<surrogate-DFFF>

  @spec to_binary(integer) :: String.t()
  defp to_binary(integer) when is_integer(integer) and integer in 0xD800..0xDFFF do
    ""
  end

  defp to_binary(integer) when is_integer(integer) do
    "\\x{" <> Integer.to_string(integer, 16) <> "}"
  end

  @spec to_binary(integer, integer) :: String.t()
  @spec to_binary(charlist, charlist) :: String.t()

  defp to_binary(first, first) when is_integer(first) do
    to_binary(first)
  end

  defp to_binary(first, last) when is_integer(first) and is_integer(last) do
    # The surrogate block D800..DFFF cannot appear in UTF-8 / PCRE, so split any
    # range that overlaps it and drop the surrogate portion. Emitting the raw
    # endpoints would corrupt the class (a dropped endpoint leaves a dangling
    # "-", e.g. `[-\x{E7FF}]`) or fail to compile.
    first
    |> surrogate_free_segments(last)
    |> Enum.map_join("", fn
      {low, low} ->
        "\\x{" <> Integer.to_string(low, 16) <> "}"

      {low, high} ->
        "\\x{" <> Integer.to_string(low, 16) <> "}-\\x{" <> Integer.to_string(high, 16) <> "}"
    end)
  end

  # A range whose endpoints are both non-surrogates is emitted unchanged even if
  # it spans the surrogate block: PCRE accepts `\x{64}-\x{10FFFF}` and no valid
  # character is a surrogate. Only a *surrogate endpoint* must be clipped, since
  # emitting it would drop to "" and leave a dangling hyphen.
  defp surrogate_free_segments(first, last) do
    cond do
      not surrogate?(first) and not surrogate?(last) -> [{first, last}]
      surrogate?(first) and surrogate?(last) -> []
      surrogate?(first) -> [{0xE000, last}]
      surrogate?(last) -> [{first, 0xD7FF}]
    end
  end

  defp surrogate?(codepoint), do: codepoint in 0xD800..0xDFFF

  @doc """
  Converts a expanded AST into a simple
  regex.

  PCRE engines, including `:re` do not
  support compound classes like `{ab}`
  or compound ranges like `{ab}-{cd}`
  so these need to be converted to
  alternatives within a group in order
  to be a valid regex.

  """

  def regex({first, first}, ranges, _var) when is_integer(first) do
    [to_binary(first) | ranges]
  end

  def regex({first, last}, [], _var) when is_integer(first) and is_integer(last) do
    [to_binary(first, last)]
  end

  def regex({first, last}, ranges, _var) when is_integer(first) and is_integer(last) do
    [to_binary(first, last) | ranges]
  end

  # Its a compound range
  def regex({first, last}, [], _var) when is_list(first) and is_list(last) do
    [{first, last}]
  end

  def regex({first, last}, ranges, _var) when is_list(first) and is_list(last) do
    [{first, last} | ranges]
  end

  def regex(:not_in, ranges, _var) do
    ["^" | ranges]
  end

  def regex([], [], _var) do
    []
  end

  def regex(range_1, range_2, _var) do
    [range_1, range_2]
  end
end
