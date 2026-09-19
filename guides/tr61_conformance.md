# UTS #61 conformance

This guide records how `unicode_set` relates to [UTS #61, Unicode Set Notation](https://www.unicode.org/reports/tr61/), the draft Unicode Technical Standard that formalises the UnicodeSet syntax previously described only in [CLDR TR35](https://unicode.org/reports/tr35/#Unicode_Sets) and by the ICU implementation. It was written against revision 2 of the draft (2026-09-11) and is organised by the sections of that document.

UTS #61 defines two grades of conformance.

* An implementation is **consistent** if, for every valid UnicodeSet expression, it either rejects the expression or evaluates it exactly as the standard specifies. Rejecting is always allowed; evaluating to a different set is not. Where a consistent implementation accepts expressions that the standard calls ill-formed, those are **pure extensions**, which are permitted provided they are declared.
* An implementation is **syntactically complete** if it supports every production of the set-operation grammar (Section 3), whatever subset of lexical elements it chooses to accept.

`unicode_set` is syntactically complete. It is consistent for the set-operation grammar and for property queries, with the divergences declared in the [conformance statement](#section-4-conformance-statement) below. Everything the standard marks as *not recommended for general-purpose APIs* (version qualifiers, property comparisons, regular-expression queries) is rejected.

## Summary

| UTS #61 area | Status |
| --- | --- |
| §2 Lexical elements, white space | Conformant, except the ignorable-format-control rule |
| §2.1 Literal elements | Extended: `^`, `$`, `:` and `'` are given meanings the standard does not |
| §2.2 Escaped elements | Conformant, except octal without a leading `0` and `\c` with a non-letter |
| §2.3 Named elements | Conformant, all three forms |
| §2.4 Bracketed elements and strings | Conformant, except that white space inside `{...}` is ignored; extended with string ranges |
| §2.5 Property queries | Conformant for the recommended subset; unary block names and `Is`/`In` prefixes are extensions |
| §2.5.3.1 Age queries | Conformant (cumulative) |
| §2.5.3.4 Numeric values | Rejected |
| §2.5.3.2, §2.5.3.3, §2.5.3.6 | Rejected, as the standard recommends for APIs |
| §3 Set operations | Conformant; `[-]` and `[a-a]` diverge as declared |
| §4 Conformance | Consistent with declared divergences; syntactically complete |

## Section 2: Lexical elements

### White space

Pattern_White_Space (U+0009–U+000D, U+0020, U+0085, U+200E, U+200F, U+2028, U+2029) is ignored between lexical elements, so `[ A-Z ] - [C]` inside an outer set is the same as `[A-Z]-[C]`.

The standard adds that the two *ignorable format controls*, U+200E LEFT-TO-RIGHT MARK and U+200F RIGHT-TO-LEFT MARK, may not be the *only* separator between two elements whose juxtaposition would otherwise lex differently: `[\xD<LRM>F]` is ill-formed under the standard, because without the mark `\xDF` is one escape. This library ignores the marks like any other white space, so that expression is accepted and evaluates to `[\x0D F]`. This is a pure extension.

Leading and trailing white space around a whole expression is not accepted; `" \p{L}"` is an error.

### §2.1 Literal elements

Under the standard the only characters that are not literal are the set operators `& - [ ] ^`, the braces `{ }`, `$` and `\`, and Pattern_White_Space. This library gives two further characters a meaning, both inherited from CLDR TR35 and ICU.

* **Single quotes.** Text within `'...'` is literal and `''` is a literal quote. UTS #61 treats `'` as an ordinary literal, so `['a']` is the set `{', a}` under the standard but `{a}` here. An unterminated `'` is a literal quote. This is the one place where the library is not consistent with the standard on a *valid* expression; it is a deliberate TR35 tailoring.
* **`^` and `$` mid-set.** `[a^b]` and `[a$]` are ill-formed under the standard, since `^` is a set operator and `$` is reserved. This library treats both as literal characters when they cannot be an operator, as ICU does. Pure extension.
* **`:` after `[`.** The standard requires white space between `[` and a literal `:` so that `[:` is always a POSIX query start. `[::]` and `[:^:]` are ill-formed under the standard; this library accepts them as sets containing a literal colon. Pure extension. `[ :a]` is `{:, a}` in both.

### §2.2 Escaped elements

All of the standard's escapes are supported: `\xH`, `\xHH`, `\x{H...}`, `\uHHHH`, `\UHHHHHHHH`, `\N{...}`, the named controls `\a \b \e \f \n \r \t \v`, `\cX`, octal, and `\` before any other character, which is that character. Hexadecimal escapes that do not denote a code point, such as `\x{110000}`, are rejected as the standard requires.

Two divergences:

* **Octal without a leading `0`.** Under the standard `\7` is U+0007 and `\134` is U+005C. This library only recognises octal with a leading zero (`\0`, `\07`, `\0134`); `\7` and `\134` evaluate to the literal digits, as `\` before a non-special character. The standard does not allow a digit 0–7 to be an escapable character, so these expressions are ill-formed under the standard and this is a pure extension, but note that ICU evaluates them as octal.
* **`\c` with a non-letter.** The standard defines `\c` followed by any printable ASCII character (`\c'` is U+0007, `\c[` is U+001B) and makes `\c?` and `\c` followed by a non-ASCII character ill-formed. This library only recognises `\c` followed by an ASCII letter; any other `\c` sequence is the literal `c` followed by that character. Pure extension for the ill-formed cases; a divergence for the printable-ASCII cases, which are not currently supported.

Extensions beyond the standard, all from TR35 or ICU: `\u{H...}` as a synonym for `\x{H...}`, multiple space-separated code points inside `\x{...}` or `\u{...}` forming a string member, and adjacent escaped surrogates (`\uD83D\uDE00`) kept as two code points rather than requiring a separating space.

Escaped surrogate code points are accepted everywhere, including inside string members, where the standard makes them ill-formed. Pure extension.

### §2.3 Named elements

All three forms are supported and evaluate as specified.

| Expression | Result |
| --- | --- |
| `\N{SPACE}` | U+0020 |
| `\N{0020:SPACE}` | U+0020 |
| `\N{20: :SPACE}` | U+0020 |
| `\N{0A:LATIN CAPITAL LETTER A}` | ill-formed (code point does not match) |
| `\N{41:a:LATIN CAPITAL LETTER A}` | ill-formed (character does not match) |
| `\N{THIS IS NOT A CHARACTER}` | ill-formed |
| `\N{PRESENTATION FORM FOR VERTICAL RIGHT WHITE LENTICULAR BRAKCET}` | U+FE18, via its correction alias |
| `\N{Latin small ligature o-e}` | U+0153 (UAX44-LM2 loose matching) |

A named element is an `Element`, so it may be a range endpoint and `[\N{LATIN SMALL LETTER A}-\N{LATIN SMALL LETTER Z}]` is the 26 letters, as the standard's grammar requires. An unbracketed `\N{SPACE}` is not a set, and `[\p{L}-\N{SPACE}]` is ill-formed because the right-hand side of a difference must be a set; both are rejected.

Names are resolved through the character-name table in the `unicode` library, which includes algorithmically-named characters (CJK and Tangut ideographs, Hangul syllables, Seal and Jurchen). Control-character names that exist only as formal aliases, such as `\N{NULL}`, are not currently resolvable.

### §2.4 Bracketed elements and strings

`{}` is the empty string, `{a}` is the single code point `a`, and `{ab}` is a string member. Escapes and named elements are honoured inside braces.

Divergences and extensions:

* **White space inside braces.** Under the standard every character other than `\` and `}` is literal inside braces, so `{a b}` is the three-code-point string `"a b"`. This library ignores Pattern_White_Space inside braces, so `{a b}` is `"ab"`. This is a divergence on a valid expression.
* **Bracketed range endpoints.** The standard allows a single-code-point bracketed element as a range endpoint, so `[{a}-z]` and `[a-{z}]` are both `[a-z]`. This library accepts `[{a}-{z}]` but rejects the mixed forms. Consistent (rejection), but a gap.
* **String ranges.** `[{ab}-{cd}]` is a TR35 string range, which the standard removed. This library supports it as an extension; the endpoints must have the same length.

### §2.5 Property queries

Both the Perl form `\p{...}` / `\P{...}` and the POSIX form `[:...:]` / `[:^...:]` are supported, with `=` and `≠` (U+2260) as query operators. Negation follows §2.5.1 exactly: `\P{gc=Cn}`, `[:^gc=Cn:]` and `\p{gc≠Cn}` are the code-point complement of `\p{gc=Cn}`, and a doubly negated query such as `[:^gc≠Cn:]` is the same set as `\p{gc=Cn}`.

Property and value names are matched under UAX44-LM3: case, white space, `_` and `-` are ignored, so `\p{General Category=uppercase letter}` and `\p{GC=Lu}` are the same query. Leading white space immediately inside the braces (`\p{ gc=Cn }`) is not accepted, although the standard allows it; `\p{gc = Cn}` is fine.

#### Unary queries (§2.5.2)

A unary query names a binary property, a Script value, or a General_Category value (including the groupings `L`, `LC`, `M`, `N`, `P`, `S`, `Z`, `C`), exactly as the standard specifies. Three ICU-compatible extensions are accepted where the standard would report an ill-formed expression:

* `Is` prefix: `\p{IsLatin}`, `\p{IsAlphabetic}` resolve the remainder as a script, category or binary property, and then as a block (`\p{IsBasicLatin}`).
* `In` prefix: `\p{InBasicLatin}` resolves the remainder as a block.
* The POSIX compatibility names `alpha`, `alnum`, `blank`, `cntrl`, `digit`, `graph`, `lower`, `print`, `punct`, `space`, `upper`, `word` and `xdigit`, and ICU's `Any`, `ASCII` and `Assigned`.

A bare block name such as `\p{Basic_Latin}` is ill-formed under the standard and is rejected here; use `\p{block=Basic_Latin}`.

#### Binary queries (§2.5.3)

`\p{property=value}` resolves the property through the `unicode` library: General_Category, Script, Script_Extensions, Block, Canonical_Combining_Class (numeric or named), Bidi_Class, Decomposition_Type, East_Asian_Width, Hangul_Syllable_Type, Joining_Type, Line_Break, Grapheme_Cluster_Break, Word_Break, Sentence_Break, Indic_Syllabic_Category, Indic_Positional_Category, Indic_Conjunct_Break, Vertical_Orientation, the NFx_Quick_Check properties, Numeric_Type, Age, and every binary property. A binary property may be given an explicit boolean (`\p{Uppercase=No}` is `\P{Uppercase}`).

The standard says a property value must consist only of literal characters unless the property is string-valued; this library also accepts escapes and named elements in any value (`\p{gc=\x{4C}u}` is `\p{gc=Lu}`), which is a pure extension.

Not supported, and rejected:

* **Name and Name_Alias value queries** (`\p{Name=SPACE}`), and string-valued properties such as `Lowercase_Mapping` and `Simple_Case_Folding`.
* **Numeric_Value** (`\p{nv=1/6}`, `\p{nv=0.5}`, `\p{nv=NaN}`), because the `unicode` library keys numeric values by number rather than by string.
* Some short property aliases that `unicode` does not carry, such as `Bidi_M` for `Bidi_Mirrored`; use the long name.

#### Age queries (§2.5.3.1)

Conformant. `\p{Age=6.0}` is every code point assigned in Unicode 6.0 or earlier, including private-use, surrogate and noncharacter code points, matching UTS #61 and ICU. The value may be written as a version alias (`V6_0`), or as a version number in which leading zeros and trailing zero fields are ignored (`6`, `6.0.0`, `06.00.00`). `V1_1` is an alias for 1.1, so `\p{Age=v11}` is `\p{Age=1.1}`, as the standard notes. `\p{Age=Unassigned}` and `\p{Age=NA}` are the code points that have no age.

ICU's extension of accepting a version that is not a Unicode version (`\p{Age=5.99.99}`) is not supported; such a value is an error.

#### Not recommended for APIs (§5)

The standard marks three facilities as not recommended for general-purpose libraries, and this library rejects all of them: version qualifiers (`\p{U15.1:...}`, `\p{U-1:...}`), property comparisons (`\p{scf=@lc@}`, `@none@`, `@code point@`) and regular-expression queries (`\p{Name=/CAPITAL LETTER/}`).

## Section 3: Set operations

The full grammar is implemented: `[...]`, `[^...]`, ranges, juxtaposition as union, `&` and `-` binding left-to-right at equal precedence, and nesting to override. The standard's own examples evaluate as it states.

| Expression | Result |
| --- | --- |
| `[[a-z]-[c]&[d]]` | `[d]` |
| `[[a-z]-[[c]&[d]]]` | `[a-z]` |
| `[[a-z]-[c][d]]` | `[a-bd-z]` |
| `[[a-z]-[[c][d]]]` | `[a-be-z]` |
| `[[a-z][]-[a]]` | `[b-z]` |
| `[[a-z][[]-[a]]]` | `[a-z]` |
| `[ac-z]` | 25 code points |

The right-hand operand of `&` and `-` must be a set: `[[a-z]-c]`, `[a-z-[c]]` and `[&[a]]` are ill-formed and rejected. A top-level expression must be a bracketed set or a property query: `[A-Z]-[C]` and `\p{L}&\p{Latn}` without an enclosing `[...]` are rejected.

A leading or trailing `-` is a literal hyphen: `[-a]`, `[a-]`, `[a-z-]` and `[-a-]` all contain U+002D.

Complement is the *code point* complement (§1.1): `[^{ab}]` is every code point, `[[{ab}a]&[^a]]` is empty, and `[[{ab}a]-[^a]]` is `{a, "ab"}`.

Divergences:

* **`[-]` and `[--]`.** Under the standard both are the one-element set `{-}`. This library treats `[-]` as the empty set for backwards compatibility with earlier releases, and rejects `[--]`. The first is a divergence on a valid expression; the second is a consistent rejection.
* **`[a-a]`.** The standard makes a range whose endpoints are equal ill-formed; this library accepts it as the single code point. Pure extension.
* **`[z-a]`** is rejected, as the standard requires.

The ICU extension of a trailing `$` meaning U+FFFF is not supported; `$` is a literal.

## Section 4: Conformance statement

`unicode_set` implements every production of the UTS #61 set-operation grammar and is therefore *syntactically complete*.

It is *consistent* with UTS #61 except for the following valid expressions, which it evaluates differently:

* `['a']` and any other use of `'`, which is a TR35 quoting character here and a literal under the standard.
* `[-]`, which is the empty set here and `{-}` under the standard.
* `{a b}` and any string member containing Pattern_White_Space, which is dropped here and literal under the standard.

The following are *pure extensions*, accepted here although ill-formed under the standard: unescaped `^` and `$` mid-set; `[::]`; `\7` and `\134` as literal digits; `\c` followed by a non-letter as a literal `c`; ignorable format controls as separators; `\u{...}`; multi-code-point `\x{...}`; string ranges; adjacent escaped surrogates; surrogates in strings; `[a-a]`; `Is` and `In` prefixes; POSIX compatibility names; `Any`, `ASCII`, `Assigned`; escapes in property values.

Everything else the standard defines is either evaluated as specified or rejected.

## Checking conformance

The behaviours described in this guide are exercised by `test/tr61_conformance_test.exs` and `test/parser_grammar_test.exs`. To check a single expression against your reading of the standard:

```elixir
iex> Unicode.Set.parse_and_reduce!("[[a-z]-[c]&[d]]").parsed
{:in, [{100, 100}]}

iex> Unicode.Set.parse("[\\N{0A:LATIN CAPITAL LETTER A}]")
{:error,
 {Unicode.Set.ParseError,
  "Unable to parse \"[\\\\N{0A:LATIN CAPITAL LETTER A}]\". the code point \"0A\" does not match the character named \"LATIN CAPITAL LETTER A\". Detected at \"]\"."}}
```
