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

  def expand({:union, [this, that]}) do
    union(expand(this), expand(that))
  end

  def expand({:difference, [this, that]}) do
    difference(expand(this), expand(that))
  end

  def expand({:intersection, [this, that]}) do
    intersect(expand(this), expand(that))
  end

  def expand({:in, ranges}) do
    ranges
  end

  def expand({:not_in, ranges}) do
    not_in(ranges)
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
  def union(this, that) do
    Enum.sort(this ++ that)
    |> compact_ranges
  end

  @doc """
  Returns the intersection of two lists of
  2-tuples representing codepoint ranges.

  The result is a single list of codepoint
  ranges that represents the common codepoints
  in the two lists.

  """
  def intersect(this, that) do
    IO.puts "INTERSECT: #{inspect this}, #{inspect that}"
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
    intersection = intersect(this, that)
    union(subtract(this, intersection), subtract(that, intersection))
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

  @doc """
  Returns a list of 2-tuples representing
  codepoint ranges that are the full
  set of Unicode ranges minus the ranges
  for a given property.

  """
  def not_in(ranges) do
    subtract(Unicode.ranges(), ranges)
  end

  @doc """
  Compact overlapping or adjancent ranges

  Assumes that the ranges are sorted and that each
  range tuple has the smaller codepoint before
  the larger codepoint

  """
  def compact_ranges([{a, b}, {c, d} | rest]) when b >= c and b <= d do
    compact_ranges([{a, d} | rest])
  end

  def compact_ranges([{a, b}, {_c, d} | rest]) when b >= d do
    compact_ranges([{a, b} | rest])
  end

  def compact_ranges([first | rest]) do
    [first | compact_ranges(rest)]
  end
end