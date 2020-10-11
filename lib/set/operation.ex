defmodule Unicode.Set.Operation do
  @moduledoc """
  Functions to operate on Unicode sets:

  * Intersection
  * Difference
  * Union
  * Inversion

  """

  # Debug tracer.
  #
  # In production no code will be emitted (the erlang
  # code generator will optimize out the assignment to `_`)
  #
  # In development, add any of :intersection, :union and :difference
  # into this list:
  @debug_functions []

  defmacrop debug(step, a, b) do
    {caller, _} = __CALLER__.function

    if caller in @debug_functions && Mix.env() == :dev do
      quote do
        IO.inspect("#{unquote(caller)}", label: "Step #{unquote(step)}")
        IO.inspect(unquote(a), label: "a")
        IO.inspect(unquote(b), label: "b")
      end
    end

    quote do
      _ = {unquote(step), unquote(a), unquote(b), unquote(caller)}
    end
  end

  @doc """
  Reduces all sets, properties and ranges to a list
  of 2-tuples expressing a range of codepoints.

  It can return one of two forms

  `[{:in, [tuple_list]}]` for an inclusion list

  `[{:not_in, [tuple_list]}]` for an exclusion list

  or a combination of both.

  Attempts are made to preserve `:not_in` clauses
  as long as possible since many uses, like regexes
  and `nimble_parsec` can consume `:not_in` style
  ranges.

  When only single character classes are presented,
  or several classes which are `unions`, `:not_in`
  can be preserved.

  When intersections and differences are required,
  the rnages must be both reduced and expanded in
  order for this set operations to complete.

  """
  def reduce(%Unicode.Set{state: :reduced} = unicode_set) do
    unicode_set
  end

  def reduce(%Unicode.Set{state: :expanded} = unicode_set) do
    unicode_set
  end

  def reduce(%Unicode.Set{parsed: [ast]} = unicode_set) do
    reduced =
      if has_difference_or_intersection?(ast) do
        {:in, expand(ast)}
      else
        combine(ast)
      end
      |> compact_ranges

    %{unicode_set | parsed: reduced, state: :reduced}
  end

  @doc """
  Expand takes a reduced AST and expands
  it into a single list of codepoint tuples.

  """
  def expand(%Unicode.Set{state: :expanded} = unicode_set) do
    unicode_set
  end

  def expand(%Unicode.Set{parsed: ast} = unicode_set) do
    %{unicode_set | parsed: expand(ast), state: :expanded}
  end

  def expand({:union, [this, that]}) do
    expand(this)
    |> union(expand(that))
  end

  def expand({:difference, [this, that]}) do
    difference(expand(this), expand(that))
  end

  # De Morgan's law implementation
  # def expand({:intersection, [{:not_in, this}, {:not_in, that}]}) do
  #   ranges = expand({:union, [{:in, this}, {:in, that}]})
  #   expand({:not_in, ranges})
  # end

  def expand({:intersection, [this, that]}) do
    intersect(expand(this), expand(that))
  end

  def expand({:in, ranges}) do
    ranges
    |> compact_ranges
    |> expand_string_ranges
  end

  def expand({:not_in, ranges}) do
    ranges
    |> compact_ranges
    |> expand_string_ranges
    |> complement
  end

  # The last two clauses are used
  # When we take a reduced AST and
  # need to exapnd it to a full list
  # of codepoints
  def expand([ranges]) do
    expand(ranges)
    |> Enum.sort()
    |> compact_ranges
  end

  def expand([a_list, b_list]) do
    expand({:union, [a_list, b_list]})
    |> Enum.sort()
    |> compact_ranges
  end

  @doc """
  Expand string ranges like `{ab}-{cd}`

  """
  def expand_string_ranges(ranges) when is_list(ranges) do
    Enum.map(ranges, &expand_string_range/1)
    |> List.flatten()
  end

  def expand_string_range({:in, ranges}) when is_list(ranges) do
    {:in, expand_string_ranges(ranges)}
  end

  def expand_string_range({:not_in, ranges}) when is_list(ranges) do
    {:not_in, expand_string_ranges(ranges)}
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

  def compact_ranges([{from, to} | _rest] = ranges) when is_integer(from) and is_integer(to) do
    Unicode.Utils.compact_ranges(ranges)
  end

  def compact_ranges(ranges) when is_list(ranges) do
    ranges
    |> Enum.group_by(fn {k, _v} -> k end, fn {_k, v} -> v end)
    |> Enum.map(fn {k, v} ->
      {k, v |> List.flatten() |> Enum.sort() |> Unicode.Utils.compact_ranges()}
    end)
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
  def union(a_list, b_list) when is_list(a_list) and is_list(b_list) do
    (a_list ++ b_list)
    |> Enum.sort()
    |> Enum.uniq()
  end

  # If two heads are the same then keep one and
  # advance the other list

  # def union([a_head | a_rest], [a_head | b_rest]) do
  #   union([a_head | a_rest], b_rest)
  # end
  #
  # # When the heads of the two lists are adjacent then
  # # we insert one new range that is the consolidation
  # # of them both
  #
  # def union([{as, ae} | a_rest], [{bs, be} | _b_rest] = b) when ae + 1 == bs do
  #   [{as, be} | union(a_rest, b)]
  # end
  #
  # # We've advanced the second list beyond the start of the
  # # first list so copy the head of the first list over
  # # and advance the second list
  #
  # def union([a_head | a_rest], [b_head | _b_rest] = b) when a_head < b_head do
  #   [a_head | union(a_rest, b)]
  # end
  #
  # # We've advanced the first list beyond the start of the
  # # second list so copy the head of the second list over
  # # and advance the second list
  #
  # def union([a_head | _a_rest] = a, [b_head | b_rest]) when a_head > b_head do
  #   [b_head | union(a, b_rest)]
  # end
  #
  # # And of course if either list is empty there is now
  # # just one of the lists
  #
  # def union([], b_list) do
  #   b_list
  # end
  #
  # def union(a_list, []) do
  #   a_list
  # end

  @doc """
  Returns the intersection of two lists of
  2-tuples representing codepoint ranges.

  The result is a single list of codepoint
  ranges that represents the common codepoints
  in the two lists.

  """

  # The head of the first list is the same as the head of the second
  # list so we need to advance both lists.
  #
  # This clause deals with the following relationship between the two
  # list heads:
  #
  # List 1:  <----------------->
  # List 2:  <----------------->

  def intersect([a_head | a_rest] = a, [a_head | b_rest] = b) do
    debug(1, a, b)
    [a_head | intersect(a_rest, b_rest)]
  end

  # The head of the first list starts at the same place
  # as the second list but the first list is longer.
  #
  # This clause deals with the following relationship between the two
  # list heads:
  #
  # List 1:  <----------------->
  # List 2:  <------------>

  def intersect([{as, ae} | a_rest] = a, [{as, be} | b_rest] = b) when ae > be do
    debug(2, a, b)
    [{as, be} | intersect([{be + 1, ae} | a_rest], b_rest)]
  end

  # The head of the first list starts at the same place
  # as the second list but the second list is longer.
  #
  # This clause deals with the following relationship between the two
  # list heads:
  #
  # List 1:  <------------->
  # List 2:  <----------------->

  def intersect([{as, ae} | a_rest] = a, [{as, be} | b_rest] = b) when ae < be do
    debug(3, a, b)
    [{as, ae} | intersect(a_rest, [{ae + 1, be} | b_rest])]
  end

  # a_head starts after the end of b_list
  # so there is no intersection but we still need to
  # check against a_list.
  #
  # This clause deals with the following relationship between the two
  # list heads:
  #
  # List 1:                      <----------------->
  # List 2:  <---------------->

  def intersect([{as, _ae} | _a_rest] = a, [{_bs, be} | b_rest] = b) when as > be do
    debug(4, a, b)
    intersect(a, b_rest)
  end

  # b_head starts after the end of a_list
  # list so we advance the first list since there
  # is no intersection.
  #
  # This clause deals with the following relationship between the two
  # list heads:
  #
  # List 1:  <----------------->
  # List 2:                       <---------------->

  def intersect([{_as, ae} | a_rest] = a, [{bs, _be} | _b_rest] = b) when bs > ae do
    debug(5, a, b)
    intersect(a_rest, b)
  end

  # b_head is wholly withing a_head so the
  # intersection if the whole of b_head.
  #
  # This clause deals with the following relationship between the two
  # list heads:
  #
  # List 1:  <----------------->
  # List 2:     <----------->

  def intersect([{as, ae} | a_rest] = a, [{bs, be} | b_rest] = b) when bs > as and be < ae do
    debug(6, a, b)
    [{bs, be} | intersect([{be + 1, ae} | a_rest], b_rest)]
  end

  # An intersection which consumes the head of the second
  # list so we advance that list.
  #
  # This clause deals with the following relationship between the two
  # list heads:
  #
  # List 1:    <------------->
  # List 2:  <----------------->

  def intersect([{as, ae} | a_rest] = a, [{bs, be} | b_rest] = b) when bs < as and be > ae do
    debug(7, a, b)
    [{as, ae} | intersect(a_rest, [{ae + 1, be} | b_rest])]
  end

  # a_head ends at the same place as b_head
  # but b_head starts after a_head
  #
  # This clause deals with the following relationship between the two
  # list heads:
  #
  # List 1:  <----------------->
  # List 2:     <-------------->

  def intersect([{as, ae} | a_rest] = a, [{bs, ae} | b_rest] = b) when as < bs do
    debug(8, a, b)
    [{bs, ae} | intersect(a_rest, b_rest)]
  end

  # a_head ends at the same place as b_head
  # but a_head starts after b_head
  #
  # This clause deals with the following relationship between the two
  # list heads:
  #
  # List 1:      <------------->
  # List 2:  <----------------->

  def intersect([{as, ae} | a_rest] = a, [{bs, ae} | b_rest] = b) when as > bs do
    debug(9, a, b)
    [{as, ae} | intersect(a_rest, b_rest)]
  end

  # a_head overlaps b_head but to the right
  #
  # This clause deals with the following relationship between the two
  # list heads:
  #
  # List 1:      <----------------->
  # List 2:  <----------------->

  def intersect([{as, ae} | a_rest] = a, [{bs, be} | b_rest] = b) when as > bs and ae > be do
    debug(10, a, b)
    [{as, be} | intersect([{be + 1, ae} | a_rest], b_rest)]
  end

  # a_head overlaps b_head but to the left
  #
  # This clause deals with the following relationship between the two
  # list heads:
  #
  # List 1:  <----------------->
  # List 2:      <----------------->

  def intersect([{as, ae} | a_rest] = a, [{bs, be} | b_rest] = b) when as < bs and ae < be do
    debug(10, a, b)
    [{bs, ae} | intersect(a_rest, [{ae + 1, be} | b_rest])]
  end

  def intersect(a, [] = b) do
    debug(13, a, b)
    []
  end

  def intersect([] = a, b) do
    debug(14, a, b)
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
  #
  # List A:  <------------>
  # List B:  <------------>
  #
  # Since a_head and b_head are not different
  # they are omitted from the result.

  def difference([a_head | a_rest] = a, [a_head | b_rest] = b) do
    debug(1, a, b)
    difference(a_rest, b_rest)
  end

  def difference([a_head | a_rest] = a, a_head = b) do
    debug("1b", a, b)
    a_rest
  end

  # 2. list-B is after head-A
  #
  # List A:  <----------------->
  # List B:                       <----------------->
  #
  # Since list_b is completely after head_a then
  # there is nothing to subtract from head_a so
  # head_a is returned in full and we difference
  # a_rest with b

  def difference([{as, ae} | a_rest] = a, [{bs, _be} | _b_rest] = b) when ae < bs do
    debug(2, a, b)
    [{as, ae} | difference(a_rest, b)]
  end

  # 3. list-B head is completely before list-A head
  #
  # List A:                       <----------------->
  # List B:  <----------------->
  #
  # In this case b_head is a not part of a_head
  # and is therefore b_head is discarded

  def difference([{as, _ae} | _a_rest] = a, [{_bs, be} | b_rest] = b) when as > be do
    debug(3, a, b)
    difference(a, b_rest)
  end

  # 4. list-B head is contained wholly within list-A head
  #
  # List A:  <----------------->
  # List B:     <---------->
  #
  # In this case the difference is the part of a_head
  # that is before the start of b_gead as well as the
  # part of a_head that is after the end b_head

  def difference([{as, ae} | a_rest] = a, [{bs, be} | b_rest] = b) when as < bs and ae > be do
    debug(4, a, b)
    [{as, bs - 1} | difference([{be + 1, ae} | a_rest], b_rest)]
  end

  # 5. list-B head is at the start of list-A head and is shorter than list-A head
  #
  # List A:  <----------------->
  # List B:  <---------->
  #
  # In this case the difference is the part of a_head
  # that is after the end b_head

  def difference([{as, ae} | a_rest] = a, [{as, be} | b_rest] = b) when ae > be do
    debug(5, a, b)
    difference([{be + 1, ae} | a_rest], b_rest)
  end

  # 6. list-B head is at the start of list-A head and is shorter than list-A head
  #
  # List A:  <------------>
  # List B:  <----------------->
  #
  # In this case the difference is the part of a_head
  # that is after the end b_head

  def difference([{as, ae} | a_rest] = a, [{as, be} | b_rest] = b) when ae < be do
    debug(6, a, b)
    difference(a_rest, [{ae + 1, be} | b_rest])
  end

  # 7. list-B head is at the end of list-A head and is shorter than list-A head
  #
  # List A:  <----------------->
  # List B:         <---------->
  #
  # In this case the difference is the part of a_head
  # that is after the end b_head

  def difference([{as, ae} | a_rest] = a, [{bs, ae} | b_rest] = b) when as < bs do
    debug(7, a, b)
    [{as, bs - 1} | difference(a_rest, b_rest)]
  end

  # 8. list-A head is at the end of list-B head and is shorter than list-B head
  #
  # List A:       <----->
  # List B:  <---------->
  #
  # In this case b_head completely covers a_head
  # so a_head if omitted

  def difference([{as, ae} | a_rest] = a, [{bs, ae} | b_rest] = b) when as >= bs do
    debug(8, a, b)
    difference(a_rest, b_rest)
  end

  # 9. list-B head encloses list-A head
  #
  # List A:    <----->
  # List B:  <---------->
  #
  # In this case b_head completely covers a_head
  # so a_head if omitted but we need to check
  # the end of b_head against the a_rest

  def difference([{as, ae} | a_rest] = a, [{bs, be} | b_rest] = b) when as > bs and ae < be do
    debug(9, a, b)
    difference(a_rest, [{ae + 1, be} | b_rest])
  end

  # 10. list-B head overlaps behind list-A head
  #
  # List A:  <---------->
  # List B:     <---------->
  #
  # In this case b_head partially covers
  # a_head so remove those parts of a_head
  # covered by b_head but keep the remainder
  # of b_head because it may relate to a_rest

  def difference([{as, ae} | a_rest] = a, [{bs, be} | b_rest] = b) when as < bs and ae < be do
    debug(10, a, b)
    [{as, bs - 1} | difference(a_rest, [{ae + 1, be} | b_rest])]
  end

  # 11. list-B head overlaps in front list-A head
  #
  # List A:     <---------->
  # List B:  <---------->
  #
  # In this case b_head partially covers
  # a_head so remove those parts of a_head
  # covered by b_head but keep the remainder
  # of a_head because it may relate to b_rest

  def difference([{as, ae} | a_rest] = a, [{bs, be} | b_rest] = b) when as > bs and ae > be do
    debug(11, a, b)
    difference([{be + 1, ae} | a_rest], b_rest)
  end

  # 12. list-B head ends where list-A head starts
  #
  # List A:             <---------->
  # List B:  <---------->
  #
  # In this case b_head partially covers
  # a_head so remove those parts of a_head
  # covered by b_head but keep the remainder
  # of b_head because it may relate to a_rest

  def difference([{as, ae} | a_rest] = a, [{_bs, as} | b_rest] = b) do
    debug(12, a, b)
    difference([{as + 1, ae} | a_rest], b_rest)
  end

  # 13. list-A is empty
  def difference([] = a, b_list) do
    debug(13, a, b_list)
    []
  end

  # 14. list-B is empty
  def difference(a_list, [] = b_list) do
    debug(14, a_list, b_list)
    a_list
  end

  # def difference(a_list, b_tuple) when is_tuple(b_tuple) do
  #   debug(15, a_list, b_tuple)
  #   difference(a_list, [b_tuple])
  # end

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
  Returns the complement (inverse) of a set.

  """
  def complement(%Unicode.Set{parsed: {:in, parsed}} = set) do
    %{set | parsed: {:not_in, parsed}}
  end

  def complement(%Unicode.Set{parsed: {:not_in, parsed}} = set) do
    %{set | parsed: {:in, parsed}}
  end

  def complement(%Unicode.Set{state: :parsed} = set) do
    set
    |> reduce
    |> complement
  end

  def complement(%Unicode.Set{parsed: parsed} = set) do
    %{set | parsed: complement(parsed)}
  end

  def complement(ranges) when is_list(ranges) do
    difference(Unicode.all(), ranges)
  end

  @doc """
  Prewalks the expanded AST from a parsed
  Unicode Set invoking a function on each
  codepoint range in the set.

  """
  def traverse(%Unicode.Set{parsed: ranges}, fun) do
    traverse(ranges, fun)
  end

  def traverse(ranges, fun) when is_function(fun) do
    traverse(ranges, nil, fun)
  end

  def traverse(%Unicode.Set{parsed: ranges}, var, fun) do
    traverse(ranges, var, fun)
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

  # defp maybe_list_wrap(term) when is_list(term), do: term
  # defp maybe_list_wrap(term), do: [term]
end
