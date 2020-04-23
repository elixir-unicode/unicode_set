defmodule Unicode.Set.Operation do
  @moduledoc """
  Functions to operate on Unicode sets:

  * Intersection
  * Difference
  * Union
  * Inversion

  """

  @doc """
  Expands all sets, properties and ranges to a list
  of 2-tuples expressing a range of codepoints

  It can return one of two forms

  `[{:in, [tuple_list]}]` for an inclusion list

  `[{:not_in, [tuple_list]}]` for an exclusion list

  """
  def expand([ast]) do
    if has_difference_or_intersection?(ast) do
      {:in, expand(ast)}
    else
      combine(ast)
    end
    |> compact_ranges
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
    expand_string_ranges(ranges)
  end

  def expand({:not_in, ranges}) do
    ranges
    |> expand_string_ranges
    |> invert
  end

  @doc """
  Expand string ranges like `{ab}-{cd}`

  """
  def expand_string_ranges([range]) do
    expand_string_range(range)
  end

  def expand_string_ranges(ranges) when is_list(ranges) do
    Enum.map(ranges, &expand_string_range/1)
  end

  def expand_string_range({from, to}) when is_integer(from) and is_integer(to) do
    {from, to}
  end

  def expand_string_range({from, to}) when is_list(from) and is_list(to) do
    prefix_length = length(from) - length(to)
    {prefix, from} = Enum.split(from, prefix_length)

    from
    |> Enum.zip(to)
    |> expand_string_range
    |> Enum.map(&(prefix ++ &1))
    |> Enum.map(&{&1, &1})
  end

  # def expand_string_range([{a, a}]) do
  #   a
  # end
  #
  # def expand_string_range([{a, b}]) do
  #   a..b
  # end

  def expand_string_range([{a, b}, {c, d}]) do
    for x <- a..b, y <- c..d, do: [x, y]
  end

  def expand_string_range([{a, b} | rest]) do
    for x <- a..b, y <- expand_string_range(rest), do: [x | y]
  end

  @doc """
  Combines all the ranges into a single list

  This function is called iff the Unicode
  Sets are formed by unions only. If
  the set operations of intersection or
  difference are present then the ranges
  will need to be expanded via `expand/1`.

  """
  def combine([ast]) do
    combine(ast)
  end

  def combine({:union, [this, that]}) do
    [combine(this), combine(that)]
    |> List.flatten()
  end

  def combine(other) do
    other
  end

  @doc """
  Compact overlapping and adjacent ranges
  """
  def compact_ranges({:in, ranges}) do
    {:in, Unicode.Utils.compact_ranges(ranges)}
  end

  def compact_ranges({:not_in, ranges}) do
    {:not_in, Unicode.Utils.compact_ranges(ranges)}
  end

  def compact_ranges(ranges) when is_list(ranges) do
   Unicode.Utils.compact_ranges(ranges)
  end

  def compact_ranges({_charlist_1, _charlist_2} = range) do
    range
  end

  @doc """
  Returns a boolean indicating whether the given
  AST includes set operations intersection or
  difference.

  When these operations exist then all ranges - including
  `^` ranges needs to be expanded.  If there are no
  intersections or differences then the `^` ranges can
  be directly translated to guard clauses or a list of
  elixir ranges.

  """
  def has_difference_or_intersection?([ast]) do
    has_difference_or_intersection?(ast)
  end

  def has_difference_or_intersection?({operation, [_this, _that]})
      when operation in [:intersection, :difference] do
    true
  end

  def has_difference_or_intersection?({_operation, [this, that]}) do
    has_difference_or_intersection?(this) || has_difference_or_intersection?(that)
  end

  def has_difference_or_intersection?(_other) do
    false
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

  def intersect([{as, ae} | a_rest], [{bs, be} | b_rest]) do
    intersection = {max(as, bs), min(ae, be)}
    [intersection | intersect([intersection | a_rest], b_rest)]
  end

  # To process character strings
  # like {abc}
  def intersect([head | []], [head | _other]) do
    head
  end

  def intersect([head | _rest], head) do
    head
  end

  def intersect([head | rest], [head | other]) do
    [head, intersect(rest, other)]
  end

  def intersect([_head | rest], other) do
    intersect(rest, other)
  end

  # And of course if either list is empty there is no
  # intersection

  def intersect(_rest, []) do
    []
  end

  def intersect([], _rest) do
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

  # 1. list-B head is the same as list-A head
  def difference([a_head | a_rest], [a_head | b_rest]) do
    difference(a_rest, b_rest)
  end

  def difference([a_head | a_rest], a_head) do
    a_rest
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
    [{as, bs - 1} | difference([{be + 1, ae} | a_rest], b_rest)]
  end

  # 5. list-B head is at the start of list-A head and is shorter than list-A head
  def difference([{_as, ae} | a_rest], [{_bs, be} | b_rest]) when be < ae do
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

  def difference(a_list, b_tuple) when is_tuple(b_tuple) do
    difference(a_list, [b_tuple])
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
    difference(union(this, that), intersect(this, that))
  end

  @doc """
  Returns a list of 2-tuples representing
  codepoint ranges that are the full
  set of Unicode ranges minus the ranges
  for a given property.

  """
  def invert(ranges) do
    difference(Unicode.ranges(), ranges)
  end

  @doc """
  Prewalks the expanded AST from a parsed
  Unicode Set invoking a function on each
  codepoint range in the set.

  """
  def traverse(ranges, fun) when is_function(fun) do
    traverse(ranges, nil, fun)
  end

  def traverse({:not_in, ranges}, var, fun) do
    fun.(:not_in, traverse(ranges, var, fun), var)
  end

  def traverse({:in, ranges}, var, fun) do
    traverse(ranges, var, fun)
  end

  def traverse({from, to} = range, var, fun) when is_list(from) and is_list(to) do
    fun.(range, [], var)
  end

  def traverse([{first, last} = range | rest], var, fun)
      when is_integer(first) and is_integer(last) do
    fun.(range, traverse(rest, var, fun), var)
  end

  def traverse([range], var, fun) do
    traverse(range, var, fun)
  end

  def traverse([range | rest], var, fun) do
    fun.(traverse(range, var, fun), traverse(rest, var, fun), var)
  end

  def traverse([] = range, var, fun) do
    fun.(range, range, var)
  end
end
