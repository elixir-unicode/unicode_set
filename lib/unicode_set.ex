defmodule Unicode.Set do
  @moduledoc File.read!("README.md")
             |> String.split("<!-- MDOC -->")
             |> Enum.at(1)

  import NimbleParsec
  import Unicode.Set.Parser
  alias Unicode.Set.{Operation, Transform}

  defstruct [:set, :parsed]

  @doc """
  Parses a Unicode Set binary into an internal
  AST-like representation

  ## Example

      iex> Unicode.Set.parse("[[:Zs:]]")
      {:ok, %#{inspect __MODULE__}{
        set:
          "[[:Zs:]]",
        parsed:
         [
           in: [
             {32, 32},
             {160, 160},
             {5760, 5760},
             {8192, 8202},
             {8239, 8239},
             {8287, 8287},
             {12288, 12288}
           ]
        ]
      }}

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

  @doc false
  @dialyzer {:nowarn_function, one_set: 1}
  defparsec(:one_set, unicode_set())

  def parse(unicode_set) do
    case parse_one(unicode_set) do
      {:ok, parsed, "", _, _, _} ->
        {:ok, struct(__MODULE__, [set: unicode_set, parsed: parsed])}

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
  def parse_and_expand(unicode_set) do
    with {:ok, parsed} <- parse(unicode_set) do
      {:ok, Operation.expand(parsed)}
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

  * `Unicode.match?/2` can be used in as `defguard` argument.
    For example:

      defguard is_lower(codepoint) when Unicode.Set.match?(codepoint, "[[:Lu:]]")

  * Or as a guard clause itself:

      def my_function(<< codepoint :: utf8, _rest :: binary>>)
      #=>    when Unicode.Set.match?(codepoint, "[[:Lu:]]")

  """

  defmacro match?(var, unicode_set) do
    assert_binary_parameter!(unicode_set)

    parse!(unicode_set)
    |> Operation.expand()
    |> Operation.traverse(var, &Transform.guard_clause/3)
  end

  def to_pattern(unicode_set) when is_binary(unicode_set) do
    with {:ok, parsed} <- parse(unicode_set) do
      parsed
      |> Operation.expand()
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
      |> Operation.expand()
      |> Operation.traverse(&Transform.utf8_char/3)
    end
  end

  def to_character_class(unicode_set) when is_binary(unicode_set) do
    with {:ok, parsed} <- parse(unicode_set) do
      parsed
      |> Operation.expand()
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
    with {:ok, parsed} <- parse(unicode_set) do
      parsed
      |> Operation.expand()
      |> Operation.traverse(&Transform.regex/3)
      |> extract_and_expand_string_ranges
      |> return(:ok)
    end
  end

  def to_regex_string!(unicode_set) when is_binary(unicode_set) do
    case to_regex_string(unicode_set) do
      {:error, {exception, reason}} -> raise exception, reason
      {:ok, class} -> class
    end
  end

  # Separate the string ranges from the character
  # classes and then expand the string ranges
  defp extract_and_expand_string_ranges(elements) do
    Enum.reduce(elements, {[], []}, fn
      {first, last}, {strings, classes} -> {strings, [{first, last} | classes]}
      string, {strings, classes} -> {[string | strings], classes}
    end)
    |> expand_string_ranges
    |> form_regex_string
  end

  defp expand_string_ranges({strings, string_ranges}) do
    string_alternates =
      string_ranges
      |> Unicode.Set.Operation.expand_string_ranges
      |> Enum.map(fn {first, _last} -> List.to_string(first) end)

    {Enum.reverse(strings), string_alternates}
  end

  defp form_regex_string({["^" | strings], []}) do
    "[^" <> Enum.join(strings) <> "]"
  end

  defp form_regex_string({["^" | _strings], _string_ranges}) do
    {:error, {Unicode.Set.ParseError, "Can't negate string ranges"}}
  end

  defp form_regex_string({strings, []}) do
    "[" <> Enum.join(strings) <> "]"
  end

  defp form_regex_string({[], string_ranges}) do
    "(" <> Enum.join(string_ranges, "|") <> ")"
  end

  defp form_regex_string({strings, string_ranges}) do
    "([" <> Enum.join(strings) <> "]|" <> Enum.join(string_ranges, "|") <> ")"
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

  defp return(term, atom) do
    {atom, term}
  end
end
