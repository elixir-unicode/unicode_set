defmodule Unicode.Set do
  import NimbleParsec
  import Unicode.Set.Parser

  defparsec(
    :parse,
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
end
