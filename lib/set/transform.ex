defmodule Unicode.Set.Transform do
  @moduledoc false

  @doc """
  Converts an expanded AST into a format that
  can be used as a guard clause.

  """
  def guard_clause({first, first}, ranges, var) do
    quote do
      unquote(var) == unquote(first) or unquote(ranges)
    end
  end

  def guard_clause({first, last}, ranges, var) do
    quote do
      unquote(var) in unquote(first)..unquote(last) or unquote(ranges)
    end
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
  def pattern({first, first}, range, _var) do
    [List.to_string([first]) | range]
  end

  def pattern({first, last}, range, _var) do
    Enum.map(first..last, fn c -> List.to_string([c]) end) ++ range
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
  def utf8_char({first, first}, range, _var) do
    [first | range]
  end

  def utf8_char({first, last}, range, _var) do
   [first..last, range]
  end

  def utf8_char(:not_in, range, _var) do
    Enum.map(range, &{:not, &1})
  end

  def utf8_char(range_1, range_2, _var) do
    range_1 ++ range_2
  end
end
