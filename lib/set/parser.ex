defmodule Unicode.Set.Parser do
  @moduledoc false

  import NimbleParsec
  import Unicode.Set.Property

  @doc false
  def unicode_set do
    choice([
      property(),
      empty_set(),
      basic_set()
    ])
  end

  @doc false
  def basic_set do
    ignore(ascii_char([?[]))
    |> optional(ascii_char([?^]) |> replace(:not))
    |> ignore(optional(whitespace()))
    |> optional(literal_hyphen())
    |> times(sequence(), min: 1)
    |> optional(literal_hyphen())
    |> ignore(ascii_char([?]]))
    |> reduce(:reduce_set_operations)
    |> label("set")
  end

  @doc false
  # A `-` immediately after `[`/`[^` or immediately before `]` has no operand to
  # its left/right, so it is a literal hyphen rather than a range or difference
  # operator (matching ICU): `[-a]`, `[a-]`, `[a-z-]`. (`[-]` alone is the empty
  # set, handled by `empty_set/0` which is tried first.)
  def literal_hyphen do
    ascii_char([?-])
    |> replace({:in, [{?-, ?-}]})
    |> ignore(optional(whitespace()))
  end

  @doc false
  # `[]` is the empty set (TR61). `[-]` is also treated as the empty set; this
  # is a deliberate tailoring — a lone hyphen elsewhere (`[-a]`, `[a-]`) is a
  # literal hyphen (see `literal_hyphen/0`), but `[-]` alone stays empty for
  # backwards compatibility with earlier versions of this library.
  def empty_set do
    choice([string("[-]"), string("[]")])
    |> replace({:in, []})
    |> label("empty set")
  end

  @doc false
  def sequence do
    choice([
      maybe_repeated_set(),
      quoted_literal(),
      range()
    ])
    |> ignore(optional(whitespace()))
    |> label("sequence")
  end

  @doc false
  # Single-quote quoting (CLDR TR35): text within `'...'` is literal — special
  # characters lose their meaning — and two adjacent single quotes `''` are one
  # literal quote (inside or outside a quoted span). An unterminated `'` falls
  # through to being a literal quote character.
  def quoted_literal do
    choice([
      string("''") |> replace(?'),
      ignore(ascii_char([?']))
      |> repeat(quoted_char())
      |> ignore(ascii_char([?']))
    ])
    |> reduce(:quoted_to_set)
    |> label("quoted literal")
  end

  @doc false
  def quoted_char do
    choice([
      string("''") |> replace(?'),
      utf8_char([{:not, ?'}])
    ])
  end

  @doc false
  def quoted_to_set(codepoints) do
    {:in, codepoints |> Enum.sort() |> Enum.map(&{&1, &1})}
  end

  @doc false
  def maybe_repeated_set do
    parsec(:one_set)
    |> repeat(set_operator() |> parsec(:one_set))
  end

  # Fails the Elixir 1.18 type checker for now.
  # Revisit by Elixir 1.19.

  # @debug_functions []
  #
  # defmacrop tracer(step, a) do
  #   {caller, _} = __CALLER__.function
  #
  #   if Mix.env() in [:dev] and caller in @debug_functions do
  #     quote do
  #       IO.inspect("#{unquote(caller)}", label: "Step #{unquote(step)}")
  #       IO.inspect(unquote(a), label: "argument")
  #     end
  #   else
  #     quote do
  #       _ = {unquote(step), unquote(a)}
  #     end
  #   end
  # end

  defmacrop tracer(step, a) do
    quote do
      _ = {unquote(step), unquote(a)}
    end
  end

  @doc false
  def reduce_set_operations([set_a]) do
    tracer(0, [set_a])
    set_a
  end

  # A leading `^` complements the set. Merge any adjacent plain classes first so
  # the complement applies to their union, then flip `:in` <-> `:not_in`.
  def reduce_set_operations([:not, {:in, ranges1}, {:in, ranges2} | rest]) do
    tracer(1, [:not, {:in, ranges1}, {:in, ranges2} | rest])
    reduce_set_operations([:not, {:in, Enum.sort(ranges1 ++ ranges2)} | rest])
  end

  def reduce_set_operations([:not, {:in, ranges} | rest]) do
    tracer(2, [:not, {:in, ranges} | rest])
    reduce_set_operations([{:not_in, ranges} | rest])
  end

  def reduce_set_operations([:not, {:not_in, ranges} | rest]) do
    tracer(3, [:not, {:not_in, ranges} | rest])
    reduce_set_operations([{:in, ranges} | rest])
  end

  def reduce_set_operations([:not | rest]) do
    tracer(4, [:not | rest])
    reduce_set_operations([{:not_in, rest}])
  end

  # The binary operators (implicit union, `&`, `-`) have equal precedence and
  # bind left-to-right (TR35). Fold the flat operand/operator sequence so each
  # operator applies to the entire accumulated result, not just its neighbour.
  def reduce_set_operations([set_a | rest]) do
    tracer(5, [set_a | rest])
    fold_set_operations(rest, set_a)
  end

  defp fold_set_operations([], accumulated) do
    accumulated
  end

  defp fold_set_operations([operator, set_b | rest], accumulated)
       when operator in [:intersection, :difference] do
    fold_set_operations(rest, {operator, [accumulated, set_b]})
  end

  defp fold_set_operations([set_b | rest], accumulated) do
    fold_set_operations(rest, union_ast(accumulated, set_b))
  end

  # Adjacent plain character classes coalesce into one `:in` list; any other
  # union becomes an explicit `:union` node for `Operation.reduce/1` to evaluate.
  defp union_ast({:in, ranges1}, {:in, ranges2}) do
    {:in, Enum.sort(ranges1 ++ ranges2)}
  end

  defp union_ast(accumulated, set_b) do
    {:union, [accumulated, set_b]}
  end

  @doc false
  def set_operator do
    ignore(optional(whitespace()))
    |> choice([
      ascii_char([?&]) |> replace(:intersection),
      ascii_char([?-]) |> replace(:difference)
    ])
    |> ignore(optional(whitespace()))
  end

  @doc false
  def range do
    choice([
      character_range(),
      string_range()
    ])
    |> reduce(:reduce_range)
    |> post_traverse(:check_valid_range)
    |> label("range")
  end

  @doc false
  def character_range do
    char()
    |> ignore(optional(whitespace()))
    |> optional(
      ignore(ascii_char([?-]))
      |> ignore(optional(whitespace()))
      |> concat(char())
    )
  end

  @doc false
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

  @doc false
  def reduce_range([[bracketed]]) when is_list(bracketed),
    do: {:in, Enum.map(bracketed, &{&1, &1})}

  def reduce_range([[from]]) when is_integer(from), do: {:in, [{from, from}]}

  def reduce_range([[from], [to]]) when is_integer(from) and is_integer(to),
    do: {:in, [{from, to}]}

  def reduce_range([from]), do: {:in, [{from, from}]}
  def reduce_range([from, to]), do: {:in, [{from, to}]}

  @doc false
  def check_valid_range(rest, [in: [{from, to}]] = args, context, _, _)
      when is_integer(from) and is_integer(to) do
    if from > to do
      {:error, "Character range starts at #{from} which is after its end #{to}"}
    else
      {rest, args, context}
    end
  end

  def check_valid_range(rest, [in: [{from, from}]] = args, context, _, _) do
    {rest, args, context}
  end

  def check_valid_range(rest, [in: [{from, to}]] = args, context, _, _)
      when is_list(from) and is_list(to) do
    cond do
      length(from) == 1 or length(to) == 1 ->
        {:error,
         "String ranges must be longer than one character. Found " <>
           format_string_range(from, to)}

      length(from) != length(to) ->
        {:error,
         "String range endpoints must be the same length. Found " <>
           format_string_range(from, to)}

      true ->
        {rest, args, context}
    end
  end

  @doc false
  def property do
    choice([
      perl_property(),
      posix_property()
    ])
    |> post_traverse(:reduce_property)
    |> label("property")
  end

  @doc false
  def posix_property do
    ignore(string("[:"))
    |> optional(ascii_char([?^]) |> replace(:not))
    |> property_expression([{:not, ?:}])
    |> ignore(string(":]"))
    |> label("posix property")
  end

  @doc false
  def perl_property do
    ignore(ascii_char([?\\]))
    |> choice([ascii_char([?P]) |> replace(:not), ignore(ascii_char([?p]))])
    |> ignore(ascii_char([?{]))
    |> property_expression([{:not, ?}}])
    |> ignore(ascii_char([?}]))
    |> label("perl property")
  end

  @doc false
  def operator do
    choice([
      utf8_char([0x2260]) |> replace(:not_in),
      ascii_char([?=]) |> replace(:in)
    ])
  end

  @doc false
  def property_expression(combinator \\ empty(), fence) do
    combinator
    |> choice([
      block_prefix()
      |> ignore(optional(whitespace()))
      |> concat(value(fence)),
      property_name()
      |> optional(operator() |> ignore(optional(whitespace())) |> concat(value(fence)))
    ])
  end

  @doc false
  # `\p{Is<name>}` / `[:Is<name>:]`: per UTS#18 / Java semantics, resolve the
  # name as a script, general category or binary property FIRST, and only fall
  # back to a block when it is none of those. This lets `\p{IsAlphabetic}`,
  # `\p{IsLatin}` and `[:IsLowercase:]` resolve to the property/script while
  # `\p{IsBasicLatin}` (not a script/category/property) still resolves as a block.
  def reduce_property(rest, [value, "is_prefix"], context, _line, _offset) do
    tracer(0, [value, :is_prefix])

    case fetch_script_category_or_block(value) do
      %{parsed: [{:not_in, parsed}]} -> {rest, [{:not_in, parsed}], context}
      %{parsed: [{:in, parsed}]} -> {rest, [{:in, parsed}], context}
      %{parsed: parsed} -> {rest, parsed, context}
      ranges -> {rest, [{:in, ranges}], context}
    end
  end

  def reduce_property(rest, [value, "is_prefix", :not], context, _line, _offset) do
    tracer(0, [value, :is_prefix, :not])

    case fetch_script_category_or_block(value) do
      %{parsed: [{:not_in, parsed}]} -> {rest, [{:in, parsed}], context}
      %{parsed: [{:in, parsed}]} -> {rest, [{:not_in, parsed}], context}
      %{parsed: parsed} -> {rest, [{:not_in, parsed}], context}
      ranges -> {rest, [{:not_in, ranges}], context}
    end
  end

  def reduce_property(rest, [value, "block" = property], context, _line, _offset) do
    tracer(0, [value, :in, property])

    case fetch_property!(property, value) do
      %{parsed: parsed} -> {rest, [{:in, parsed}], context}
      ranges -> {rest, [{:in, ranges}], context}
    end
  end

  def reduce_property(rest, [value, "block" = property, :not], context, _line, _offset) do
    tracer(1, [value, :in, property, :not])

    case fetch_property!(property, value) do
      %{parsed: parsed} -> {rest, [{:not_in, parsed}], context}
      ranges -> {rest, [{:not_in, ranges}], context}
    end
  end

  def reduce_property(rest, [value, :in, property, :not], context, _line, _offset) do
    tracer(2, [value, :in, property, :not])

    case fetch_property!(property, value) do
      %{parsed: parsed} -> {rest, [{:not_in, parsed}], context}
      ranges -> {rest, [{:not_in, ranges}], context}
    end
  end

  def reduce_property(rest, [value, :not_in, property, :not], context, _line, _offset) do
    tracer(3, [value, :not_in, property, :not])

    case fetch_property!(property, value) do
      %{parsed: parsed} -> {rest, parsed, context}
      ranges -> {rest, [{:in, ranges}], context}
    end
  end

  def reduce_property(rest, [value, operator, property], context, _line, _offset)
      when operator in [:in, :not_in] do
    tracer(4, [value, operator, property])

    case fetch_property!(property, value) do
      %{parsed: parsed} -> {rest, [{operator, parsed}], context}
      ranges -> {rest, [{operator, ranges}], context}
    end
  end

  def reduce_property(rest, [value, :not], context, _line, _offset) do
    tracer(5, [value, :not])

    case fetch_script_category_or_in_block(value) do
      %{parsed: [{:not_in, parsed}]} -> {rest, [{:in, parsed}], context}
      %{parsed: [{:in, parsed}]} -> {rest, [{:not_in, parsed}], context}
      %{parsed: parsed} -> {rest, [{:not_in, parsed}], context}
      ranges -> {rest, [{:not_in, ranges}], context}
    end
  end

  def reduce_property(rest, [value], context, _line, _offset) do
    tracer(6, [value])

    case fetch_script_category_or_in_block(value) do
      %{parsed: [{:not_in, parsed}]} -> {rest, [{:not_in, parsed}], context}
      %{parsed: [{:in, parsed}]} -> {rest, [{:in, parsed}], context}
      %{parsed: parsed} -> {rest, parsed, context}
      ranges -> {rest, [{:in, ranges}], context}
    end
  end

  @doc false
  def block_prefix do
    choice([
      string("is") |> replace("is_prefix"),
      string("Is") |> replace("is_prefix"),
      string("iS") |> replace("is_prefix"),
      string("IS") |> replace("is_prefix")
    ])
    |> label("property name")
  end

  @doc false
  @alphanumeric [?a..?z, ?A..?Z, ?0..?9]
  def property_name do
    ascii_char(@alphanumeric)
    |> repeat(ascii_char(@alphanumeric ++ [?_, ?\s, ?-]))
    |> ignore(optional(whitespace()))
    |> reduce(:to_lower_string)
    |> label("property name")
  end

  @doc false
  def value(gate) do
    times(
      choice([
        ignore(ascii_char([?\\])) |> concat(quoted()),
        ascii_char(gate)
      ]),
      min: 1
    )
    |> reduce(:to_lower_string)
  end

  @doc false
  def to_lower_string(args) do
    args
    |> List.to_string()
    |> String.replace(" ", "_")
    |> String.downcase()
  end

  @doc false
  @whitespace_chars [0x20, 0x9..0xD, 0x85, 0x200E, 0x200F, 0x2028, 0x2029]
  def whitespace_char do
    ascii_char(@whitespace_chars)
  end

  @doc false
  def whitespace do
    times(whitespace_char(), min: 1)
  end

  @doc false
  def string do
    ignore(ascii_char([?{]))
    # `min: 0` so the empty-string member `{}` is accepted (ICU 69+); it reduces
    # to the empty charlist string member `{~c"", ~c""}`.
    |> times(ignore(optional(whitespace())) |> concat(char()), min: 0)
    |> ignore(optional(whitespace()))
    |> ignore(ascii_char([?}]))
  end

  @doc false
  # ++ @whitespace_chars
  @syntax_chars [?&, ?-, ?[, ?], ?\\, ?{, ?}]
  @not_syntax_chars Enum.map(@syntax_chars, fn c -> {:not, c} end)
  def char do
    choice([
      ignore(ascii_char([?\\])) |> concat(quoted()),
      utf8_char(@not_syntax_chars)
    ])
  end

  @doc false
  # Each backslash escape resolves to a single codepoint. The form is
  # disambiguated by the grammar (not after the fact) so that, for example,
  # `\f` (FORM FEED) and `\xf` (U+000F) do not collide:
  #
  #   \uHHHH        exactly 4 hex digits
  #   \u{H...}      1-6 hex digits, braced (multiple space-separated is rejected)
  #   \UHHHHHHHH    exactly 8 hex digits
  #   \xH / \xHH    1-2 hex digits
  #   \x{H...}      braced, as for \u{...}
  #   \a \b \e \f \n \r \t \v   named control escapes
  #   \N{NAME}      named codepoint (resolved via `unicode ~> 2.0`)
  #   \<other>      the character itself (e.g. `\-` -> `-`, `\g` -> `g`)
  def quoted do
    choice([
      ignore(ascii_char([?u])) |> concat(bracketed_hex()),
      ignore(ascii_char([?u])) |> times(hex(), 4) |> reduce(:hex_digits_to_codepoint),
      ignore(ascii_char([?U])) |> times(hex(), 8) |> reduce(:hex_digits_to_codepoint),
      ignore(ascii_char([?x])) |> concat(bracketed_hex()),
      ignore(ascii_char([?x]))
      |> times(hex(), min: 1, max: 2)
      |> reduce(:hex_digits_to_codepoint),
      ignore(string("N{"))
      |> concat(property_name())
      |> ignore(ascii_char([?}]))
      |> post_traverse(:resolve_named_codepoint),
      # `\0ooo` octal escape: a leading 0 then up to three octal digits.
      ignore(ascii_char([?0]))
      |> times(ascii_char([?0..?7]), min: 0, max: 3)
      |> reduce(:octal_to_codepoint),
      # `\cX` control escape: Ctrl-<letter>, e.g. `\cH` -> U+0008.
      ignore(ascii_char([?c]))
      |> ascii_char([?a..?z, ?A..?Z])
      |> reduce(:control_char),
      ascii_char([?a, ?b, ?e, ?f, ?n, ?r, ?t, ?v]) |> reduce(:control_escape),
      utf8_char([0x0..0x10FFFF])
    ])
    |> label("quoted character")
  end

  @doc false
  def bracketed_hex do
    ignore(ascii_char([?{]))
    |> ignore(optional(whitespace()))
    |> concat(hex_codepoint())
    |> repeat(ignore(whitespace()) |> concat(hex_codepoint()))
    |> ignore(optional(whitespace()))
    |> ignore(ascii_char([?}]))
    |> reduce(:bracketed_hex_to_codepoint)
    |> label("bracketed hex")
  end

  @doc false
  def hex_codepoint do
    times(hex(), min: 1, max: 6)
    |> reduce(:hex_digits_to_codepoint)
    |> label("hex codepoint")
  end

  @doc false
  def hex do
    ascii_char([?a..?f, ?A..?F, ?0..?9])
    |> label("hex character")
  end

  @doc false
  def hex_digits_to_codepoint(hex_digits) do
    hex_digits
    |> List.to_string()
    |> String.to_integer(16)
  end

  @doc false
  def bracketed_hex_to_codepoint([codepoint]) when is_integer(codepoint) do
    codepoint
  end

  # Multiple space-separated codepoints (`\u{41 42 43}`) form a string member,
  # represented as a codepoint list that `reduce_range/1` turns into a string.
  def bracketed_hex_to_codepoint(codepoints) when is_list(codepoints) do
    codepoints
  end

  @doc false
  def octal_to_codepoint([]), do: 0
  def octal_to_codepoint(digits), do: digits |> List.to_string() |> String.to_integer(8)

  @doc false
  # `\cX` is Ctrl-<letter>: upper-case the letter and subtract 0x40, giving the
  # control code in 0x01..0x1A.
  def control_char([char]) do
    upper = if char in ?a..?z, do: char - 32, else: char
    upper - 0x40
  end

  @doc false
  def control_escape([?a]), do: ?\a
  def control_escape([?b]), do: ?\b
  def control_escape([?e]), do: ?\e
  def control_escape([?f]), do: ?\f
  def control_escape([?n]), do: ?\n
  def control_escape([?r]), do: ?\r
  def control_escape([?t]), do: ?\t
  def control_escape([?v]), do: ?\v

  @doc false
  # Resolve `\N{NAME}` to a codepoint via the `unicode` dependency's character
  # name table. That table is only available in `unicode ~> 2.0`; on earlier
  # versions the escape is reported as unsupported rather than crashing.
  def resolve_named_codepoint(rest, [name], context, _line, _offset) do
    case named_codepoint(name) do
      {:ok, codepoint} ->
        {rest, [codepoint], context}

      :error ->
        {:error, "the codepoint name #{inspect(name)} is not known"}
    end
  end

  defp named_codepoint(name) do
    # `apply/3` on a module bound to a variable keeps the compiler from
    # statically resolving `Unicode.CharacterName.to_codepoint/1`, which is
    # absent when built against `unicode ~> 1.21`.
    module = Unicode.CharacterName

    if Code.ensure_loaded?(module) and function_exported?(module, :to_codepoint, 1) do
      apply(module, :to_codepoint, [name])
    else
      :error
    end
  end

  @doc false
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

  @doc false
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

  @doc false
  def iteration([from, to]) do
    {:repeat, min: from, max: to}
  end

  @doc false
  def anchor do
    ignore(optional(whitespace())) |> ascii_char([?$]) |> replace(:end)
  end

  #  Helpers
  #  -------

  defp format_string_range(from, to) do
    "{#{List.to_string(from)}}-{#{List.to_string(to)}}"
  end
end
