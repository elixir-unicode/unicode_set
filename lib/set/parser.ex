defmodule Unicode.Set.Parser do
  @moduledoc false

  import NimbleParsec
  import Unicode.Set.Property

  def basic_set do
    ignore(ascii_char([?[]))
    |> optional(ascii_char([?-, ?^]))
    |> ignore(optional(whitespace()))
    |> times(sequence(), min: 1)
    |> ignore(ascii_char([?]]))
    |> reduce(:reduce_set_operations)
    |> label("set")
  end

  def empty_set do
    string("[-]")
    |> label("empty set")
  end

  def sequence do
    choice([
      maybe_repeated_set(),
      range()
    ])
    |> ignore(optional(whitespace()))
    |> label("sequence")
  end

  def maybe_repeated_set do
    parsec(:one_set)
    |> repeat(set_operator() |> parsec(:one_set))
    |> reduce(:reduce_set_operations)
  end

  def reduce_set_operations([set_a]) do
    set_a
  end

  def reduce_set_operations([set_a, operator, set_b])
      when operator in [:difference, :intersection] do
    {operator, [set_a, set_b]}
  end

  def reduce_set_operations([set_a, operator, set_b | repeated_sets])
      when operator in [:difference, :intersection] do
    reduce_set_operations([{operator, [set_a, set_b]} | repeated_sets])
  end

  def reduce_set_operations([set_a | rest]) do
    {:merge, [set_a, reduce_set_operations(rest)]}
  end

  def set_operator do
    ignore(optional(whitespace()))
    |> choice([
      ascii_char([?&]) |> replace(:intersection),
      ascii_char([?-]) |> replace(:difference)
    ])
    |> ignore(optional(whitespace()))
  end

  def range do
    choice([
      char()
      |> ignore(optional(whitespace()))
      |> optional(ignore(ascii_char([?-]))
      |> ignore(optional(whitespace()))
      |> concat(char())),
      ascii_char([?{])
      |> times(ignore(optional(whitespace())) |> concat(char()), min: 1)
      |> ignore(optional(whitespace()))
      |> ascii_char([?}])
    ])
    |> reduce(:reduce_range)
    |> unwrap_and_tag(:range)
    |> label("range")
  end

  def reduce_range([arg]), do: [arg, arg]
  def reduce_range(arg), do: arg

  def property do
    choice([
      perl_property(),
      posix_property()
    ])
    |> post_traverse(:reduce_property)
    |> label("property")
  end

  def posix_property do
    ignore(string("[:"))
    |> optional(ascii_char([?^]) |> replace(:not))
    |> concat(property_name())
    |> optional(operator() |> ignore(optional(whitespace())) |> concat(value_2()))
    |> ignore(string(":]"))
    |> label("posix property")
  end

  def perl_property do
    ignore(ascii_char([?\\]))
    |> choice([ascii_char([?P]) |> replace(:not), ignore(ascii_char([?p]))])
    |> ignore(ascii_char([?{]))
    |> concat(property_name())
    |> optional(operator() |> ignore(optional(whitespace())) |> concat(value_1()))
    |> ignore(ascii_char([?}]))
    |> label("perl property")
  end

  def operator do
    choice([
      ascii_char([?≠]) |> replace(:not_equal),
      ascii_char([?=]) |> replace(:equal)
    ])
  end

  def reduce_property(_rest, [:not, value, operator, property], context, _line, _offset) do
    with {:ok, {property, value}} <- fetch_property(property, value) do
      {[{:not, {operator, [property, value]}}], context}
    end
  end

  def reduce_property(_rest, [value, operator, property], context, _line, _offset) do
    with {:ok, {property, value}} <- fetch_property(property, value) do
      {[{operator, [property, value]}], context}
    end
  end

  def reduce_property(_rest, [:not, value], context, _line, _offset) do
    with {:ok, {property, value}} <- fetch_property(:script_or_category, value) do
      {[{:not, {:equal, [property, value]}}], context}
    end
  end

  def reduce_property(_rest, [value], context, _line, _offset) do
    with {:ok, {property, value}} <- fetch_property(:script_or_category, value) do
      {[{:equal, [property, value]}], context}
    end
  end

  @alphanumeric [?a..?z, ?A..?Z, ?0..?9]
  def property_name do
    ignore(optional(whitespace()))
    |> ascii_char(@alphanumeric)
    |> repeat(ascii_char(@alphanumeric ++ [?_, ?\s]))
    |> ignore(optional(whitespace()))
    |> reduce(:to_lower_string)
    |> label("property name")
  end

  def value_1 do
    times(
      choice([
        ignore(ascii_char([?\\])) |> concat(quoted()),
        ascii_char([{:not, ?}}])
      ]),
      min: 1
    )
    |> reduce(:to_lower_string)
  end

  def value_2 do
    times(
      choice([
        ignore(ascii_char([?\\])) |> concat(quoted()),
        ascii_char([{:not, ?:}])
      ]),
      min: 1
    )
    |> reduce(:to_lower_string)
  end

  def to_lower_string(args) do
    args
    |> List.to_string()
    |> String.replace(" ", "_")
    |> String.downcase()
  end

  @whitespace_chars [0x20, 0x9..0xD, 0x85, 0x200E, 0x200F, 0x2028, 0x2029]
  def whitespace do
    times(ascii_char(@whitespace_chars), min: 1)
  end

  @syntax_chars [?&, ?-, ?[, ?], ?\\, ?{, ?}] ++ @whitespace_chars
  @not_syntax_chars Enum.map(@syntax_chars, fn c -> {:not, c} end)
  def char do
    utf8_char(@not_syntax_chars)
  end

  def quoted do
    choice([
      ascii_char([?u]) |> choice([times(hex(), 4), bracketed_hex()]),
      ascii_char([?x]) |> choice([times(hex(), 2), bracketed_hex()]),
      string("U00")
      |> choice([ascii_char([?0]) |> times(hex(), 5), string("10") |> times(hex(), 4)]),
      string("N{") |> concat(property_name()) |> ascii_char([?}]),
      utf8_char([0x0..0x10FFFF])
    ])
    |> label("quoted character")
  end

  def bracketed_hex do
    ascii_char([?{])
    |> ignore(optional(whitespace()))
    |> concat(hex_codepoint())
    |> repeat(ignore(optional(whitespace())) |> concat(hex_codepoint()))
    |> ignore(optional(whitespace()))
    |> ascii_char([?}])
    |> label("bracketed hex")
  end

  def hex_codepoint do
    choice([
      times(hex(), min: 1, max: 5),
      string("10") |> times(hex(), 4)
    ])
    |> label("hex codepoint")
  end

  def hex do
    ascii_char([?a..?f, ?A..?F, ?0..?9])
    |> label("hex character")
  end
end
