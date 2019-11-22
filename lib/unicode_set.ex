defmodule Unicode.Set do
  @moduledoc File.read!("README.md")
  |> String.split("<!-- MDOC -->")
  |> Enum.at(1)

  import NimbleParsec
  import Unicode.Set.Parser
  alias Unicode.Set.{Operation, Transform}

  defparsec(
    :parse,
    parsec(:one_set)
    |> eos()
  )

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

  defmacro matches?(var, unicode_set) do
    unless is_binary(unicode_set) do
      raise ArgumentError,
        "unicode set must be a compile-time binary. Found #{inspect unicode_set}"
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
