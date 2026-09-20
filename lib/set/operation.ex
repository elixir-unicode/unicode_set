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
  # @debug_functions []

  defmacrop debug(step, a, b) do
    # {caller, _arity} = __CALLER__.function
    #
    # if caller in @debug_functions && Mix.env() == :dev do
    #   quote generated: true do
    #     IO.inspect("#{unquote(caller)}", label: "Step #{unquote(step)}")
    #     IO.inspect(unquote(a), label: "a")
    #     IO.inspect(unquote(b), label: "b")
    #   end
    # end
    caller = :unknown

    quote generated: true do
      _ = {unquote(step), unquote(a), unquote(b), unquote(caller)}
    end
  end

  @doc """
  Evaluates the set operations of a parsed set, leaving
  a list of code point ranges.

  A complement is preserved as `{:not_in, ranges}` for as
  long as possible, since guards, regexes and `nimble_parsec`
  can all consume an exclusion directly. Only an intersection
  or difference forces the ranges to be expanded into
  positive form.

  ### Arguments

  * `unicode_set` is a `t:Unicode.Set.t/0` returned by
    `Unicode.Set.parse/1`. A set that is already reduced or
    expanded is returned unchanged.

  ### Returns

  * The `t:Unicode.Set.t/0` with its `:parsed` field replaced by
    `{:in, ranges}`, `{:not_in, ranges}` or a list of such terms,
    and its `:state` set to `:reduced`.

  ### Examples

      iex> Unicode.Set.parse!("[[a-z]&[m-z]]") |> Unicode.Set.Operation.reduce() |> Map.get(:parsed)
      {:in, [{109, 122}]}

      iex> Unicode.Set.parse!("[^a-z]") |> Unicode.Set.Operation.reduce() |> Map.get(:parsed)
      {:not_in, [{97, 122}]}

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
        reduce_combined(ast)
      end
      |> compact_ranges

    %{unicode_set | parsed: reduced, state: :reduced}
  end

  defp reduce_combined(ast) do
    case combine(ast) do
      terms when is_list(terms) -> reduce_union_terms(terms, ast)
      combined -> combined
    end
  end

  defp reduce_union_terms(terms, ast) do
    if Enum.all?(terms, &match?({:not_in, _}, &1)) do
      # A pure union of complements (`[[^a][^b]]`) cannot be kept in the
      # compact `:not_in` form: per De Morgan `¬a ∪ ¬b == ¬(a ∩ b)`, so
      # merging the range lists by key (as `compact_ranges/1` would) yields
      # `¬(a ∪ b)`, the wrong set. Expand to a single positive range list.
      {:in, expand(ast)}
    else
      terms
    end
  end

  @doc """
  Expands a reduced set, or a reduced expression tree, into a
  single positive list of code point ranges.

  ### Arguments

  * `unicode_set` is a reduced `t:Unicode.Set.t/0`, or a reduced
    expression term such as `{:not_in, ranges}` or
    `{:union, [this, that]}`.

  ### Returns

  * For a `t:Unicode.Set.t/0`, the set with its `:parsed` field
    replaced by the expanded range list and its `:state` set to
    `:expanded`.

  * For a term, the expanded range list.

  ### Examples

      iex> Unicode.Set.parse_and_reduce!("[^a]") |> Unicode.Set.Operation.expand() |> Map.get(:parsed)
      [{0, 96}, {98, 1114111}]

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
  # of codepoints.

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
  Expands any string ranges in a range list into their
  individual string members.

  ### Arguments

  * `ranges` is a list of code point ranges and string ranges,
    where a string range is a `{from, to}` pair of charlists of
    the same length.

  ### Returns

  * The range list with each string range replaced by one
    `{string, string}` member per string in the range.

  ### Examples

      iex> Unicode.Set.Operation.expand_string_ranges([{97, 97}, {~c"ab", ~c"ad"}])
      [{97, 97}, {~c"ab", ~c"ab"}, {~c"ac", ~c"ac"}, {~c"ad", ~c"ad"}]

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

  # The empty-string member `{}` has nothing to expand.
  def expand_string_range({[], []}) do
    {[], []}
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
  Combines the terms of a union-only expression tree into a
  flat list of `{:in, ranges}` and `{:not_in, ranges}` terms.

  This is the fast path used by `reduce/1` when an expression
  contains no intersection or difference; otherwise the tree
  must be expanded with `expand/1`.

  ### Arguments

  * `ast` is a parsed expression term.

  ### Returns

  * A list of `{:in, ranges}` and `{:not_in, ranges}` terms, or
    a single such term.

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
  Merges overlapping and adjacent code point ranges.

  ### Arguments

  * `ranges` is a sorted list of `{first, last}` code point
    ranges and string members, or an `{:in, ranges}` or
    `{:not_in, ranges}` term, or a list of such terms.

  ### Returns

  * The same shape with overlapping and adjacent code point
    ranges merged. String members are deduplicated but
    otherwise kept as written.

  ### Examples

      iex> Unicode.Set.Operation.compact_ranges([{1, 2}, {3, 4}, {4, 9}])
      [{1, 9}]

      iex> Unicode.Set.Operation.compact_ranges({:in, [{97, 98}, {99, 99}]})
      {:in, [{97, 99}]}

  """
  def compact_ranges({:in, ranges}) do
    {:in, Unicode.Utils.compact_ranges(ranges)}
  end

  def compact_ranges({:not_in, ranges}) do
    {:not_in, Unicode.Utils.compact_ranges(ranges)}
  end

  # A list of `{:in, ranges}` / `{:not_in, ranges}` terms (the output of
  # `combine/1`): merge the range lists under each key.
  def compact_ranges([{key, _ranges} | _rest] = terms) when key in [:in, :not_in] do
    terms
    |> Enum.group_by(fn {k, _v} -> k end, fn {_k, v} -> v end)
    |> Enum.map(fn {k, v} ->
      {k, v |> List.flatten() |> Enum.sort() |> Unicode.Utils.compact_ranges()}
    end)
  end

  # A plain range list. Codepoint ranges are merged; string members and string
  # ranges are only deduplicated, since their endpoints are code point lists
  # (not scalars) and must be kept exactly as written. Codepoint ranges sort
  # before string ranges, matching the parser's term ordering.
  def compact_ranges(ranges) when is_list(ranges) do
    {codepoint_ranges, string_ranges} =
      Enum.split_with(ranges, fn {from, _to} -> is_integer(from) end)

    Unicode.Utils.compact_ranges(codepoint_ranges) ++ Enum.uniq(string_ranges)
  end

  @doc """
  Returns whether an expression tree contains an intersection
  or a difference.

  When it does, every range, including a complement, must be
  expanded before the operation can be evaluated. When it does
  not, a complement can be passed through as `{:not_in, ranges}`.

  ### Arguments

  * `ast` is a parsed expression term.

  ### Returns

  * `true` or `false`.

  ### Examples

      iex> Unicode.Set.Operation.has_difference_or_intersection?(Unicode.Set.parse!("[[a-z]&[m-z]]").parsed)
      true

      iex> Unicode.Set.Operation.has_difference_or_intersection?(Unicode.Set.parse!("[[a-z][m-z]]").parsed)
      false

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
  Returns the union of two lists of code point ranges.

  ### Arguments

  * `a_list` and `b_list` are lists of `{first, last}` code
    point ranges.

  ### Returns

  * A sorted, compacted list of the code point ranges in
    either list.

  ### Examples

      iex> Unicode.Set.Operation.union([{1, 3}, {10, 12}], [{4, 6}])
      [{1, 6}, {10, 12}]

  """
  def union(a_list, b_list) when is_list(a_list) and is_list(b_list) do
    (a_list ++ b_list)
    |> Enum.sort()
    |> Enum.uniq()
    |> Unicode.Utils.compact_ranges()
  end

  @doc """
  Returns the intersection of two lists of code point ranges.

  ### Arguments

  * `a` and `b` are sorted lists of `{first, last}` code point
    ranges with no overlapping ranges, as `compact_ranges/1`
    returns them.

  ### Returns

  * A sorted list of the code point ranges common to both.

  ### Examples

      iex> Unicode.Set.Operation.intersect([{1, 5}, {10, 20}], [{3, 12}])
      [{3, 5}, {10, 12}]

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

  # b_head is wholly within a_head so the
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
  Returns the difference of two lists of code point ranges.

  ### Arguments

  * `a` and `b` are sorted lists of `{first, last}` code point
    ranges with no overlapping ranges, as `compact_ranges/1`
    returns them.

  ### Returns

  * A sorted list of the code point ranges in `a` that are not
    in `b`.

  ### Examples

      iex> Unicode.Set.Operation.difference([{1, 10}], [{3, 4}, {8, 20}])
      [{1, 2}, {5, 7}]

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

  def difference([a_head | a_rest] = a, b) when b == a_head do
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
  Returns the symmetric difference of two lists of code point
  ranges.

  ### Arguments

  * `this` and `that` are lists of `{first, last}` code point
    ranges.

  ### Returns

  * A sorted list of the code point ranges in either list but
    not in both.

  ### Examples

      iex> Unicode.Set.Operation.symmetric_difference([{1, 5}], [{3, 8}])
      [{1, 2}, {6, 8}]

  """
  def symmetric_difference(this, that) do
    this = this |> Enum.sort() |> Unicode.Utils.compact_ranges()
    that = that |> Enum.sort() |> Unicode.Utils.compact_ranges()
    difference(union(this, that), intersect(this, that))
  end

  @doc """
  Returns the code point complement of a set or a range list.

  ### Arguments

  * `set` is a `t:Unicode.Set.t/0` in any state, or a list of
    `{first, last}` code point ranges.

  ### Returns

  * For a `t:Unicode.Set.t/0`, the set with `{:in, ranges}` and
    `{:not_in, ranges}` exchanged.

  * For a range list, the list of code points from U+0000 to
    U+10FFFF that are not in it.

  ### Examples

      iex> Unicode.Set.Operation.complement([{0, 96}, {98, 1114111}])
      [{97, 97}]

  """
  def complement(%Unicode.Set{parsed: {:in, parsed}} = set) do
    %{set | parsed: {:not_in, parsed}}
  end

  def complement(%Unicode.Set{parsed: {:not_in, parsed}} = set) do
    %{set | parsed: {:in, parsed}}
  end

  def complement(%Unicode.Set{state: :parsed} = set) do
    set
    |> reduce()
    |> complement()
  end

  def complement(%Unicode.Set{parsed: parsed} = set) do
    %{set | parsed: complement(parsed)}
  end

  def complement(ranges) when is_list(ranges) do
    difference(Unicode.all(), ranges)
  end

  @doc """
  Walks a reduced set, invoking a function on each code point
  range, and returns the results.

  This is how the transforms to guards, patterns, `utf8_char/1`
  lists and regex strings are built.

  ### Arguments

  * `set` is a reduced `t:Unicode.Set.t/0`, or its `:parsed`
    field.

  * `var` is an optional term passed through to `fun`, used to
    build guard clauses around a variable.

  * `fun` is a function of a range, the accumulated result and
    `var`.

  ### Returns

  * The result of applying `fun` across the ranges.

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
