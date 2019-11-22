defmodule Unicode.Set do
  @moduledoc File.read!("README.md")
  |> String.split("<!-- MDOC -->")
  |> Enum.at(1)

  import NimbleParsec
  import Unicode.Set.Parser
  alias Unicode.Set.{Operation, Transform}

  @doc """
  Parses a Unicode Set binary into an internal
  AST-like representation

  ## Example

      iex> Unicode.Set.parse("[[:Zs:]]")
      {:ok,
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
       ], "", %{}, {1, 0}, 8}

  """
  defparsec(
    :parse,
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

  defparsecp(
    :one_set,
    choice([
      property(),
      empty_set(),
      basic_set()
    ])
  )

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

    #==> defguard is_lower(codepoint) when Unicode.Set.match?("[[:Lu:]]")

  * Or as a guard clause itself:

    #==> def my_function(<< codepoint :: utf8, _rest :: binary>>) when Unicode.Set.match?("[[:Lu:]]")

  """

  defmacro match?(var, unicode_set) do
    unless is_binary(unicode_set) do
      raise ArgumentError,
        "unicode_set must be a compile-time binary. Found #{inspect unicode_set}"
    end

    parsed =
      case parse(unicode_set) do
        {:ok, result, "", _, _, _} ->
          result
        {:error, message} ->
          raise ArgumentError, "Could not parse #{inspect unicode_set}. #{message}"
      end

    guard_clause =
      parsed
      |> Operation.expand()
      |> Transform.ranges_to_guard_clause(var)

    quote do
      unquote(guard_clause)
    end
  end
end
