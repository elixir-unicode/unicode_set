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

  def guard_clause(:string, _range, _var) do
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

  @doc """
  Converts an expanded AST into a format that
  can be fed to `:binary.compile_pattern/1`.

  """
  def pattern({first, first}, range, _var) when is_integer(first) do
    [List.to_string([first]) | range]
  end

  def pattern({first, last}, range, _var) when is_integer(first) and is_integer(last) do
    Enum.map(first..last, fn c -> List.to_string([c]) end) ++ range
  end

  def pattern(:string, {first, last}, _var) when is_list(first) and is_list(last) do
    first
    |> Operation.expand_string_range(last)
    |> Enum.map(&List.to_string/1)
  end

  def pattern(:not_in, _ranges, _var) do
    raise ArgumentError, "[^...] unicode sets are not supported for compiled patterns"
  end

  def pattern(range1, range2, _var) do
    range1 ++ range2
  end

  @doc """
  Converts an expanded AST into a format that
  can be fed to `NimbleParsec.utf8_char`.

  """
  def utf8_char({first, first}, range, _var) when is_integer(first) do
    [first | range]
  end

  def utf8_char({first, last}, range, _var) when is_integer(first) and is_integer(last) do
   [first..last, range]
  end

  def utf8_char(:string, _range, _var) do
    raise ArgumentError, "[{...}] string ranges are not supported for utf8 ranges"
  end

  def utf8_char(:not_in, range, _var) do
    Enum.map(range, &{:not, &1})
  end

  def utf8_char(range_1, range_2, _var) do
    range_1 ++ range_2
  end
end
