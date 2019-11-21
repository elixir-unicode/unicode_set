defmodule Unicode.Set.Operation do
  @moduledoc """
  Functions to operate on Unicode sets:

  * Intersection
  * Difference
  * Union

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

  # When the heads of the two lists are adjacent then
  # we insert one new range that is the consolidation
  # of them both

  def union([{as, ae} | a_rest], [{bs, be} | _b_rest] = b) when ae + 1 == bs do
    [{as, be} | union(a_rest, b)]
  end

  # We've advanced the second list beyond the start of the
  # first list so copy the head of the first list over
  # and advance the second list

  def union([a_head | a_rest], [b_head | _b_rest] = b) when a_head < b_head do
    [a_head | union(a_rest, b)]
  end

  # We've advanced the first list beyond the start of the
  # second list so copy the head of the second list over
  # and advance the second list

  def union([a_head | _a_rest] = a, [b_head | b_rest]) when a_head > b_head do
    [b_head | union(a, b_rest)]
  end

  # And of course if either list is empty there is now
  # just one of the lists

  def union([], b_list) do
    b_list
  end

  def union(a_list, []) do
    a_list
  end

  @doc """
  Returns the intersection of two lists of
  2-tuples representing codepoint ranges.

  The result is a single list of codepoint
  ranges that represents the common codepoints
  in the two lists.

  """

  # The head of the first list is after the end of the second
  # list so we need to advance the second list.
  #
  # This clause deals with the following relationship between the two
  # list heads:
  #
  # List 1:                      <----------------->
  # List 2:  <---------------->

  def intersect([{as, _ae} | _a_rest] = a, [{_bs, be} | b_rest]) when as > be do
    intersect(a, b_rest)
  end

  # The head of the second list starts after the end of the first
  # list so we advance the first list.
  #
  # This clause deals with the following relationship between the two
  # list heads:
  #
  # List 1:  <----------------->
  # List 2:                       <---------------->

  def intersect([{_as, ae} | a_rest], [{bs, _be} | _b_rest] = b) when bs > ae do
    intersect(a_rest, b)
  end

  # An intersection which consumes the head of the second
  # list so we advance that list.
  #
  # This clause deals with the following relationship between the two
  # list heads:
  #
  # List 1:  <----------------->
  # List 2:               <---------------->

  def intersect([{as, ae} | a_rest], [{bs, be} | b_rest])  do
    intersection = {max(as, bs), min(ae, be)}
    [intersection | intersect([intersection | a_rest], b_rest)]
  end

  # And of course if either list is empty there is no
  # intersection

  def intersect(_rest, [])  do
    []
  end

  def intersect([], _rest)  do
    []
  end


  @doc """
  Removes one list of 2-tuples
  representing Unicode codepoints from
  another.

  Returns the first list of codepoint
  ranges minus the codepoints in the second
  list.

  """

  # There are several cases that need to be considered:
  #
  # 1. list-B head is the same as list-A head
  # 2. list-B head is completely after list-A head
  # 3. list-B head is completely before list-A head
  # 4. list-B head is contained wholly within list-A head
  # 5. list-B head is at the start of list-A head and is shorter than list-A head
  # 6. list-B head is at the end of list-A head and is shorter than list-A head
  # 7. list-B head encloses list-A head
  # 8. list-A is empty
  # 9. list-B is empty

  # 1. list-B head is the same as list-A head
  def difference([a_head | a_rest], [a_head | b_rest]) do
    difference(a_rest, b_rest)
  end

  # 2. list-B head is completely after list-A head
  def difference([{as, ae} | a_rest], [{bs, _be} | _b_rest] = b) when bs > ae do
    [{as, ae} | difference(a_rest, b)]
  end

  # 3. list-B head is completely before list-A head
  def difference([{as, _ae} | _a_rest] = a, [{_bs, be} | b_rest]) when be < as do
    difference(a, b_rest)
  end

  # 4. list-B head is contained wholly within list-A head
  def difference([{as, ae} | a_rest], [{bs, be} | b_rest]) when bs > as and be < ae do
    [{as, bs - 1}, {be + 1, ae} | difference(a_rest, b_rest)]
  end

  # 5. list-B head is at the start of list-A head and is shorter than list-A head
  def difference([{as, ae} | a_rest], [{as, be} | b_rest]) when be < ae do
    [{be + 1, ae} | difference(a_rest, b_rest)]
  end

  # 6. list-B head is at the end of list-A head and is shorter than list-A head
  def difference([{as, ae} | a_rest], [{bs, ae} | b_rest]) when bs > as do
    [{as, bs - 1} | difference(a_rest, b_rest)]
  end

  # 7. list-B head encloses list-A head
  def difference([{_as, ae} | a_rest], [{_bs, be} | b_rest]) when be > ae do
    difference(a_rest, [{ae + 1, be} | b_rest])
  end

  # 8. list-A is empty
  def difference([], _b_list) do
    []
  end

  # 9. list-B is empty
  def difference(a_list, []) do
    a_list
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
  def compact_ranges([{as, ae}, {bs, be} | rest]) when ae >= bs and as <= be do
    compact_ranges([{as, be} | rest])
  end

  def compact_ranges([{as, ae}, {_bs, be} | rest]) when ae >= be do
    compact_ranges([{as, ae} | rest])
  end

  def compact_ranges([first]) do
    first
  end

  def compact_ranges([first | rest]) do
    [first | compact_ranges(rest)]
  end
end