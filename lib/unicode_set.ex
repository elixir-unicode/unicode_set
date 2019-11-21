defmodule Unicode.Set do
  import NimbleParsec
  import Unicode.Set.Parser

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

  defparsec(
    :one_set,
    choice([
      property(),
      empty_set(),
      basic_set()
    ])
  )

  defparsec(
    :value,
    value_1()
  )

  defparsec(
    :quoted,
    quoted()
  )

  defdelegate union(list1, list2), to: Unicode.Set.Operation
  defdelegate intersect(list1, list2), to: Unicode.Set.Operation
  defdelegate difference(list1, list2), to: Unicode.Set.Operation
end
