defmodule Unicode.Regex do
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
      {:error, {Unicode.Set.ParseError,
        "Unable to parse \\"[:ZZZZ:]\\". The unicode script, category or property \\"zzzz\\" is not known."}}

  """
  def compile(string, options \\ @default_options) do
    options = force_unicode_option(options)

    string
    |> split_ranges
    |> Enum.reverse
    |> recombine_sets
    |> expand_sets
    |> Enum.join
    |> Regex.compile(options)

  rescue e in Unicode.Set.ParseError ->
      {:error, {e.__struct__, e.message}}
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

  defp split_ranges(<< "[", rest :: binary >>, acc) do
    split_ranges(rest, ["[" | acc])
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

  defp recombine_sets(["" | rest]) do
    recombine_sets(rest)
  end

  defp recombine_sets(["[" | rest]) do
    {set, rest} =
      Cldr.Enum.reduce_peeking(rest, "[", fn
        "]", tail, acc -> {:halt, {acc <> "]", tail}}
        other, _tail, acc -> {:cont, acc <> other}
      end)

    [set | recombine_sets(rest)]
  end

  defp recombine_sets(element) do
    element
  end

  defp expand_sets([<< "[", set :: binary >>| rest]) do
    [Unicode.Set.to_regex_string!("[" <> set) | expand_sets(rest)]
  end

  defp expand_sets([<< "\\", c :: binary-1, set :: binary >> | rest]) when c in ["p", "P"] do
    [Unicode.Set.to_regex_string!("\\" <> c <> set) | expand_sets(rest)]
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