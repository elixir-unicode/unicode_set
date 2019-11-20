defmodule Unicode.Set.Operation do
  @moduledoc """
  A set of functions to expand Unicode sets:

  * Intersection
  * Difference
  * Ranges

  """

  @doc """
  Expands all sets, properties and ranges to a list
  of 2-tuples expressing a range of codepoints

  """

  def expand([operation]) do
    expand(operation)
  end

  def expand({:merge, [this, that]}) do
    merge(expand(this), expand(that))
  end

  def expand({:not, [this]}) do
    subtract(Unicode.ranges(), expand(this))
  end

  def expand({:range, [from, to]}) do
    range(from, to)
  end

  def expand({:difference, [this, that]}) do
    difference(expand(this), expand(that))
  end

  def expand({:intersection, [this, that]}) do
    intersection(expand(this), expand(that))
  end

  def expand({:equal, [property, name]}) do
    equal(property, name)
  end

  def expand({:not_equal, [property, name]}) do
    not_equal(property, name)
  end

  def range(from, to) do
    [{from, to}]
  end

  @doc """
  Merges two lists of 2-tuples representing
  ranges of codepoints.  The result is a
  single list of 2-tuple codepoint ranges
  that includes all codepoint from the
  two lists.

  It is assumed that both lists are sorted
  prior to merging.

  """
  def merge(this, that) do

  end

  @doc """
  Returns the intersection of two lists of
  2-tuples representing codepoint ranges.

  The result is a single list of codepoint
  ranges that represents the common codepoints
  in the two lists.

  """
  def intersection(this, that) do
    IO.puts "INTERSECTION: #{inspect this}, #{inspect that}"
  end

  @doc """
  Returns the difference of two lists of
  2-tuples representing codepoint ranges.

  The result is a single list of codepoint
  ranges that represents the codepoints
  that are in either of the two lists but
  not both.

  """
  def difference(this, that) do
    intersection = intersection(this, that)
    merge(subtract(this, intersection), subtract(that, intersection))
  end

  @doc """
  Returns a list of 2-tuples representing
  codepoint ranges for a given Unicode
  property

  """
  def equal(:block, name) do
    Unicode.Block.blocks |> Map.fetch!(name)
  end

  def equal(:script, name) do
    Unicode.Script.scripts |> Map.fetch!(name)
  end

  def equal(:category, name) do
    Unicode.Category.categories |> Map.fetch!(name)
  end

  def equal(:ccc, name) do
    Unicode.CombiningClass.combining_classes |> Map.fetch!(name)
  end

  @doc """
  Returns a list of 2-tuples representing
  codepoint ranges that are the full
  set of Unicode ranges minus the ranges
  for a given property.

  """
  def not_equal(property, name) do
    Unicode.ranges
    |> subtract(equal(property, name))
  end

  @doc """
  Subtracts one list of 2-tuples
  representing Unicode codepoints from
  another.

  Returns the first list of codepoint
  ranges minus the codepoints in the second
  list.

  """
  def subtract(this, that) do

  end
end