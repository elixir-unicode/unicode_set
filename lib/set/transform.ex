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
    raise ArgumentError, "[^...] unicode sets are not supported for compiled patterns"
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
    [first..last, ranges]
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

  @doc """
  Converts a expanded AST into a simple
  character class.

  This conversion supports converting
  Unicode sets into character classes
  for pre-processing regex expressions.

  """
  def character_class({first, first}, ranges, _var) when is_integer(first) do
    [to_binary(first)] ++ ranges
  end

  def character_class({first, last}, ranges, _var) when is_integer(first) and is_integer(last) do
    [to_binary(first, last)] ++  ranges
  end

  def character_class({first, last}, ranges, _var) when is_list(first) and is_list(last) do
    [to_binary(first, last)] ++ ranges
  end

  def character_class(:not_in, ranges, _var) do
    ["^", ranges]
  end

  def character_class(range_1, range_2, _var) do
    range_1 ++ range_2
  end

  defp to_binary(integer) when is_integer(integer) and integer >= 0xd800 do
    raise ArgumentError, "Invalid unicode codepoint found: #{inspect integer}"
  end

  defp to_binary(integer) when is_integer(integer) and integer > 127 or integer < 32 do
    "\\x{" <> Integer.to_string(integer, 16) <> "}"
  end

  defp to_binary(integer) when is_integer(integer) do
    <<integer::utf8>>
  end

  defp to_binary(first, last) when is_integer(first) and is_integer(last) do
    to_binary(first) <> "-" <> to_binary(last)
  end

  defp to_binary(first, first) when is_list(first) do
    "{" <> List.to_string(first) <> "}"
  end

  defp to_binary(first, last) when is_list(first) and is_list(last) do
    "{" <> List.to_string(first) <> "}" <> "-" <> "{" <> List.to_string(last) <> "}"
  end

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
