defmodule Unicode.Set.Parser do
  @moduledoc false

  import NimbleParsec
  import Unicode.Set.Property

  defguard is_hex_digit(c) when c in ?0..?9 or c in ?a..?z or c in ?A..?Z

  def unicode_set do
    choice([
      property(),
      empty_set(),
      basic_set()
    ])
  end

  def basic_set do
    ignore(ascii_char([?[]))
    |> optional(ascii_char([?-, ?^]) |> replace(:not))
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

  def reduce_set_operations([{:in, ranges1}, {:in, ranges2} | rest]) do
    reduce_set_operations([{:in, Enum.sort(ranges1 ++ ranges2)} | rest])
  end

  def reduce_set_operations([:not, {:in, ranges1}, {:in, ranges2} | rest]) do
    reduce_set_operations([:not, {:in, Enum.sort(ranges1 ++ ranges2)} | rest])
  end

  def reduce_set_operations([:not, {:in, ranges} | rest]) do
    reduce_set_operations([{:not_in, ranges} | rest])
  end

  def reduce_set_operations([set_a | rest]) do
    {:union, [set_a, reduce_set_operations(rest)]}
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
      character_range(),
      string_range()
    ])
    |> reduce(:reduce_range)
    |> post_traverse(:check_valid_range)
    |> label("range")
  end

  def character_range do
    char()
    |> ignore(optional(whitespace()))
    |> optional(
      ignore(ascii_char([?-]))
      |> ignore(optional(whitespace()))
      |> concat(char())
    )
  end

  # Of the forrm {abc} or {abc-def}
  def string_range do
    string()
    |> wrap
    |> ignore(optional(whitespace()))
    |> optional(
      ignore(ascii_char([?-]))
      |> ignore(optional(whitespace()))
      |> concat(string() |> wrap)
    )
  end

  def reduce_range([[bracketed]]) when is_list(bracketed),
    do: {:in, Enum.map(bracketed, &{&1, &1})}

  def reduce_range([[from]]) when is_integer(from), do: {:in, [{from, from}]}

  def reduce_range([[from], [to]]) when is_integer(from) and is_integer(to),
    do: {:in, [{from, to}]}

  def reduce_range([from]), do: {:in, [{from, from}]}
  def reduce_range([from, to]), do: {:in, [{from, to}]}

  def check_valid_range(_rest, [in: [{from, to}]] = args, context, _, _)
      when is_integer(from) and is_integer(to) do
    {args, context}
  end

  def check_valid_range(_rest, [in: [{from, from}]] = args, context, _, _) do
    {args, context}
  end

  def check_valid_range(_rest, [in: [{from, to}]] = args, context, _, _) do
    if length(from) == 1 or length(to) == 1 do
      {:error,
       "String ranges must be longer than one character. Found " <>
         format_string_range(from, to)}
    else
      {args, context}
    end
  end

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
      utf8_char([0x2260]) |> replace(:not_in),
      ascii_char([?=]) |> replace(:in)
    ])
  end

  def reduce_property(_rest, [value, :in, property, :not], context, _line, _offset) do
    with {:ok, ranges} <- fetch_property(property, value) do
      {[{:not_in, ranges}], context}
    end
  end

  def reduce_property(_rest, [value, :not_in, property, :not], context, _line, _offset) do
    with {:ok, ranges} <- fetch_property(property, value) do
      {[{:in, ranges}], context}
    end
  end

  def reduce_property(_rest, [value, operator, property], context, _line, _offset)
      when operator in [:in, :not_in] do
    with {:ok, ranges} <- fetch_property(property, value) do
      {[{operator, ranges}], context}
    end
  end

  def reduce_property(_rest, [value, :not], context, _line, _offset) do
    with {:ok, ranges} <- fetch_property(:script_or_category, value) do
      {[{:not_in, ranges}], context}
    end
  end

  def reduce_property(_rest, [value], context, _line, _offset) do
    with {:ok, ranges} <- fetch_property(:script_or_category, value) do
      {[{:in, ranges}], context}
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
  def whitespace_char do
    ascii_char(@whitespace_chars)
  end

  def whitespace do
    times(whitespace_char(), min: 1)
  end

  def string do
    ignore(ascii_char([?{]))
    |> times(ignore(optional(whitespace())) |> concat(char()), min: 1)
    |> ignore(optional(whitespace()))
    |> ignore(ascii_char([?}]))
  end

  @syntax_chars [?&, ?-, ?[, ?], ?\\, ?{, ?}] # ++ @whitespace_chars
  @not_syntax_chars Enum.map(@syntax_chars, fn c -> {:not, c} end)
  def char do
    choice([
      ignore(ascii_char([?\\])) |> concat(quoted()),
      utf8_char(@not_syntax_chars)
    ])
  end

  def quoted do
    choice([
      ignore(ascii_char([?x]))
      |> choice([
        ascii_char([?0]) |> times(hex(), 5),
        ascii_char([?1]) |> ascii_char([?0]) |> times(hex(), 4)
      ]),
      string("N{") |> concat(property_name()) |> ascii_char([?}]),
      ignore(ascii_char([?u])) |> choice([times(hex(), 4), bracketed_hex()]),
      ignore(ascii_char([?x])) |> choice([times(hex(), 2), bracketed_hex()]),
      utf8_char([0x0..0x10FFFF])
    ])
    |> reduce(:hex_to_codepoint)
    |> label("quoted character")
  end

  def bracketed_hex do
    ignore(ascii_char([?{]))
    |> ignore(optional(whitespace()))
    |> concat(hex_codepoint())
    |> repeat(ignore(optional(whitespace())) |> concat(hex_codepoint()))
    |> ignore(optional(whitespace()))
    |> ignore(ascii_char([?}]))
    |> wrap
    |> label("bracketed hex")
  end

  def hex_codepoint do
    choice([
      times(hex(), min: 1, max: 5),
      ascii_char([?1]) |> ascii_char([?0]) |> times(hex(), 4)
    ])
    |> wrap
    |> label("hex codepoint")
  end

  def hex do
    ascii_char([?a..?f, ?A..?F, ?0..?9])
    |> label("hex character")
  end

  # Its just an escaped char
  def hex_to_codepoint([?t]), do: ?\t
  def hex_to_codepoint([?n]), do: ?\n
  def hex_to_codepoint([?r]), do: ?\r
  def hex_to_codepoint([c]) when not is_hex_digit(c), do: c

  # Actual hex-encoded codepoints
  def hex_to_codepoint([arg | _rest] = args) when is_list(arg) do
    Enum.map(args, &hex_to_codepoint/1)
  end

  def hex_to_codepoint(args) do
    args
    |> List.to_string()
    |> String.to_integer(16)
  end


  # Applied to a regex
  def repetition do
    ignore(optional(whitespace()))
    |> choice([
      ascii_char([?*]) |> replace({:repeat, min: 0, max: :infinity}),
      ascii_char([?+]) |> replace({:repeat, min: 1, max: :infinity}),
      ascii_char([??]) |> replace({:repeat, min: 0, max: 1}),
      iterations()
    ])
  end

  def iterations do
    ignore(ascii_char([?{]))
    |> ignore(optional(whitespace()))
    |> integer(min: 1)
    |> ignore(optional(whitespace()))
    |> ignore(ascii_char([?,]))
    |> ignore(optional(whitespace()))
    |> integer(min: 1)
    |> ignore(optional(whitespace()))
    |> ignore(ascii_char([?}]))
    |> reduce(:iteration)
  end

  def iteration([from, to]) do
    {:repeat, min: from, max: to}
  end

  def anchor do
    ignore(optional(whitespace()))
    |> ascii_char([?$]) |> replace(:end)
  end

  #  Helpers
  #  -------

  defp format_string_range(from, to) do
    "{#{List.to_string(from)}}-{#{List.to_string(to)}}"
  end
end
