# User guide

`unicode_set` parses [Unicode Set](https://www.unicode.org/reports/tr61/) expressions such as `[[:Lu:]&[:Latn:]]` and turns them into things Elixir can use directly: function guards, compiled binary patterns for `String.split/3`, code point lists for `nimble_parsec`, and character classes for regular expressions. This guide walks through the expression syntax and each of those uses.

Every function returns `{:ok, result}` or `{:error, {exception, reason}}`. Each has a `!` variant that returns the bare result or raises `Unicode.Set.ParseError`.

## Installation

Add `unicode_set` to your dependencies:

```elixir
def deps do
  [
    {:unicode_set, "~> 1.9"}
  ]
end
```

The library depends on [`unicode`](https://hex.pm/packages/unicode), which carries the Unicode Character Database. Both follow the current Unicode release, 18.0 at the time of writing.

## Writing a Unicode Set

A Unicode Set is a set of code points and, optionally, of strings. It is written between square brackets.

### Characters and ranges

```elixir
iex> Unicode.Set.parse_and_reduce!("[abc]").parsed
{:in, [{97, 99}]}

iex> Unicode.Set.parse_and_reduce!("[a-z]").parsed
{:in, [{97, 122}]}

iex> Unicode.Set.parse_and_reduce!("[a-zA-Z0-9_]").parsed
{:in, [{48, 57}, {65, 90}, {95, 95}, {97, 122}]}
```

The `:parsed` field holds the evaluated set as a sorted list of `{first, last}` code point ranges. Juxtaposed elements are unioned.

Any character can be written literally except the set-syntax characters `[ ] { } & - ^ \ $`, which must be escaped with a backslash:

```elixir
iex> Unicode.Set.parse_and_reduce!("[\\[\\]\\-]").parsed
{:in, [{45, 45}, {91, 91}, {93, 93}]}
```

A hyphen at the start or end of a set is a literal hyphen, so `[-a]`, `[a-]` and `[-]` all contain U+002D. `[]` is the empty set.

### Escapes

All the usual escapes are available, and any other backslashed character is itself:

| Escape | Meaning |
| --- | --- |
| `\uHHHH` | four hex digits |
| `\UHHHHHHHH` | eight hex digits |
| `\xH`, `\xHH` | one or two hex digits |
| `\x{H…}`, `\u{H…}` | one to six hex digits in braces |
| `\ooo` | one to three octal digits |
| `\N{NAME}` | a character by name or name alias |
| `\a \b \e \f \n \r \t \v` | the C0 controls |
| `\cX` | Ctrl-`X`, for `X` in `@ A-Z [ \ ] ^ _` |

```elixir
iex> Unicode.Set.parse_and_reduce!("[\\u0041\\x{1F600}\\N{EURO SIGN}\\N{NULL}]").parsed
{:in, [{0, 0}, {65, 65}, {8364, 8364}, {128512, 128512}]}
```

Character names are matched loosely: case, spaces, hyphens and underscores are ignored, so `\N{latin_small_letter_a}` and `\N{LATIN SMALL LETTER A}` are the same character. Name aliases of every kind resolve, which is how `\N{NULL}`, `\N{LF}` and `\N{BYTE ORDER MARK}` work.

### Properties

The real power of a Unicode Set is naming characters by their Unicode properties. There are two spellings, POSIX-style `[:…:]` and Perl-style `\p{…}`, which mean the same thing:

```elixir
iex> Unicode.Set.parse_and_reduce!("[:Lu:]").parsed == Unicode.Set.parse_and_reduce!("\\p{Lu}").parsed
true
```

A bare name is a General_Category value, a Script value or a binary property:

```elixir
iex> {:in, ranges} = Unicode.Set.parse_and_reduce!("\\p{Lu}").parsed
iex> hd(ranges)
{65, 90}

iex> {:in, ranges} = Unicode.Set.parse_and_reduce!("\\p{Greek}").parsed
iex> hd(ranges)
{880, 883}

iex> {:in, ranges} = Unicode.Set.parse_and_reduce!("\\p{Emoji}").parsed
iex> hd(ranges)
{35, 35}
```

Any other property is written `property=value`, and `≠` (U+2260) selects everything else:

```elixir
iex> Unicode.Set.parse_and_reduce!("\\p{Block=Basic Latin}").parsed
{:in, [{0, 127}]}

iex> {:in, ranges} = Unicode.Set.parse_and_reduce!("\\p{Line_Break=OP}").parsed
iex> hd(ranges)
{40, 40}

iex> Unicode.Set.parse_and_reduce!("\\p{gc≠Cn}").parsed == Unicode.Set.parse_and_reduce!("\\P{Cn}").parsed
true
```

Property and value names are matched loosely too, so `\p{General Category=uppercase letter}`, `\p{gc=Lu}` and `\p{GC=LU}` are all the same query. The General_Category groupings `L`, `LC`, `M`, `N`, `P`, `S`, `Z` and `C` work, as do the POSIX names `alpha`, `digit`, `punct`, `space` and so on.

`\P{…}` and `[:^…:]` are the complement of the property, kept in `{:not_in, ranges}` form:

```elixir
iex> {:not_in, ranges} = Unicode.Set.parse_and_reduce!("\\P{L}").parsed
iex> hd(ranges)
{65, 90}
```

Three properties take special values. `Age` is cumulative, so `\p{Age=6.0}` is every character that existed in Unicode 6.0. `Numeric_Value` takes `NaN`, a fraction or a decimal:

```elixir
iex> Unicode.Set.parse_and_reduce!("\\p{nv=1/6}").parsed
{:in, [{8537, 8537}, {68087, 68087}, {74849, 74849}, {126269, 126269}]}
```

And `Name` and `Name_Alias` select a single character:

```elixir
iex> Unicode.Set.parse_and_reduce!("\\p{Name=EURO SIGN}").parsed
{:in, [{8364, 8364}]}
```

The README lists every supported property. The [UTS #61 conformance guide](tr61_conformance.md) records exactly how the syntax relates to the standard.

### Set operations

Sets combine by juxtaposition (union), `&` (intersection) and `-` (difference). The operators have equal precedence and bind left to right, so nest brackets to group:

```elixir
iex> Unicode.Set.parse_and_reduce!("[[a-z][A-Z]]").parsed
{:in, [{65, 90}, {97, 122}]}

iex> Unicode.Set.parse_and_reduce!("[[a-z]&[m-z]]").parsed
{:in, [{109, 122}]}

iex> Unicode.Set.parse_and_reduce!("[[a-z]-[aeiou]]").parsed
{:in, [{98, 100}, {102, 104}, {106, 110}, {112, 116}, {118, 122}]}

iex> Unicode.Set.parse_and_reduce!("[[a-z]-[c]&[d]]").parsed
{:in, [{100, 100}]}

iex> Unicode.Set.parse_and_reduce!("[[a-z]-[[c]&[d]]]").parsed
{:in, [{97, 122}]}
```

The right-hand side of `&` or `-` must be a bracketed set or a property query. The most common use is narrowing a property:

```elixir
iex> {:in, ranges} = Unicode.Set.parse_and_reduce!("[[:Lu:]&[:Greek:]]").parsed
iex> hd(ranges)
{880, 880}
```

### Complement

A leading `^` complements the set:

```elixir
iex> Unicode.Set.parse_and_reduce!("[^a-z]").parsed
{:not_in, [{97, 122}]}
```

A complement is kept in `{:not_in, ranges}` form wherever possible, because guards, regexes and `nimble_parsec` can all express "not these" directly. It is only expanded into positive ranges when an intersection or difference forces it.

### Strings

A set may also contain strings, written in braces. `{}` is the empty string.

```elixir
iex> Unicode.Set.parse_and_reduce!("[a{bc}{def}]").parsed
{:in, [{97, 97}, {~c"bc", ~c"bc"}, {~c"def", ~c"def"}]}
```

Inside braces every character other than `\` and `}` is literal, including spaces and the set-syntax characters. String members appear in the range list as `{charlist, charlist}` pairs, and are only supported by the functions that can match more than one code point: `to_pattern/1`, `compile_pattern/1`, `to_regex_string/1` and the non-guard form of `match?/2`.

### White space

White space between elements is ignored, so long expressions can be laid out for reading:

```elixir
iex> {:in, ranges} = Unicode.Set.parse_and_reduce!("[ [:L:] & [:Latn:] - [a-z] ]").parsed
iex> hd(ranges)
{65, 90}
```

## Parsing

`parse/1` parses an expression without evaluating its set operations; `parse_and_reduce/1` evaluates them and leaves the range list shown throughout this guide. Both return a `Unicode.Set` struct:

```elixir
iex> {:ok, set} = Unicode.Set.parse_and_reduce("[a-z]")
iex> set.set
"[a-z]"
iex> set.parsed
{:in, [{97, 122}]}
iex> set.state
:reduced
```

Invalid expressions return an error rather than raising:

```elixir
iex> {:error, {Unicode.Set.ParseError, message}} = Unicode.Set.parse("[:nonesuch:]")
iex> message
"Unable to parse \"[:nonesuch:]\". The unicode script, category or property \"nonesuch\" is not known."
```

The `~u` sigil parses at compile time:

```elixir
iex> import Unicode.Set.Sigil
iex> ~u"[[:Lu:]&[:thai:]]"
#Unicode.Set<[[:Lu:]&[:thai:]]>
```

## Function guards

`Unicode.Set.match?/2` is a macro. In a guard it expands, at compile time, into plain comparisons on the code point, so there is no runtime cost beyond a few integer tests:

```elixir
defmodule Guards do
  require Unicode.Set

  defguard is_digit(codepoint) when Unicode.Set.match?(codepoint, "[[:Nd:]]")
  defguard is_greek_letter(codepoint) when Unicode.Set.match?(codepoint, "[[:L:]&[:Greek:]]")
end

defmodule Classifier do
  require Guards

  def classify(<<codepoint::utf8, _::binary>>) when Guards.is_digit(codepoint), do: :digit
  def classify(<<codepoint::utf8, _::binary>>) when Guards.is_greek_letter(codepoint), do: :greek
  def classify(_), do: :other
end
```

The set must be a literal string, because it is parsed when the module compiles. Outside a guard, `match?/2` builds a search tree at compile time and consults it at runtime, and there it also accepts sets with string members:

```elixir
iex> require Unicode.Set
iex> Unicode.Set.match?(?๓, "[[:digit:]]")
true
iex> Unicode.Set.match?(?๓, "[[:digit:]-[:Thai:]]")
false
```

## Binary patterns

`to_pattern/1` returns the set as a list of strings, and `compile_pattern/1` compiles that list with `:binary.compile_pattern/1`. Both can be passed to `String.split/3`, `String.replace/3` and `String.contains?/2`, and the compiled form is the faster of the two:

```elixir
iex> Unicode.Set.to_pattern!("[0-9]")
["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]

iex> pattern = Unicode.Set.compile_pattern!("[[:Nd:]]")
iex> String.split("abc1def2ghi3jkl", pattern)
["abc", "def", "ghi", "jkl"]
```

A pattern enumerates every member of the set, so keep the set small; a complement or a very large class is better handled as a regex. `compile_pattern/1` returns an error for a complement, for the empty set and for a set whose only member is the empty string, since binary patterns cannot express those.

## NimbleParsec ranges

`to_utf8_char/1` returns the set in the form `NimbleParsec.utf8_char/1` and its siblings accept: integers, ranges and `{:not, …}` exclusions:

```elixir
iex> Unicode.Set.to_utf8_char!("[[^abcd][mnb]]")
[98, 109..110, {:not, 97..100}]
```

```elixir
defmodule Combinators do
  import NimbleParsec

  @digit Unicode.Set.to_utf8_char!("[[:Nd:]]")

  defparsec :digit, utf8_char(@digit) |> label("a digit in any script")
end
```

String members cannot be expressed as a code point list, so `to_utf8_char/1` raises `ArgumentError` for a set that contains them.

## Regular expressions

`to_regex_string/1` renders the set as a PCRE character class, with string members as an alternation in front of it:

```elixir
iex> Unicode.Set.to_regex_string!("[a-z{ch}]")
"(?:ch|[\\x{61}-\\x{7A}])"
```

More useful is `Unicode.Regex`, whose `compile/2`, `compile!/2` and `match?/3` take an ordinary regular expression, expand every Unicode Set in it, and hand the result to `Regex`. This gives regular expressions the full property syntax, including intersections and differences that PCRE cannot express, and it tracks the current Unicode release rather than the one the VM was built with:

```elixir
iex> {:ok, regex} = Unicode.Regex.compile("^[[:L:]&[:Greek:]]+$")
iex> Regex.match?(regex, "Ελληνικά")
true
iex> Regex.match?(regex, "Greek")
false

iex> Unicode.Regex.match?("[[:Sc:]]", "$")
true
```

A set in a regex must be written as a class, so `[[:Lu:]]` or `\p{Lu}`, and property names are resolved by this library rather than by PCRE.

## Errors

Every parsing function returns `{:error, {exception, reason}}` for an expression it cannot handle, where `exception` is the module to raise and `reason` is a message naming the problem and where it was detected:

```elixir
iex> Unicode.Set.parse("[z-a]")
{:error,
 {Unicode.Set.ParseError,
  "Unable to parse \"[z-a]\". Character range starts at 122 which is after its end 97. Detected at \"]\"."}}
```

The `!` variants raise `Unicode.Set.ParseError` with the same message. Because the sets inside `match?/2` and `~u` are parsed at compile time, an invalid set there is a compile error.

## Performance notes

* Everything that can be done at compile time is. `match?/2` in a guard, and `~u`, cost nothing at runtime beyond the generated comparisons.
* `parse_and_reduce/1` resolves property queries against the `unicode` library's tables, which are compiled into that library, so evaluation is fast but not free; cache the result rather than re-parsing in a loop.
* Prefer `compile_pattern/1` over `to_pattern/1` when the pattern is reused.
* A regex compiled by `Unicode.Regex.compile/2` is an ordinary `Regex` and can be stored in a module attribute.
