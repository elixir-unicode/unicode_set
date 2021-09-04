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

  @type generated_match :: list(Macro.t() | String.t())

  @type state :: nil | :parsed | :reduced | :expanded

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

  * `true` or `false`

  ## Examples

  * `Unicode.Set.match?/2` can be used with `defguard/1`.
    For example:

  ```elixir
  defguard is_lower(codepoint) when Unicode.Set.match?(codepoint, "[[:Lu:]]")
  ```
  * Or as a guard clause itself:

  ```elixir
  def my_function(<< codepoint :: utf8, _rest :: binary>>)
    when Unicode.Set.match?(codepoint, "[[:Lu:]]")
  ```
  """

  defmacro match?(var, unicode_set) do
    unicode_set = assert_binary_parameter!(unicode_set)

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

  @doc """
  Transforms a Unicode Set into a pattern
  that can be used with `String.split/3`
  and `String.replace/3`.

  ## Arguements

  * `unicode_set` is a string representation
    of a Unicode Set

  ## Returns

  * `{:ok, pattern}` or

  * `{:error, {exception, reason}}`

  ## Example
  ```
      iex> pattern = Unicode.Set.to_pattern "[[:digit:]]"
      {:ok,
       ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "٠", "١", "٢", "٣",
        "٤", "٥", "٦", "٧", "٨", "٩", "۰", "۱", "۲", "۳", "۴", "۵", "۶",
        "۷", "۸", "۹", "߀", "߁", "߂", "߃", "߄", "߅", "߆", "߇", "߈", "߉",
        "०", "१", "२", "३", "४", "५", "६", "७", ...]}

  """
  @spec to_pattern(binary()) :: {:ok, [binary()]} | {:error, {module(), binary()}}
  def to_pattern(unicode_set) when is_binary(unicode_set) do
    with {:ok, parsed} <- parse(unicode_set) do
      parsed
      |> Operation.reduce()
      |> Operation.traverse(&Transform.pattern/3)
      |> return(:ok)
    end
  end

  @doc """
  Transforms a Unicode Set into a pattern
  that can be used with `String.split/3`
  and `String.replace/3`.

  ## Arguements

  * `unicode_set` is a string representation
    of a Unicode Set

  ## Returns

  * `pattern` or

  * raises an exception

  ## Example
  ```
      iex> pattern = Unicode.Set.to_pattern "[[:digit:]]"
      ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "٠", "١", "٢", "٣",
       "٤", "٥", "٦", "٧", "٨", "٩", "۰", "۱", "۲", "۳", "۴", "۵", "۶",
        "۷", "۸", "۹", "߀", "߁", "߂", "߃", "߄", "߅", "߆", "߇", "߈", "߉"
       "०", "१", "२", "३", "४", "५", "६", "७", ...]

  """
  @spec to_pattern!(binary) :: [binary()] | no_return()
  def to_pattern!(unicode_set) do
    case to_pattern(unicode_set) do
      {:ok, result} ->
        result

      {:error, {exception, reason}} ->
        raise exception, reason
    end
  end

  @doc """
  Transforms a Unicode Set into a compiled
  pattern that can be used with `String.split/3`
  and `String.replace/3`.

  [Compiled patterns](http://erlang.org/doc/man/binary.html#compile_pattern-1)
  can be the more performant when matching strings.

  ## Arguements

  * `unicode_set` is a string representation
    of a Unicode Set

  ## Returns

  * `{:ok, compiled_pattern}` or

  * `{:error, {exception, reason}}`

  ## Example
  ```
      iex> pattern = Unicode.Set.compile_pattern "[[:digit:]]"
      {:ok, {:ac, #Reference<0.2927979228.2367029250.255911>}}
      iex> String.split("abc1def2ghi3jkl", pattern)
      ["abc", "def", "ghi", "jkl"]

  """
  @spec compile_pattern(binary()) :: {:ok, [binary()]} | {:error, {module(), binary()}}
  def compile_pattern(unicode_set) when is_binary(unicode_set) do
    with {:ok, pattern} <- to_pattern(unicode_set) do
      {:ok, :binary.compile_pattern(pattern)}
    end
  end

  @doc """
  Transforms a Unicode Set into a list of
  codepoints that can be used with
  [nimble_parsec](https://hex.pm/packages/nimble_parsec).

  THe list of codepoints can be used as an
  argument to `NimbleParsec.utf8_char/1`.

  ## Arguements

  * `unicode_set` is a string representation
    of a Unicode Set

  ## Returns

  * `{:ok, list_of_codepints}` or

  * `{:error, {exception, reason}}`

  ## Example
  ```
      iex> pattern = Unicode.Set.to_utf8_char "[[:digit:]-[:Zs]]"
      {:ok,
       [48..57, 1632..1641, 1776..1785, 1984..1993, 2406..2415, 2534..2543,
        2662..2671, 2790..2799, 2918..2927, 3046..3055, 3174..3183, 3302..3311,
        3430..3439, 3558..3567, 3664..3673, 3792..3801, 3872..3881, 4160..4169,
        4240..4249, 6112..6121, 6160..6169, 6470..6479, 6608..6617, 6784..6793,
        6800..6809, 6992..7001, 7088..7097, 7232..7241, 7248..7257, 42528..42537,
        43216..43225, 43264..43273, 43472..43481, 43504..43513, 43600..43609,
        44016..44025, 65296..65305, 66720..66729, 68912..68921, 69734..69743,
        69872..69881, 69942..69951, 70096..70105, 70384..70393, 70736..70745,
        70864..70873, 71248..71257, 71360..71369, ...]}

  """
  @spec to_utf8_char(binary()) :: {:ok, nimble_list} | {:error, {module(), binary()}}
  def to_utf8_char(unicode_set) when is_binary(unicode_set) do
    with {:ok, parsed} <- parse(unicode_set) do
      parsed
      |> Operation.reduce()
      |> Operation.traverse(&Transform.utf8_char/3)
      |> return(:ok)
    end
  end

  @doc """
  Transforms a Unicode Set into a list of
  codepoints that can be used with
  [nimble_parsec](https://hex.pm/packages/nimble_parsec).

  THe list of codepoints can be used as an
  argument to `NimbleParsec.utf8_char/1`.

  ## Arguements

  * `unicode_set` is a string representation
    of a Unicode Set

  ## Returns

  * `list_of_codepints` or

  * raises an exception

  ## Example
  ```
      iex> pattern = Unicode.Set.to_utf8_char! "[[:digit:]-[:Zs]]"
      [48..57, 1632..1641, 1776..1785, 1984..1993, 2406..2415, 2534..2543,
       2662..2671, 2790..2799, 2918..2927, 3046..3055, 3174..3183, 3302..3311,
       3430..3439, 3558..3567, 3664..3673, 3792..3801, 3872..3881, 4160..4169,
       4240..4249, 6112..6121, 6160..6169, 6470..6479, 6608..6617, 6784..6793,
       6800..6809, 6992..7001, 7088..7097, 7232..7241, 7248..7257, 42528..42537,
       43216..43225, 43264..43273, 43472..43481, 43504..43513, 43600..43609,
       44016..44025, 65296..65305, 66720..66729, 68912..68921, 69734..69743,
       69872..69881, 69942..69951, 70096..70105, 70384..70393, 70736..70745,
       70864..70873, 71248..71257, 71360..71369, ...]}

  """
  @spec to_utf8_char!(binary) :: nimble_list | no_return()
  def to_utf8_char!(unicode_set) do
    case to_utf8_char(unicode_set) do
      {:ok, result} ->
        result

      {:error, {exception, reason}} ->
        raise exception, reason
    end
  end

  @doc """
  Transforms a Unicode Set into a regex
  string that can be used as an argument
  to `Regex.compile/1`.

  ## Arguements

  * `unicode_set` is a string representation
    of a Unicode Set

  ## Returns

  * `{:ok, regex_string}` or

  * `{:error, {exception, reason}}`

  ## Example
  ```
      iex> Unicode.Set.to_regex_string "[[:Zs]-[\s]]"
      {:ok, "[\\x{3A}\\x{5A}\\x{73}]"}

  """
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

  @doc """
  Transforms a Unicode Set into a regex
  string that can be used as an argument
  to `Regex.compile/1`.

  ## Arguements

  * `unicode_set` is a string representation
    of a Unicode Set

  ## Returns

  * `regex_string` or

  * raises an exception

  ## Example
  ```
      iex> Unicode.Set.to_regex_string "[[:Zs]-[\s]]"
      {:ok, "[\\x{3A}\\x{5A}\\x{73}]"}

  """
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
      |> Enum.map(&expand_string_range/1)

    {Enum.reverse(strings), string_alternates}
  end

  defp expand_string_range(string_range) when is_list(string_range) do
    Enum.map(string_range, &expand_string_range/1)
  end

  defp expand_string_range({first, first}) do
    List.to_string(first)
  end

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
    ["(?:", form_regex_string(strings), "|", form_string_ranges(string_ranges), ")"]
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

  @doc false

  # This function takes a unicode set and returns
  # a 2-tuple where the first element is a guard clause
  # and the second element is a list of strings
  #
  # The primary use of this function is to return
  # a structure than can be used to generate code that
  # matches a string to a unicode set without having to
  # use regexs. The library `unicode_transform` uses
  # this function for that purpose.

  @spec generate_matches(binary(), any()) :: {:ok, generated_match()} | {:error, {module(), binary()}}
  def generate_matches(unicode_set, var) when is_binary(unicode_set) do
    with {:ok, set} <- parse_and_reduce(unicode_set),
         {:ok, set} <- not_in_has_no_string_ranges(set) do
      expanded = maybe_expand_set(set)

      strings =
        expanded
        |> Operation.traverse(&Transform.regex/3)
        |> extract_string_ranges
        |> expand_string_ranges
        |> elem(1)

      guard =
        expanded
        |> Map.fetch!(:parsed)
        |> Operation.traverse(var, &Transform.reject_string_range/3)
        |> Operation.traverse(var, &Transform.guard_clause/3)

      if guard == false do
        {:ok, strings}
      else
        {:ok, [guard | strings]}
      end
    end
  end

  @doc false
  @spec generate_matches!(binary(), any()) :: generated_match() | no_return()
  def generate_matches!(unicode_set, var) when is_binary(unicode_set) do
    case generate_matches(unicode_set, var) do
      {:error, {exception, reason}} -> raise exception, reason
      {:ok, match_strings} -> match_strings
    end
  end

  # Assert that the argument is a binary or
  # if the argument is a struct from this module
  # then extract the binary set.

  defp assert_binary_parameter!(unicode_set) do
    case unicode_set do
      unicode_set when is_binary(unicode_set) ->
        unicode_set
      {:%, _, [{:__aliases__, _, [:UnicodeSet]}, {:%{}, _, fields}]} ->
        Keyword.fetch!(fields, :set) |> assert_binary_parameter!
      {:%, _, [{:__aliases__, _, [:Unicode, :Set]}, {:%{}, _, fields}]} ->
        Keyword.fetch!(fields, :set) |> assert_binary_parameter!
      true ->
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
