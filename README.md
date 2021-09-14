# Unicode Set

![Build Status](https://api.cirrus-ci.com/github/elixir-unicode/unicode_set.svg)
[![Hex.pm](https://img.shields.io/hexpm/v/unicode_set.svg)](https://hex.pm/packages/ex_unicode_set)
[![Hex.pm](https://img.shields.io/hexpm/dw/unicode_set.svg?)](https://hex.pm/packages/ex_unicode_set)
[![Hex.pm](https://img.shields.io/hexpm/l/unicode_set.svg)](https://hex.pm/packages/ex_unicode_set)

A [Unicode Set](http://userguide.icu-project.org/strings/unicodeset) is a representation of a set of Unicode characters or character strings. The contents of that set are specified by patterns or by building them programmatically. This library implements parsing of unicode sets, resolving them to a list of codepoints and matching a given codepoint to that list.  This expansion supports the following public API:

* `Unicode.Set.match?/2` which is a macro that matches a codepoint to a unicode set.
* `Unicode.Regex.compile/2` which pre-processes a regex string expanding unicode sets into a regex executable by the `Regex` module.
* `Unicode.Set.to_utf8_char/1` that converts a unicode set into a form usable with [nimble_parsec](https://hex.pm/packages/nimble_parsec)
* `Unicode.Set.compile_pattern/1` which converts a unicode set into a string that is then compiled with `:binary.compile_pattern/1`.

The implementation conforms closely to the [Unicode Set specification](http://unicode.org/reports/tr35/#Unicode_Sets) but currently omits support for the `\N{codepoint_name}` syntax.

<!-- MDOC -->

## Usage

### Function guards

This is helpful in defining [function guards](https://hexdocs.pm/elixir/guards.html). For example:
```elixir
defmodule Guards do
  require Unicode.Set

  # Define a guard that checks if a codepoint is a unicode digit
  defguard digit?(x) when Unicode.Set.match?(x, "[[:Nd:]]")
end

defmodule MyModule do
  require Guards

  # Define a function using the previously defined guard
  def my_function(<< x :: utf8, _rest :: binary>>) when Guards.digit?(x) do
    IO.puts "Its a digit!"
  end

  # Define a guard directly on the function
  def my_other_function_(<< x :: utf8, _rest :: binary>>) when Unicode.Set.match?(x, "[[:Nd:]]") do
    IO.puts "Its also a digit!"
  end
end
```

### Generating compiled patterns for String matching

`String.split/3` and `String.replace/3` allow for patterns and [compiled patterns](http://erlang.org/doc/man/binary.html#compile_pattern-1) to be used with compiled patterns being the more performant approach.  Unicode Set supports the generation of patterns and compiled patterns:
```
iex> pattern = Unicode.Set.compile_pattern "[[:digit:]]"
iex> list = String.split("abc1def2ghi3jkl", pattern)
["abc", "def", "ghi", "jkl"]
```

### Generating NimbleParsec ranges

The parser generator [nimble_parsec](https://hex.pm/packages/nimble_parsec) allows a list of codepoint ranges as parameters to several combinators. Unicode Set can generate such ranges:
```
iex> Unicode.Set.utf8_char("[[^abcd][mnb]]")
[{:not, 97}, {:not, 98}, {:not, 99}, {:not, 100}, 98, 109, 110]
```
This can be used as shown in the following example:
```
defmodule MyCombinators do
  import NimbleParsec

  @digit_list = Unicode.Set.to_utf8_char("[[:digit:]]")
  def unicode_digit do
    utf8_char(@digit_list)
    |> label("a digit in any Unicode script")
  end
end
```

### Compiling extended regular expressions

The `Regex` module supports a limited set of Unicode Sets. The `Unicode.Regex` module provides `compile/2` and `compile!/2` functions that have the same arguments and compatible functionality with `Regexp.compile/2` other that they pre-process the regular expression, expanding any Unicode Sets. This makes it simple to incorporate Unicode Sets in regular expressions.

All Unicode Sets are expanded, even those that are known to `Regex.compile/2` since the erlang `:re` module upon `Regex` is based does not always keep pace with Unicode releases.

For example:

```elixir
iex> Unicode.Regex.compile("\\p{Zs}")
{:ok, ~r/[\x{20}\x{A0}\x{1680}\x{2000}-\x{200A}\x{202F}\x{205F}\x{3000}]/u}

iex> Unicode.Regex.compile("[:graphic:]")
{:ok,
 ~r/[\x{20}-\x{7E}\x{A0}-\x{AC}\x{AE}-\x{377}\x{37A}-\x{37F}...]/u}
```

### Other Examples

These examples show how to combine sets (union, difference and intersection) to deliver a flexible targeting of the required match.

```elixir
# The character "๓" is the thai digit `1`
iex> Unicode.Set.match? ?๓, "[[:digit:]]"
true

# Set operations allow union, insersection and difference
# This example matches on digits, but not the Thai script
iex> Unicode.Set.match? ?๓, "[[:digit:]-[:thai:]]"
false
```

### Compile time parsing

As much work as possible is done at compile time in order to deliver good performance. The macro `Unicode.Set.match?/2` parses the unicode set, expands the require codepoints and generates guard clauses at compile time. The resulting code is a simple set of boolean operators that executes quickly at runtime.

## Supported Unicode properties

This version of `Unicode Set` supports the following enumerable unicode properties in unicode sets:

* `script` such as `[:script=arabic:]`, `\p{script=arabic}` or `[:arabic:]`
* `block` such as `[:block=sudanese:]`, `\p{block=sudanese}`, `\p{IsSudanese}` or `[:IsSudanese:]`
* `general category` such as `[:Lu:]`, `\p{Lu}`, `[:gc=Lu:]` or `[:general category=Lu:]`
* `combining class` such as `[:ccc=230:]`

In addition, the following boolean properties are supported. These are expressed as `[:white space:]` or `\p{White Space}`.


Property   | Property | Property | Property
---------- | -------- | -------- | ----------
alphabetic | ascii_hex_digit | bidi_control | cased
 changes_when_casemapped | changes_when_lowercased |  changes_when_titlecased | changes_when_uppercased
dash | default_ignorable_code_point |  deprecated |  diacritic
extender | grapheme_base |  grapheme_extend |  grapheme_link
hex_digit | hyphen |  id_continue |  id_start
ideographic | ids_binary_operator |  ids_trinary_operator |  join_control
logical_order_exception | lowercase |  math |  noncharacter_code_point
other_alphabetic | other_default_ignorable_code_point |  other_grapheme_extend |  other_id_continue
other_id_start |  other_lowercase | other_math |  other_uppercase
pattern_syntax |  pattern_white_space | prepended_concatenation_mark |  quotation_mark
radical |  regional_indicator | sentence_terminal |  soft_dotted
terminal_punctuation |  unified_ideograph | uppercase |  variation_selector
white_space |  xid_continue | xid_start | changes_when_casefolded

In all cases, property names and property values may include whitespace and mixed case notation.

### General Categories

Abbreviation	      | Long Form
------------------- | --------------------------------------
L  |	Letter
Lu |	Uppercase Letter
Ll |	Lowercase Letter
Lt |	Titlecase Letter
Lm |	Modifier Letter
Lo |	Other Letter
M  |	Mark
Mn |	Non-Spacing Mark
Mc |	Spacing Combining Mark
Me |	Enclosing Mark
N  |	Number
Nd |	Decimal Digit Number
Nl |	Letter Number
No |	Other Number
S  |	Symbol
Sm |	Math Symbol
Sc |	Currency Symbol
Sk |	Modifier Symbol
So |	Other Symbol
P  |	Punctuation
Pc |	Connector Punctuation
Pd |	Dash Punctuation
Ps |	Open Punctuation
Pe |	Close Punctuation
Pi |	Initial Punctuation
Pf |	Final Punctuation
Po |	Other Punctuation
Z  |	Separator
Zs |	Space Separator
Zl |	Line Separator
Zp |	Paragraph Separator
C  |	Other
Cc |	Control
Cf |	Format
Cs |	Surrogate
Co |	Private Use
Cn |	Unassigned

Derived Categories	| Long Form
------------------- | --------------------------------------
Any                 | Any	all code points	[\u{0}-\u{10FFFF}]
Assigned            | Assigned	all assigned characters meaning	`\P{Cn}`
ASCII               | ASCII	all ASCII characters	[\u{0}-\u{7F}]

### Compatibility Property Names

Property  | Unicode Category           | Comments
--------- | -------------------------- | -----------
alpha	    | `\p{Alphabetic}`           | Alphabetic includes more than gc = Letter. Note that combining marks (Me, Mn, Mc) are required for words of many languages. While they could be applied to non-alphabetics, their principal use is on alphabetics. Alphabetic should not be used as an approximation for word boundaries: see `word` below.
lower	    | `\p{Lowercase}`	             | Lowercase includes more than gc = Lowercase_Letter (Ll).
upper	    | `\p{Uppercase}`	             | Uppercase includes more than gc = Uppercase_Letter (Lu).
punct	    | `\p{gc=Punctuation} \p{gc=Symbol} - \p{alpha}` | Punctuation and symbols.
digit     |	`\p{gc=Decimal_Number}`	     | [0..9]	Non-decimal numbers (like Roman numerals) are normally excluded.
xdigit    | `\p{gc=Decimal_Number} \p{Hex_Digit}`	| [0-9 A-F a-f]	Hex_Digit contains 0-9 A-F, fullwidth and halfwidth, upper and lowercase.
alnum     |	`\p{alpha} \p{digit}`	       | Simple combination of other properties
space     |	`\p{Whitespace}`	|
blank	    | `\p{gc=Space_Separator} \N{CHARACTER TABULATION}`	| "horizontal" whitespace: space separators plus U+0009 tab.
cntrl	    | `\p{gc=Control} `            | The characters in \p{gc=Format} share some, but not all aspects of control characters. Many format characters are required in the representation of plain text.
graph	    | `[^\p{space} \p{gc=Control} \p{gc=Surrogate} \p{gc=Unassigned}]`	| Warning: the set shown here is defined by excluding space, controls, and so on with ^.
print	    | `\p{graph} \p{blank} -- \p{cntrl}`	| Includes graph and space-like characters.
word      | `\p{alpha} \p{gc=Mark} \p{digit} \p{gc=Connector_Punctuation} \p{Join_Control}`	|	This is only an approximation to Word Boundaries. The Connector Punctuation is added in for programming language identifiers, thus adding `_` and similar characters.

## Additional Derived properties

In addition to the Unicode properties, some additional properties are also defined for convenience. These properties related to quote marks and are:

* `quote_mark`
* `quote_mark_left`
* `quote_mark_right`
* `quote_mark_ambidextrous`
* `quote_mark_single`
* `quote_mark_double`

As above these properties can be expressed in mixed case with spaces and underscores inserted for readability.  They can be used in the same way as any Unicode property name.

## Example Unicode Sets

Here are a few examples of sets. Although elements of the syntax appear similar to regular expressions, unicode sets only expresses one or more ranges of unicode codepoints.

Pattern	              | Description
--------------------- | -----------------------------------------------------------
`[a-z]`               | The lower case letters `a` through `z`
`[abc123]`            | The six characters `a,b,c,1,2` and `3`
`[\p{Letter}]`        | All characters with the Unicode General Category of Letter

### String Values

In addition to being a set of characters (of Unicode code points), a UnicodeSet may also contain string values. Conceptually, the UnicodeSet is always a set of strings, not a set of characters, although in many common use cases the strings are all of length one, which reduces to being a set of characters.

This concept can be confusing when first encountered, probably because similar set constructs from other environments (regular expressions) can only contain characters.

## Unicode Set Patterns

Patterns are a series of characters bounded by square brackets that contain lists of characters and Unicode property sets. Lists are a sequence of characters that may have ranges indicated by a '-' between two characters, as in "a-z". The sequence specifies the range of all characters from the left to the right, in Unicode order. For example, `[a c d-f m]` is equivalent to `[a c d e f m]`. Whitespace can be freely used for clarity as `[a c d-f m]` means the same as `[acd-fm]`.

Unicode property sets are specified by a Unicode property, such as [:Letter:]. For a list of supported properties, see the [Properties](#supported-unicode-properties) section. For details on the use of short vs. long property and property value names, see the end of this section. The syntax for specifying the property names is an extension of either POSIX or Perl syntax with the addition of `=value`. For example, you can match letters by using the POSIX syntax `[:Letter:]`, or by using the Perl-style syntax `\p{Letter}`. The type can be omitted for the `Category` and `Script` properties, but is required for other properties.

The table below shows the two kinds of syntax: POSIX and Perl style. Also, the table shows the "Negative", which is a property that excludes all characters of a given kind. For example, `[:^Letter:]` matches all characters that are not `[:Letter:]`.

Style              | Positive	        | Negative
------------------ | ---------------- | ----------------
POSIX-style Syntax | [:type=value:]   |	[:^type=value:]
Perl-style Syntax  |	\p{type=value}	| \P{type=value}

These following low-level lists or properties then can be freely combined with the normal set operations (union, inverse, difference, and intersection):

Example	                       | Meaning
------------------------------ | -----------------------------------------------------------
`A B	[[:letter:] [:number:]]` | To union two sets A and B, simply concatenate them
`A & B	[[:letter:] & [a-z]]`  | To intersect two sets A and B, use the '&' operator.
`A - B	[[:letter:] - [a-z]]`	 | To take the set-difference of two sets A and B, use the '-' operator.
`[^A]	[^a-z]`	                 | To invert a set A, place a `^` immediately after the opening `[`. Note that the complement only affects code points, not string values. In any other location, the `^` does not have a special meaning.

## Precedence

The binary operators of union, intersection, and set-difference have equal precedence and bind left-to-right. Thus the following are equivalent:

* `[[:letter:] - [a-z] [:number:] & [\u0100-\u01FF]]`
* `[[[[[:letter:] - [a-z]] [:number:]] & [\u0100-\u01FF]]`

Another example is that the set `[[ace][bdf] - [abc][def]]` is not the empty set, but instead the set `[def]`. That is because the syntax corresponds to the following UnicodeSet operations:

1. start with `[ace]`
2. union `[bdf]`  -- we now have `[abcdef]`
3. subtract `[abc]` -- we now have `[def]`
4. union `[def]` -- no effect, we still have `[def]`

This only really matters where there are the difference and intersection operations, as the union operation is commutative. To make sure that the - is the main operator, add brackets to group the operations as desired, such as `[[ace][bdf] - [[abc][def]]]`.

Another caveat with the `&` and `-` operators is that they operate between sets. That is, they must be immediately preceded and immediately followed by a set. For example, the pattern `[[:Lu:]-A]` is illegal, since it is interpreted as the set [:Lu:] followed by the incomplete range -A. To specify the set of uppercase letters except for `A`, enclose the `A` in a set: `[[:Lu:]-[A]]`.

## Examples

* `[a]`	The set containing 'a'
* `[a-z]`	The set containing 'a' through 'z' and all letters in between, in Unicode order
* `[^a-z]`	The set containing all characters but 'a' through 'z', that is, U+0000 through 'a'-1 and 'z'+1 through U+FFFF
* `[[pat1][pat2]]`	The union of sets specified by pat1 and pat2
* `[[pat1]&[pat2]]`	The intersection of sets specified by pat1 and pat2
* `[[pat1]-[pat2]]`	The asymmetric difference of sets specified by pat1 and pat2
* `[:Lu:]`	The set of characters belonging to the given Unicode category; in this case, Unicode uppercase letters. The long form for this is `[:UppercaseLetter:]`.
* `[:L:]`	The set of characters belonging to all Unicode categories starting with 'L', that is, `[[:Lu:][:Ll:][:Lt:][:Lm:][:Lo:]]`. The long form for this is `[:Letter:]`.

## String Values in Sets

String values are enclosed in `{`curly brackets`}`.

Set expression	    | Description
------------------- | --------------------------------------
`[abc{def}]`	      | A set containing four members, the single characters a, b and c, and the string “def”
`[{abc}{def}]`      |	A set containing two members, the string “abc” and the string “def”.
`[{a}{b}{c}][abc]`	| These two sets are equivalent. Each contains three items, the three individual characters `a`, `b` and `c`. A `{string}` containing a single character is equivalent to that same character specified in any other way.

## Character Quoting and Escaping in Unicode Set Patterns

### Single Quote

Two single quotes represents a single quote, either inside or outside single quotes.

Text within single quotes is not interpreted in any way (except for two adjacent single quotes). It is taken as literal text (special characters become non-special).

These quoting conventions for ICU UnicodeSets differ from those of regular expression character set expressions. In regular expressions, single quotes have no special meaning and are treated like any other literal character.

### Backslash Escapes

Outside of single quotes, certain backslashed characters have special meaning. Note that these are escapes processed by Unicode Set (this library) and therefore require `\\\\` to be entered as a prefix. [Elixir also provides similar escapes](https://elixir-lang.org/getting-started/sigils.html#interpolation-and-escaping-in-sigils) as native part of its string processing and Elixir's escapes are to be preferred where possible.

Escape         | Description
-------------- | -------------------------------------------------
\uhhhh	       | Exactly 4 hex digits; h in [0-9A-Fa-f]
\Uhhhhhhhh	   | Exactly 8 hex digits
\xhh	         | 1-2 hex digits

Certain other escapes are native to Elixir and are applicable in Unicode Sets they are in any Elixir string:

Escape         | Description
-------------- | -------------------------------------------------
\a	           | U+0007 (BELL)
\b	           | U+0008 (BACKSPACE)
\t	           | U+0009 (HORIZONTAL TAB)
\n	           | U+000A (LINE FEED)
\v	           | U+000B (VERTICAL TAB)
\f	           | U+000C (FORM FEED)
\r	           | U+000D (CARRIAGE RETURN)
\\	           | U+005C (BACKSLASH)
\xDD           | represents a single byte in hexadecimal (such as `\x13`)
\uDDDD and \u{D...} | represents a Unicode codepoint in hexadecimal (such as `\u{1F600}`)

Anything else following a backslash is mapped to itself, except in an environment where it is defined to have some special meaning. For example, `\p{Lu}` is the set of uppercase letters in a Unicode Set.

Any character formed as the result of a backslash escape loses any special meaning and is treated as a literal. In particular, note that `\u` and `\U` escapes create literal characters.

### Whitespace

Whitespace (as defined by the specification) is ignored unless it is quoted or backslashed.

## Property Values

The following property value variants are recognized:

Format	  | Example                           | Description
--------- | --------------------------------- | ----------------------------------------------
short	    | Lu                                | omits the type (used to prevent ambiguity and only allowed with the Category and Script properties)
medium	  | gc=Lu                             | uses an abbreviated type and value
long	    | General_Category=Uppercase_Letter | uses a full type and value

If the type or value is omitted, then the equals sign is also omitted. The short style is only
used for Category and Script properties because these properties are very common and their omission is unambiguous.

In actual practice, you can mix type names and values that are omitted, abbreviated, or full. For example, if Category=Unassigned you could use what is in the table explicitly, `\p{gc=Unassigned}`, `\p{Category=Cn}`, or `\p{Unassigned}`.

When these are processed, case and whitespace are ignored so you may use them for clarity, if desired. For example, `\p{Category = Uppercase Letter}` or `\p{Category = uppercase letter}`.

<!-- MDOC -->

## Installation

To install, add the package `unicode_set` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:unicode_set, "~> 1.0"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/unicode_set](https://hexdocs.pm/unicode_set).

