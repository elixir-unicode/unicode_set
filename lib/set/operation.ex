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

  # If two heads are the same then keep one and
  # advance the other list
  def union([a_head | a_rest], [a_head | b_rest]) do
    union([a_head | a_rest], b_rest)
  end

  # We've advanced the first list beyond the start of the
  # second list so copy the head of the second list over
  # and advance the second list
  def union([a_head | a_rest], [b_head | _b_rest] = b) when a_head < b_head do
    [a_head | union(a_rest, b)]
  end


  def union([a_head | _a_rest] = a, [b_head | b_rest]) when a_head > b_head do
    [b_head | union(a, b_rest)]
  end

  def union([], other) do
    other
  end

  def union(list, []) do
    list
  end

  @doc """
  Returns the intersection of two lists of
  2-tuples representing codepoint ranges.

  The result is a single list of codepoint
  ranges that represents the common codepoints
  in the two lists.

  """
  def intersect(a, b, acc \\ [])

  # After we intersect its possible that the list has lost its
  # order to check for that and do a bubble sort
  def intersect([head, second | rest], other, acc) when head > second do
    intersect([second, head | rest], other, acc)
  end

  # The head of the first list is after the end of the second
  # list so we need to advance the second list
  def intersect([{as, _ae} | _a_rest] = a, [{_bs, be} | b_rest], acc) when as > be do
    intersect(a, b_rest, acc)
  end

  # THe head of the second list starts after the end of the first
  # list so we advance the first list
  def intersect([{_as, ae} | a_rest], [{bs, _be} | _b_rest] = b, acc) when bs > ae do
    intersect(a_rest, b, acc)
  end

  # An intersection which consumes the head of the second
  # parameter so we advance
  def intersect([{as, ae} | a_rest], [{bs, be} | b_rest], acc)  do
    intersection = {max(as, bs), min(ae, be)}
    intersect([intersection | a_rest], b_rest, [intersection | acc])
  end

  def intersect(_, [], acc)  do
    :lists.reverse(acc)
  end

  def intersect([], _, acc)  do
    :lists.reverse(acc)
  end

  @doc """
  Removes from one list of 2-tuples
  representing Unicode codepoints from
  another.

  Returns the first list of codepoint
  ranges minus the codepoints in the second
  list.

  """
  def difference(this, that) do

  end

  @doc """
  Returns the difference of two lists of
  2-tuples representing codepoint ranges.

  The result is a single list of codepoint
  ranges that represents the codepoints
  that are in either of the two lists but
  not both.

  """
  def symmetric_difference(this, that) do
    intersection = intersect(this, that)
    union(difference(this, intersection), difference(that, intersection))
  end

  @doc """
  Returns a list of 2-tuples representing
  codepoint ranges that are the full
  set of Unicode ranges minus the ranges
  for a given property.

  """
  def not_in(ranges) do
    difference(Unicode.ranges(), ranges)
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

  def compact_ranges([first]) do
    first
  end

  def compact_ranges([first | rest]) do
    [first | compact_ranges(rest)]
  end
end