defmodule Unicode.Regex do
  @moduledoc """
  Implements [Unicode regular expressions](http://unicode.org/reports/tr18/)
  by transforming them into regular expressions supported by
  the Elixir Regex module.

  """

  @default_options "u"

  defguard is_perl_set(c) when c in ["p", "P"]

  @doc """
  Compiles a binary regular expression after
  expanding any Unicode Sets.

  ## Arguments

  * `string` is a regular expression in
    string form

  * `options` is a string or a list which is
    passed unchanged to `Regex.compile/2`.
    The default is "u" meaning the regular
    expression will operate in Unicode mode

  ## Returns

  * `{:ok, regex}` or

  * `{:error, {exception, message}}`

  ## Notes

  This function operates by splitting the string
  at the boundaries of Unicode Set markers which
  are:

  * Posix style: `[:` and `:]`
  * Perl style: `\\p{` and `}`

  This parsing is naive meaning that is does not
  take any character escaping into account when s
  plitting the string.

  ## Example

      iex> Unicode.Regex.compile("[:Zs:]")
      {:ok, ~r/[\\x{20}\\x{A0}\\x{1680}\\x{2000}-\\x{200A}\\x{202F}\\x{205F}\\x{3000}]/u}

      iex> Unicode.Regex.compile("\\\\p{Zs}")
      {:ok, ~r/[\\x{20}\\x{A0}\\x{1680}\\x{2000}-\\x{200A}\\x{202F}\\x{205F}\\x{3000}]/u}

      iex> Unicode.Regex.compile("[:ZZZZ:]")
      {:error, {'POSIX named classes are supported only within a class', 0}}

  """
  def compile(string, options \\ @default_options) do
    options = force_unicode_option(options)

    string
    |> split_ranges
    |> Enum.reverse
    |> expand_sets
    |> Enum.join
    |> Regex.compile(options)
  end

  @doc """
  Compiles a binary regular expression after
  interpolating any Unicode Sets.

  ## Arguments

  * `string` is a regular expression in
    string form.

  * `options` is a string or a list which is
    passed unchanged to `Regex.compile/2`.
    The default is "u" meaning the regular
    expression will operate in Unicode mode

  ## Returns

  * `regex` or

  * raises an exception

  ## Example

      iex> Unicode.Regex.compile!("[:Zs:]")
      ~r/[\\x{20}\\x{A0}\\x{1680}\\x{2000}-\\x{200A}\\x{202F}\\x{205F}\\x{3000}]/u

  """
  def compile!(string, opts \\ @default_options) do
    case compile(string, opts) do
      {:ok, regex} -> regex
      {:error, {exception, message}} when is_atom(exception) -> raise(exception, message)
      {:error, {message, index}} -> raise(Regex.CompileError, "#{message} at position #{index}")
    end
  end

  defp split_ranges(string, acc \\ [""])

  defp split_ranges("", acc) do
    acc
  end

  defp split_ranges(<< "\\p{", rest :: binary >>, acc) do
    split_ranges(rest,  ["\\p{" | acc])
  end

  defp split_ranges(<< "\\P{", rest :: binary >>, acc) do
    split_ranges(rest, ["\\P{" | acc])
  end

  defp split_ranges(<< "\\", char :: binary-1, rest :: binary >>, [head | others]) do
    split_ranges(rest, [head <> "\\" <> char | others])
  end

  defp split_ranges(<< "[", _rest :: binary >> = string, acc) do
    {character_class, rest} = consume_character_class(string)
    split_ranges(rest, [character_class | acc])
  end

  perl_set = quote do
    [<< "\\", var!(c) :: binary-1, var!(head) :: binary >> | var!(others)]
  end

  defp split_ranges(<< "}", rest :: binary >>, unquote(perl_set)) when is_perl_set(c) do
    split_ranges(rest, ["" | ["\\" <> c <> head <> "}" | others]])
  end

  defp split_ranges(<< "]", rest :: binary >>, [head | others]) do
    split_ranges(rest, ["" | [head <> "]" | others]])
  end

  defp split_ranges(<< char :: binary-1, rest :: binary >>, [head | others]) do
    split_ranges(rest, [head <> char | others])
  end

  defp consume_character_class(string, level \\ 0)

  defp consume_character_class("" = string, _level) do
    {string, ""}
  end

  defp consume_character_class(<< "\\[", rest :: binary >>, level) do
    {string, rest} = consume_character_class(rest, level)
    {"\\[" <> string, rest}
  end

  defp consume_character_class(<< "\\]", rest :: binary >>, level) do
    {string, rest} = consume_character_class(rest, level)
    {"\\]" <> string , rest}
  end

  defp consume_character_class(<< "[", rest :: binary >>, level) do
    {string, rest} = consume_character_class(rest, level + 1)
    {"[" <> string, rest}
  end

  defp consume_character_class(<< "]", rest :: binary >>, 1) do
    {"]", rest}
  end

  defp consume_character_class(<< "]", rest :: binary >>, level) do
    {string, rest} = consume_character_class(rest, level - 1)
    {"]" <> string, rest}
  end

  defp consume_character_class(<< char :: binary-1, rest :: binary >>, level) do
    {string, rest} = consume_character_class(rest, level)
    {char <> string, rest}
  end

  defp expand_sets([<< "[", set :: binary >> | rest]) do
    regex = "[" <> set

    case Unicode.Set.to_regex_string(regex) do
      {:ok, string} -> [string | expand_sets(rest)]
      {:error, _} -> [regex | expand_sets(rest)]
    end
  end

  defp expand_sets([<< "\\", c :: binary-1, set :: binary >> | rest]) when is_perl_set(c) do
    regex = "\\" <> c <> set

    case Unicode.Set.to_regex_string(regex) do
      {:ok, string} -> [string | expand_sets(rest)]
      {:error, _} -> [regex | expand_sets(rest)]
    end
  end

  defp expand_sets(["" | rest]) do
    expand_sets(rest)
  end

  defp expand_sets(element) do
    element
  end

  defp force_unicode_option(options) when is_binary(options) do
    if String.contains?(options, "u") do
      options
    else
      options <> "u"
    end
  end

  defp force_unicode_option(options) when is_list(options) do
    if Enum.find(options, &(&1 == :unicode)) do
      options
    else
      [:unicode | options]
    end
  end

end