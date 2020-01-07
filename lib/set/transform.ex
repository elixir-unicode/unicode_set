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
end
