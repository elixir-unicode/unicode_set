defmodule Unicode.Set.SearchTree do

  defstruct [:binary_tree, :operation]

  def build_search_tree(%Unicode.Set{parsed: {operation, tuple_list}, state: :expanded}) do
    search_tree = build_search_tree(tuple_list)
    struct(__MODULE__, binary_tree: search_tree, operation: operation)
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

  def member?(char, %__MODULE__{binary_tree: tree, operation: :in}) do
    member?(char, tree)
  end

  def member?(char, %__MODULE__{binary_tree: tree, operation: :not_in}) do
    !member?(char, tree)
  end

  def member?(char, {start, finish}) when char in start..finish do
    true
  end

  def member?(_char, {start, finish}) when is_integer(start) and is_integer(finish) do
    false
  end

  def member?(char, {_left, {right_start, right_finish}}) when char in right_start..right_finish do
    true
  end

  def member?(char, {{left_start, left_finish}, _right}) when char in left_start..left_finish do
    true
  end

  # This is not at all optimal. Currently the implementation
  # Can't tell whether to take the left or the right branch
  # since its just nested tuples.
  def member?(char, {left, right}) do
    member?(char, left) || member?(char, right)
  end

end