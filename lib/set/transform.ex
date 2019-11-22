defmodule Unicode.Set.Transform do
  @moduledoc false

  @doc false
  def ranges_to_guard_clause([{first, first}], var) when is_integer(first) do
    quote do
      unquote(var) == unquote(first)
    end
  end

  def ranges_to_guard_clause([{first, last}], var) when is_integer(first) do
    quote do
      unquote(var) in unquote(first)..unquote(last)
    end
  end

  def ranges_to_guard_clause([{first, first} | rest], var) when is_integer(first) do
    quote do
      unquote(var) == unquote(first) or unquote(ranges_to_guard_clause(rest, var))
    end
  end

  def ranges_to_guard_clause([{first, last} | rest], var) when is_integer(first) do
    quote do
      unquote(var) in unquote(first)..unquote(last) or unquote(ranges_to_guard_clause(rest, var))
    end
  end

  def ranges_to_guard_clause({:not_in, ranges}, var) do
    quote do
      not unquote(ranges_to_guard_clause(ranges, var))
    end
  end

  def ranges_to_guard_clause({:in, ranges}, var) do
    quote do
      unquote(ranges_to_guard_clause(ranges, var))
    end
  end

  def ranges_to_guard_clause([range], var) do
    ranges_to_guard_clause(range, var)
  end

  def ranges_to_guard_clause([range | rest], var) do
    quote do
      unquote(ranges_to_guard_clause(range, var)) or unquote(ranges_to_guard_clause(rest, var))
    end
  end
end
