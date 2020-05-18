defmodule Unicode.Regex do
  @moduledoc """
  Preprocesses a binary regular expression to expand
  Unicode Sets which are then interpolated back into
  the Regular Expression which is then compiled with
  `Regex.compile/2` or `Regex.compile!/2`.

  """

  @open_posix_set "[:"
  @close_posix_set ":]"

  @open_perl_set "\\p{"
  @open_perl_not_set "\\P{"
  @close_perl_set "}"

  @unicode_sets Regex.compile!("\\[:|:\\]|\\\\p{|\\\\P{|}", [:unicode, :ungreedy])

  @default_options "u"

  @doc """
  Compiles a binary regular expression after
  interpolating any Unicode Sets.

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
    @unicode_sets
    |> Regex.split(string, include_captures: true, trim: true)
    |> expand_sets
    |> case do
      {:error, _} = error ->
        error
      expansion ->
        expansion
        |> Enum.join
        |> make_character_class
        |> Regex.compile(options)
    end
  end

  defp make_character_class(string) do
    "[" <> string <> "]"
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

  def expand_sets(sets) do
    do_expand_sets(sets)
  rescue e in Unicode.Set.ParseError ->
    {:error, {e.__struct__, e.message}}
  end

  def do_expand_sets([]) do
    []
  end

  def do_expand_sets([@open_posix_set, "^" <> set, @close_posix_set | rest]) do
    expansion = Unicode.Set.character_class!(@open_posix_set <> set <> @close_posix_set)
    ["^#{expansion}" | expand_sets(rest)]
  end

  def do_expand_sets([@open_posix_set, set, @close_posix_set | rest]) do
    [Unicode.Set.character_class!(@open_posix_set <> set <> @close_posix_set) | expand_sets(rest)]
  end

  def do_expand_sets([@open_perl_set, set, @close_perl_set | rest]) do
    [Unicode.Set.character_class!(@open_perl_set <> set <> @close_perl_set) | expand_sets(rest)]
  end

  def do_expand_sets([@open_perl_not_set, set, @close_perl_set | rest]) do
    [Unicode.Set.character_class!(@open_perl_not_set <> set <> @close_perl_set) | expand_sets(rest)]
  end

  def do_expand_sets([head | rest]) do
    [head | expand_sets(rest)]
  end
end