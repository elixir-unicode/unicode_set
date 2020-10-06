defmodule Unicode.Set.Search do
  defstruct [:binary_tree, :string_ranges, :operation]

  def build_search_tree(%Unicode.Set{parsed: {operation, tuple_list}, state: :reduced}) do
    {ranges, string_ranges} = extract_and_expand_string_ranges(tuple_list)
    search_tree = build_search_tree(ranges)
    search_struct = [binary_tree: search_tree, string_ranges: string_ranges, operation: operation]
    struct(__MODULE__, search_struct)
  end

  def build_search_tree([]) do
    {}
  end

  def build_search_tree([tuple]) when is_tuple(tuple) do
    tuple
  end

  def build_search_tree([left, right]) when is_tuple(left) and is_tuple(right) do
    {left, right}
  end

  def build_search_tree(tuple_list) when is_list(tuple_list) do
    count = Enum.count(tuple_list)
    {left, right} = Enum.split(tuple_list, div(count, 2))
    {build_search_tree(left), build_search_tree(right)}
  end

  def extract_and_expand_string_ranges(tuples) do
    Enum.reduce(tuples, {[], []}, fn
      {from, to} = tuple, {ranges, string_ranges} when is_list(from) and is_list(to) ->
        {ranges, [tuple | string_ranges]}

      tuple, {ranges, string_ranges} ->
        {[tuple | ranges], string_ranges}
    end)
    |> Unicode.Set.expand_string_ranges()
    |> tag_string_ranges
  end

  defp tag_string_ranges({ranges, string_ranges}) do
    string_patterns =
      Enum.map(string_ranges, fn [hd | _rest] = range ->
        [String.length(hd) | range]
      end)

    {ranges, string_patterns}
  end

  def member?(codepoint, %__MODULE__{binary_tree: tree, operation: :in})
      when is_integer(codepoint) do
    member?(codepoint, tree)
  end

  def member?(codepoint, %__MODULE__{binary_tree: tree, operation: :not_in})
      when is_integer(codepoint) do
    !member?(codepoint, tree)
  end

  string_match =
    quote do
      <<var!(codepoint)::utf8, _rest::binary>> = var!(string)
    end

  def member?(unquote(string_match), %__MODULE__{operation: :in} = search_tree) do
    %__MODULE__{binary_tree: tree, string_ranges: strings} = search_tree
    member?(codepoint, tree) || string_member?(string, strings)
  end

  def member?(unquote(string_match), %__MODULE__{operation: :not_in} = search_tree) do
    %__MODULE__{binary_tree: tree, string_ranges: strings} = search_tree
    not (member?(codepoint, tree) || string_member?(string, strings))
  end

  def member?(_codepoint, {}) do
    false
  end

  def member?(codepoint, {start, finish})
      when is_integer(codepoint) and codepoint in start..finish do
    true
  end

  def member?(codepoint, {start, finish})
      when is_integer(codepoint) and is_integer(start) and is_integer(finish) do
    false
  end

  def member?(codepoint, {_left, {right_start, right_finish}})
      when is_integer(codepoint) and codepoint in right_start..right_finish do
    true
  end

  def member?(codepoint, {{left_start, left_finish}, _right})
      when is_integer(codepoint) and codepoint in left_start..left_finish do
    true
  end

  # This is not at all optimal. Currently the implementation
  # Can't tell whether to take the left or the right branch
  # since its just nested tuples.
  def member?(codepoint, {left, right}) when is_integer(codepoint) do
    member?(codepoint, left) || member?(codepoint, right)
  end

  def string_member?(string, strings) do
    Enum.reduce_while(strings, false, fn [len | pattern], acc ->
      pattern = :binary.compile_pattern(pattern)

      if :binary.match(string, pattern, scope: {0, len}) == :nomatch do
        {:cont, acc}
      else
        {:halt, true}
      end
    end)
  end
end
