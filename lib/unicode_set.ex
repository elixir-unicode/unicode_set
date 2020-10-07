defmodule Unicode.Set do
  @moduledoc File.read!("README.md")
             |> String.split("<!-- MDOC -->")
             |> Enum.at(1)

  import NimbleParsec
  import Unicode.Set.Parser

  alias Unicode.Set.{Operation, Transform, Search}

  @keys [:set, :parsed, :state]
  @enforce_keys @keys
  defstruct @keys

  @type codepoint :: 0..1_114_111
  @type character_range :: {codepoint, codepoint}
  @type string_range :: {charlist, charlist}
  @type range :: character_range | string_range
  @type range_list :: [range]

  @type codepoint_range :: %Range{first: codepoint, last: codepoint}
  @type nimble_range :: codepoint | codepoint_range | {:not, codepoint | codepoint_range}
  @type nimble_list :: [nimble_range]

  @type state :: nil | :reduced | :expanded

  @type operator :: :union | :intersection | :difference | :in | :not_in
  @type operation :: [{operator, operation | range_list}] | {operator, operation | range_list}

  @type t :: %__MODULE__{
          set: binary(),
          parsed: operation() | range_list(),
          state: state()
        }

  defparsecp(
    :one_set,
    unicode_set()
  )

  defparsecp(
    :parse_one,
    parsec(:one_set)
    |> eos()
  )

  defparsecp(
    :parse_many,
    parsec(:one_set)
    |> ignore(optional(whitespace()))
    |> repeat(parsec(:one_set))
    |> eos()
  )

  @spec parse(binary) :: {:ok, t()} | {:error, {module(), binary()}}
  def parse(unicode_set) do
    case parse_one(unicode_set) do
      {:ok, parsed, "", _, _, _} ->
        set = [set: unicode_set, parsed: parsed, state: :parsed]
        {:ok, struct(__MODULE__, set)}

      {:error, message, rest, _, _, _} ->
        {:error, parse_error(unicode_set, message, rest)}
    end
  rescue
    e in Regex.CompileError ->
      {:error, parse_error(unicode_set, e.message, "")}
  end

  @spec parse!(binary) :: t() | no_return()
  def parse!(unicode_set) do
    case parse(unicode_set) do
      {:ok, result} ->
        result

      {:error, {exception, reason}} ->
        raise exception, reason
    end
  end

  @doc """
  Parses a unicode set and expands the
  set expressions then compacts the
  character ranges.

  """
  @spec parse_and_reduce(binary) :: {:ok, t()} | {:error, {module(), binary()}}
  def parse_and_reduce(unicode_set) do
    with {:ok, parsed} <- parse(unicode_set) do
      {:ok, Operation.reduce(parsed)}
    end
  end

  @spec parse_and_reduce!(binary) :: t() | no_return()
  def parse_and_reduce!(unicode_set) do
    case parse_and_reduce(unicode_set) do
      {:ok, result} ->
        result

      {:error, {exception, reason}} ->
        raise exception, reason
    end
  end

  @doc """
  Returns a boolean based upon whether `var`
  matches the provided `unicode_set`.

  ## Arguments

  * `var` is any integer variable (since codepoints
    are integers)

  * `unicode_set` is a binary representation of
    a unicode set. An exception will be raised if `unicode_set`
    is not a compile time binary

  ## Returns

  `true` or `false`

  ## Examples

  * `Unicode.Set.match?/2` can be used in as `defguard` argument.
    For example:

      defguard is_lower(codepoint) when Unicode.Set.match?(codepoint, "[[:Lu:]]")

  * Or as a guard clause itself:

      def my_function(<< codepoint :: utf8, _rest :: binary>>)
      #=>    when Unicode.Set.match?(codepoint, "[[:Lu:]]")

  """

  defmacro match?(var, unicode_set) do
    assert_binary_parameter!(unicode_set)

    if __CALLER__.context == :guard do
      parse!(unicode_set)
      |> Operation.reduce()
      |> Operation.traverse(var, &Transform.guard_clause/3)
    else
      search_tree =
        unicode_set
        |> Unicode.Set.parse!()
        |> Operation.reduce()
        |> Search.build_search_tree()
        |> Macro.escape()

      quote do
        Unicode.Set.Search.member?(unquote(var), unquote(search_tree))
      end
    end
  end

  @spec to_pattern(binary()) :: {:ok, [binary()]} | {:error, {module(), binary()}}
  def to_pattern(unicode_set) when is_binary(unicode_set) do
    with {:ok, parsed} <- parse(unicode_set) do
      parsed
      |> Operation.reduce()
      |> Operation.traverse(&Transform.pattern/3)
      |> return(:ok)
    end
  end

  @spec to_pattern!(binary) :: t() | no_return()
  def to_pattern!(unicode_set) do
    case to_pattern(unicode_set) do
      {:ok, result} ->
        result

      {:error, {exception, reason}} ->
        raise exception, reason
    end
  end

  @spec compile_pattern(binary()) :: {:ok, [binary()]} | {:error, {module(), binary()}}
  def compile_pattern(unicode_set) when is_binary(unicode_set) do
    with {:ok, pattern} <- to_pattern(unicode_set) do
      {:ok, :binary.compile_pattern(pattern)}
    end
  end

  @spec to_utf8_char(binary()) :: {:ok, nimble_list} | {:error, {module(), binary()}}
  def to_utf8_char(unicode_set) when is_binary(unicode_set) do
    with {:ok, parsed} <- parse(unicode_set) do
      parsed
      |> Operation.reduce()
      |> Operation.traverse(&Transform.utf8_char/3)
      |> return(:ok)
    end
  end

  @spec to_utf8_char!(binary) :: t() | no_return()
  def to_utf8_char!(unicode_set) do
    case to_utf8_char(unicode_set) do
      {:ok, result} ->
        result

      {:error, {exception, reason}} ->
        raise exception, reason
    end
  end

  @spec to_regex_string(binary()) :: {:ok, binary()} | {:error, {module(), binary()}}
  def to_regex_string(unicode_set) when is_binary(unicode_set) do
    with {:ok, set} <- parse_and_reduce(unicode_set),
         {:ok, set} <- not_in_has_no_string_ranges(set) do
      set
      |> maybe_expand_set
      |> Operation.traverse(&Transform.regex/3)
      |> extract_string_ranges
      |> expand_string_ranges
      |> form_regex_string
      |> :erlang.iolist_to_binary()
      |> return(:ok)
    end
  end

  @spec to_regex_string!(binary()) :: binary() | no_return()
  def to_regex_string!(unicode_set) when is_binary(unicode_set) do
    case to_regex_string(unicode_set) do
      {:error, {exception, reason}} -> raise exception, reason
      {:ok, regex_string} -> regex_string
    end
  end

  defp not_in_has_no_string_ranges(%{parsed: {:in, _ranges}} = set) do
    {:ok, set}
  end

  defp not_in_has_no_string_ranges(%{parsed: {:not_in, ranges}} = set) do
    if Enum.any?(ranges, &string_range?/1), do: {:error, negative_set_error()}, else: {:ok, set}
  end

  defp not_in_has_no_string_ranges(%{parsed: [{:in, _}, {:not_in, ranges}]} = set) do
    if Enum.any?(ranges, &string_range?/1), do: {:error, negative_set_error()}, else: {:ok, set}
  end

  defp string_range?({from, _to}) when is_list(from), do: true
  defp string_range?(_), do: false

  # If its just an `:in` set then no expansion is required
  defp maybe_expand_set(%{parsed: {:in, _ranges}} = set) do
    set
  end

  # if there are string ranges
  defp maybe_expand_set(%{parsed: {:not_in, ranges}} = set) do
    if Enum.any?(ranges, &string_range?/1), do: Operation.expand(set), else: set
  end

  # Must have both `:in` and `:not_in` so must be expanded
  # since to honour the union of two ranges they need to
  # be combined
  defp maybe_expand_set(set) do
    Operation.expand(set)
  end

  # Separate the string ranges from the character
  # ranges and then expand the string ranges
  defp extract_string_ranges(elements, acc \\ {[], []}) do
    Enum.reduce(elements, acc, fn
      elements, {strings, classes} when is_list(elements) ->
        {add_strings, add_classes} = extract_string_ranges(elements, acc)
        {[add_strings | strings], add_classes ++ classes}

      {first, last}, {strings, classes} ->
        {strings, [{first, last} | classes]}

      string, {strings, classes} ->
        {[string | strings], classes}
    end)
  end

  @doc false
  def expand_string_ranges({strings, string_ranges}) do
    string_alternates =
      string_ranges
      |> Operation.expand_string_ranges()
      |> maybe_wrap_list()
      |> Enum.map(&expand_string_range/1)

    {Enum.reverse(strings), string_alternates}
  end

  defp expand_string_range(string_range) when is_list(string_range) do
    Enum.map(string_range, fn {first, first} -> List.to_string(first) end)
  end

  defp maybe_wrap_list([]), do: []
  defp maybe_wrap_list([head | _rest] = range) when is_list(head), do: range
  defp maybe_wrap_list(range), do: [range]

  # Regex strings but no string ranges
  defp form_regex_string({strings, []}) do
    form_regex_string(strings)
  end

  # No regex strings, only string ranges
  defp form_regex_string({[], string_ranges}) do
    form_string_ranges(string_ranges)
  end

  # String ranges in a negative set is not supported
  defp form_regex_string({["^" | _rest], _string_ranges}) do
    {exception, reason} = negative_set_error()
    raise exception, reason
  end

  # String ranges in a negative set is not supported
  defp form_regex_string({[_first, ["^" | _rest]], _string_ranges}) do
    {exception, reason} = negative_set_error()
    raise exception, reason
  end

  # Both regex strings and string ranges
  defp form_regex_string({strings, string_ranges}) do
    ["(", form_regex_string(strings), "|", form_string_ranges(string_ranges), ")"]
  end

  defp form_regex_string([list_one, list_two]) when is_list(list_one) and is_list(list_two) do
    ["[", join_regex_strings(list_one), join_regex_strings(list_two), "]"]
  end

  defp form_regex_string(strings) do
    join_regex_strings(strings)
  end

  defp join_regex_strings(strings) when is_list(strings) do
    ["[", strings, "]"]
  end

  defp form_string_ranges(string_ranges) do
    Enum.intersperse(string_ranges, "|")
  end

  defp assert_binary_parameter!(unicode_set) do
    unless is_binary(unicode_set) do
      raise ArgumentError,
            "unicode_set must be a compile-time binary. Found #{inspect(unicode_set)}"
    end
  end

  defp parse_error(unicode_set, message, "") do
    {Unicode.Set.ParseError,
     "Unable to parse #{inspect(unicode_set)}. " <>
       "#{message}."}
  end

  defp parse_error(unicode_set, message, rest) do
    {Unicode.Set.ParseError,
     "Unable to parse #{inspect(unicode_set)}. " <>
       "#{message}. Detected at #{inspect(rest)}."}
  end

  defp negative_set_error() do
    {Unicode.Set.ParseError, "Negative sets with string ranges are not supported"}
  end

  defp return(term, atom) do
    {atom, term}
  end
end
