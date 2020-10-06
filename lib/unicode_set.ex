defmodule Unicode.Set do
  @moduledoc File.read!("README.md")
             |> String.split("<!-- MDOC -->")
             |> Enum.at(1)

  import NimbleParsec
  import Unicode.Set.Parser

  alias Unicode.Set.{Operation, Transform, Search}

  defstruct [:set, :parsed, :state]

  @doc """
  Parses a Unicode Set binary into an internal
  AST-like representation

  ## Example

      Unicode.Set.parse("[[:Zs:]]")
      #=> {:ok, #Unicode.Set<[[:Zs:]]>}

  """
  defparsec(
    :parse_one,
    parsec(:one_set)
    |> eos()
  )

  @doc false
  defparsec(
    :parse_many,
    parsec(:one_set)
    |> ignore(optional(whitespace()))
    |> repeat(parsec(:one_set))
    |> eos()
  )

  defparsec(
    :parse_regex,
    repeat(
      parsec(:one_set)
      |> optional(repetition())
      |> ignore(optional(whitespace()))
    )
    |> optional(anchor())
    |> eos()
  )

  @doc false
  @dialyzer {:nowarn_function, one_set: 1}
  defparsec(:one_set, unicode_set())

  def parse(unicode_set) do
    case parse_one(unicode_set) do
      {:ok, parsed, "", _, _, _} ->
        set = [set: unicode_set, parsed: parsed, state: :parsed]
        {:ok, struct(__MODULE__, set)}

      {:error, message, rest, _, _, _} ->
        {:error, parse_error(unicode_set, message, rest)}
    end
  end

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
  def parse_and_reduce(unicode_set) do
    with {:ok, parsed} <- parse(unicode_set) do
      {:ok, Operation.reduce(parsed)}
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
        |> Unicode.Set.parse!
        |> Operation.reduce()
        |> Search.build_search_tree()
        |> Macro.escape

      quote do
        Unicode.Set.Search.member?(unquote(var), unquote(search_tree))
      end
    end
  end

  def to_pattern(unicode_set) when is_binary(unicode_set) do
    with {:ok, parsed} <- parse(unicode_set) do
      parsed
      |> Operation.reduce()
      |> Operation.traverse(&Transform.pattern/3)
    end
  end

  def compile_pattern(unicode_set) when is_binary(unicode_set) do
    with pattern when is_list(pattern) <- to_pattern(unicode_set) do
      :binary.compile_pattern(pattern)
    end
  end

  def to_utf8_char(unicode_set) when is_binary(unicode_set) do
    with {:ok, parsed} <- parse(unicode_set) do
      parsed
      |> Operation.reduce()
      |> Operation.traverse(&Transform.utf8_char/3)
    end
  end

  def to_character_class(unicode_set) when is_binary(unicode_set) do
    with {:ok, parsed} <- parse(unicode_set) do
      parsed
      |> Operation.reduce()
      |> Operation.traverse(&Transform.character_class/3)
      |> Enum.join
    end
  end

  def to_character_class!(unicode_set) when is_binary(unicode_set) do
    case to_character_class(unicode_set) do
      {:error, {exception, reason}} -> raise exception, reason
      class -> class
    end
  end

  def to_regex_string(unicode_set) when is_binary(unicode_set) do
    with {:ok, set} <- parse_and_reduce(unicode_set),
         {:ok, set} <- not_in_has_no_string_ranges(set) do
      set
      |> maybe_expand
      |> Operation.traverse(&Transform.regex/3)
      |> extract_string_ranges
      |> expand_string_ranges
      |> form_regex_string
      |> return(:ok)
    end
  end

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
    if Enum.find(ranges, &string_range?/1) do
      {:error, negative_set_error()}
    else
      {:ok, set}
    end
  end

  defp not_in_has_no_string_ranges(%{parsed: [{:in, _}, {:not_in, ranges}]} = set) do
    if Enum.find(ranges, &string_range?/1) do
      {:error, negative_set_error()}
    else
      {:ok, set}
    end
  end

  # If its just an `:in` set then no expansion is required
  defp maybe_expand(%{parsed: {:in, _ranges}} = set) do
    set
  end

  # If its just an `:not_in` set then expansion is only required
  # if there are string ranges
  defp maybe_expand(%{parsed: {:not_in, ranges}} = set) do
    if Enum.find(ranges, &string_range?/1) do
      Operation.expand(set)
    else
      set
    end
  end

  # Must have both `:in` and `:not_in` so must be expanded
  # since to honour the union of two ranges they need to
  # be combined
  defp maybe_expand(set) do
    Operation.expand(set)
  end

  defp string_range?({from, _to}) when is_list(from), do: true
  defp string_range?(_), do: false

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
      |> Unicode.Set.Operation.expand_string_ranges
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

  # We receive a tuple of two lists:
  # * A list of normal regexable expressions
  # * A list of string ranges that are expanded

  defp form_regex_string({strings, []}) do
    form_regex_string(strings)
  end

  defp form_regex_string({[], string_ranges}) do
    form_string_ranges(string_ranges)
  end

  defp form_regex_string({["^" | _rest], _string_ranges}) do
    {exception, reason} = negative_set_error()
    raise exception, reason
  end

  defp form_regex_string({[_first, ["^" | _rest]], _string_ranges}) do
    {exception, reason} = negative_set_error()
    raise exception, reason
  end

  defp form_regex_string({strings, string_ranges}) do
    "(" <> form_regex_string(strings) <> "|" <> form_string_ranges(string_ranges) <> ")"
  end

  defp form_regex_string([list_one, list_two]) when is_list(list_one) and is_list(list_two) do
    ["[", join_regex_strings(list_one), join_regex_strings(list_two), "]"]
    |> :erlang.iolist_to_binary
  end

  defp form_regex_string(strings) do
    join_regex_strings(strings)
  end

  defp join_regex_strings(strings) when is_list(strings) do
    "[" <> Enum.join(strings) <> "]"
  end

  defp form_string_ranges(string_ranges) do
    Enum.join(string_ranges, "|")
  end

  defp assert_binary_parameter!(unicode_set) do
    unless is_binary(unicode_set) do
      raise ArgumentError,
            "unicode_set must be a compile-time binary. Found #{inspect(unicode_set)}"
    end
  end

  defp parse_error(unicode_set, message, "") do
    {Unicode.Set.ParseError,
      "Unable to parse #{inspect unicode_set}. " <>
      "#{message}."
    }
  end

  defp parse_error(unicode_set, message, rest) do
    {Unicode.Set.ParseError,
      "Unable to parse #{inspect unicode_set}. " <>
      "#{message}. Detected at #{inspect rest}."
    }
  end

  defp negative_set_error() do
    {Unicode.Set.ParseError, "Negative sets with string ranges is not supported"}
  end

  defp return(term, atom) do
    {atom, term}
  end
end
