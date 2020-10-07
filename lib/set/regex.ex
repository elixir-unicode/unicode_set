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

  * `{:error, {message, index}}`

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
    |> split_character_classes
    |> expand_unicode_sets
    |> Enum.join()
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
      {:error, {message, index}} -> raise(Regex.CompileError, "#{message} at position #{index}")
    end
  end

  @doc """
  Returns a boolean indicating whether there was a match or not
  with a Unicode Set.

  ## Arguments

  * `regex_string` is a regular expression in
    string form.

  * `string` is any string against which
    the regex match is executed

  * `options` is a string or a list which is
    passed unchanged to `Regex.compile/2`.
    The default is "u" meaning the regular
    expression will operate in Unicode mode

  ## Returns

  * a boolean indicating if there was a match or

  * raises an exception if `regex` is not
    a valid regular expression.

  ## Example

      iex> Unicode.Regex.match?("[:Sc:]", "$")
      true

  """
  def match?(regex_string, string, opts \\ @default_options)

  def match?(regex_string, string, opts) when is_binary(regex_string) do
    regex = compile!(regex_string, opts)
    Regex.match?(regex, string)
  end

  def match?(%Regex{} = regex, string, _opts) do
    Regex.match?(regex, string)
  end

  @doc """
  Split a regex into character classes
  so that these can then be later compiled.

  ## Arguments

  * `string` is a regular expression in
    string form.

  ## Returns

  * A list of string split at the
    boundaries of unicode sets

  ## Example

      iex> Unicode.Regex.split_character_classes("This is [:Zs:] and more")
      ["This is ", "[:Zs:]", " and more"]

  """
  def split_character_classes(string) do
    string
    |> split_character_classes([""])
    |> Enum.reverse()
  end

  defp split_character_classes("", acc) do
    acc
  end

  defp split_character_classes(<<"\\p{", rest::binary>>, acc) do
    split_character_classes(rest, ["\\p{" | acc])
  end

  defp split_character_classes(<<"\\P{", rest::binary>>, acc) do
    split_character_classes(rest, ["\\P{" | acc])
  end

  defp split_character_classes(<<"\\", char::binary-1, rest::binary>>, [head | others]) do
    split_character_classes(rest, [head <> "\\" <> char | others])
  end

  defp split_character_classes(<<"[", _rest::binary>> = string, acc) do
    {character_class, rest} = extract_character_class(string)
    split_character_classes(rest, ["" | [character_class | acc]])
  end

  perl_set =
    quote do
      [<<"\\", var!(c)::binary-1, var!(head)::binary>> | var!(others)]
    end

  defp split_character_classes(<<"}", rest::binary>>, unquote(perl_set)) when is_perl_set(c) do
    split_character_classes(rest, ["" | ["\\" <> c <> head <> "}" | others]])
  end

  defp split_character_classes(<<"]", rest::binary>>, [head | others]) do
    split_character_classes(rest, ["" | [head <> "]" | others]])
  end

  defp split_character_classes(<<char::binary-1, rest::binary>>, [head | others]) do
    split_character_classes(rest, [head <> char | others])
  end

  # Extract a character class which may be
  # arbitrarily nested

  defp extract_character_class(string, level \\ 0)

  defp extract_character_class("" = string, _level) do
    {string, ""}
  end

  defp extract_character_class(<<"\\[", rest::binary>>, level) do
    {string, rest} = extract_character_class(rest, level)
    {"\\[" <> string, rest}
  end

  defp extract_character_class(<<"\\]", rest::binary>>, level) do
    {string, rest} = extract_character_class(rest, level)
    {"\\]" <> string, rest}
  end

  defp extract_character_class(<<"[", rest::binary>>, level) do
    {string, rest} = extract_character_class(rest, level + 1)
    {"[" <> string, rest}
  end

  defp extract_character_class(<<"]", rest::binary>>, 1) do
    {"]", rest}
  end

  defp extract_character_class(<<"]", rest::binary>>, level) do
    {string, rest} = extract_character_class(rest, level - 1)
    {"]" <> string, rest}
  end

  defp extract_character_class(<<char::binary-1, rest::binary>>, level) do
    {string, rest} = extract_character_class(rest, level)
    {char <> string, rest}
  end

  # Expand unicode sets to their codepoints

  defp expand_unicode_sets([<<"[", set::binary>> | rest]) do
    regex = "[" <> set

    case Unicode.Set.to_regex_string(regex) do
      {:ok, string} -> [string | expand_unicode_sets(rest)]
      {:error, _} -> [regex | expand_unicode_sets(rest)]
    end
  end

  defp expand_unicode_sets([<<"\\", c::binary-1, set::binary>> | rest]) when is_perl_set(c) do
    regex = "\\" <> c <> set

    case Unicode.Set.to_regex_string(regex) do
      {:ok, string} -> [string | expand_unicode_sets(rest)]
      {:error, _} -> [regex | expand_unicode_sets(rest)]
    end
  end

  defp expand_unicode_sets(["" | rest]) do
    expand_unicode_sets(rest)
  end

  defp expand_unicode_sets([head | rest]) do
    [head | expand_unicode_sets(rest)]
  end

  defp expand_unicode_sets([]) do
    []
  end

  # Always use the unicode option on the regex

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
