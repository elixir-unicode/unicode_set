# UTS #61 conformance

This guide records how `unicode_set` relates to [UTS #61, Unicode Set Notation](https://www.unicode.org/reports/tr61/), the draft Unicode Technical Standard that formalises the UnicodeSet syntax previously described only in [CLDR TR35](https://unicode.org/reports/tr35/#Unicode_Sets) and by the ICU implementation. It was written against revision 2 of the draft (2026-09-11) and is organised by the sections of that document.

UTS #61 defines two grades of conformance.

* An implementation is **consistent** if, for every valid UnicodeSet expression, it either rejects the expression or evaluates it exactly as the standard specifies. Rejecting is always allowed; evaluating to a different set is not. Where a consistent implementation accepts expressions that the standard calls ill-formed, those are **pure extensions**, which are permitted provided they are declared.
* An implementation is **syntactically complete** if it supports every production of the set-operation grammar (Section 3), whatever subset of lexical elements it chooses to accept.

`unicode_set` is consistent and syntactically complete. Every valid expression it accepts evaluates as the standard specifies; the pure extensions it accepts are declared in the [conformance statement](#section-4-conformance-statement) below. Everything the standard marks as *not recommended for general-purpose APIs* (version qualifiers, property comparisons, regular-expression queries) is rejected.

## Summary

The table gives the status of each area of the standard as of version 1.9.0 with `unicode` 2.2. *Conformant* means every valid expression in that area evaluates as the standard specifies. *Extension* means the library additionally accepts expressions the standard makes ill-formed, which the standard permits provided they are declared. *Rejected* means the expressions are refused with an error, which is always consistent.

| UTS #61 area | Status | Notes |
| --- | --- | --- |
| §2 White space | Conformant | All Pattern_White_Space characters are ignored between elements. Extension: the ignorable format controls U+200E and U+200F also separate elements that the standard says they may not. Rejected: white space before or after a whole expression. |
| §2.1 Literal elements | Conformant | `'` is a literal; there is no TR35 quoting. Extension: `^` and `$` are literals mid-set, and `[::]` is a set containing `:`. |
| §2.2 Escaped elements | Conformant | `\x`, `\u`, `\U`, octal (1–3 digits), `\c` (`@ A-Z [ \ ] ^ _`), named controls, `\N`, and `\` before any other character. Values above U+10FFFF are rejected. Extensions: `\u{...}`, multi-code-point `\x{...}`, `\c` with a lowercase letter, adjacent escaped surrogates. |
| §2.3 Named elements | Conformant | `\N{NAME}`, `\N{HEX:NAME}` and `\N{HEX:CHAR:NAME}`, matched under UAX44-LM2 against the Name and every Name_Alias type (control, abbreviation, correction, alternate, figment). |
| §2.4 Bracketed elements and strings | Conformant | Everything but `\` and `}` is literal inside braces; `{}` is the empty string. Extension: string ranges `{ab}-{cd}`, surrogates inside strings. Rejected: mixed range endpoints `[{a}-z]`. |
| §2.5 Property queries | Conformant | Perl and POSIX forms, `=` and `≠`, single and double negation, UAX44-LM3 matching. Extensions: `Is`/`In` prefixes, POSIX compatibility names, `Any`/`ASCII`/`Assigned`, escapes in any property value. Rejected: leading white space inside the braces. |
| §2.5.2 Unary queries | Conformant | Binary properties, Script values and General_Category values including groupings. A bare block name is rejected. |
| §2.5.3 Binary queries | Conformant | Every enumerated, numeric and binary property in the UCD, including `@missing` default values such as `jt=U` and `sc=Zzzz`, plus Name and Name_Alias. Rejected: string-valued properties such as `Lowercase_Mapping`. |
| §2.5.3.1 Age queries | Conformant | Cumulative; accepts `V6_0`, `6`, `6.0.0`, `06.00.00`, `Unassigned` and `NA`. ICU's non-Unicode versions such as `5.99.99` are rejected. |
| §2.5.3.4 Name and Name_Alias | Conformant | `\p{Name=X}` matches a name or alias; `\p{Name_Alias=X}` matches an alias only. |
| §2.5.3.4 Numeric values | Conformant | `NaN`, rationals by rational equality, decimals by binary64 equality. |
| §2.5.3.2, §2.5.3.3, §2.5.3.6 Comparisons, identity and null queries, regular expressions | Rejected | Marked *not recommended for general-purpose APIs* by the standard. |
| §2.5 Version qualifiers | Rejected | Marked *not recommended for general-purpose APIs* by the standard. |
| §3 Set operations | Conformant | Full grammar, including `[-]`, `[--]`, `[ ]` and `[^ ]`. The standard's precedence examples all evaluate as stated. Extension: `[a-a]`. |
| §4 Conformance | Consistent, syntactically complete | No valid expression evaluates to a different set than the standard specifies. |

## Section 2: Lexical elements

### White space

Pattern_White_Space (U+0009–U+000D, U+0020, U+0085, U+200E, U+200F, U+2028, U+2029) is ignored between lexical elements, so `[ A-Z ] - [C]` inside an outer set is the same as `[A-Z]-[C]`.

The standard adds that the two *ignorable format controls*, U+200E LEFT-TO-RIGHT MARK and U+200F RIGHT-TO-LEFT MARK, may not be the *only* separator between two elements whose juxtaposition would otherwise lex differently: `[\xD<LRM>F]` is ill-formed under the standard, because without the mark `\xDF` is one escape. This library ignores the marks like any other white space, so that expression is accepted and evaluates to `[\x0D F]`. This is a pure extension.

Leading and trailing white space around a whole expression is not accepted; `" \p{L}"` is an error.

### §2.1 Literal elements

Under the standard the only characters that are not literal are the set operators `& - [ ] ^`, the braces `{ }`, `$` and `\`, and Pattern_White_Space. Everything else, including the single quote, is a literal: `['a']` is the set `{', a}`. The CLDR TR35 and ICU convention of `'...'` quoting is deliberately not implemented, because it changes the meaning of a valid UTS #61 expression; escape a special character with `\` instead.

Two characters are accepted as literals in positions where the standard makes the expression ill-formed, following ICU.

* **`^` and `$` mid-set.** `[a^b]` and `[a$]` are ill-formed under the standard, since `^` is a set operator and `$` is reserved. This library treats both as literal characters when they cannot be an operator, as ICU does. Pure extension.
* **`:` after `[`.** The standard requires white space between `[` and a literal `:` so that `[:` is always a POSIX query start. `[::]` and `[:^:]` are ill-formed under the standard; this library accepts them as sets containing a literal colon. Pure extension. `[ :a]` is `{:, a}` in both.

### §2.2 Escaped elements

All of the standard's escapes are supported: `\xH`, `\xHH`, `\x{H...}`, `\uHHHH`, `\UHHHHHHHH`, `\N{...}`, the named controls `\a \b \e \f \n \r \t \v`, `\cX`, octal, and `\` before any other character, which is that character. Hexadecimal escapes that do not denote a code point, such as `\x{110000}`, are rejected as the standard requires.

Octal escapes are one to three octal digits with maximal munch: `\7` is U+0007, `\134` is U+005C, and `\1234` is U+0053 followed by the literal `4`. As the standard notes, white space is needed to separate an octal escape from a following digit that would otherwise be absorbed (`\0 0` is U+0000 and `0`; `\00` is U+0000 alone).

`\cX` is defined for `X` in `@ A-Z [ \ ] ^ _` and is `X` AND 0x1F, so `\cG` is U+0007 and `\c[` is U+001B. Any other character after `\c` (including `?`, which the standard leaves undefined) is an error. As an ICU-compatible extension, a lowercase letter is also accepted and treated as its uppercase form.

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
| `\N{PRESENTATION FORM FOR VERTICAL RIGHT WHITE LENTICULAR BRAKCET}` | U+FE18 (the misspelling is the character's actual name) |
| `\N{PRESENTATION FORM FOR VERTICAL RIGHT WHITE LENTICULAR BRACKET}` | U+FE18, via its correction alias |
| `\N{NULL}`, `\N{NUL}`, `\N{0:NULL}` | U+0000, via its control-character name and abbreviation aliases |
| `\N{BYTE ORDER MARK}` | U+FEFF, via its alternate alias |
| `\N{Latin small ligature o-e}` | U+0153 (UAX44-LM2 loose matching) |

A named element is an `Element`, so it may be a range endpoint and `[\N{LATIN SMALL LETTER A}-\N{LATIN SMALL LETTER Z}]` is the 26 letters, as the standard's grammar requires. An unbracketed `\N{SPACE}` is not a set, and `[\p{L}-\N{SPACE}]` is ill-formed because the right-hand side of a difference must be a set; both are rejected.

Names are resolved through the character-name table in the `unicode` library, which includes algorithmically-named characters (CJK and Tangut ideographs, Hangul syllables, Seal and Jurchen) and, from `unicode` 2.2, every `Name_Alias` value: corrections (`LATIN CAPITAL LETTER GHA`), control-character names (`NULL`, `LINE FEED`), abbreviations (`NUL`, `LF`, `ZWJ`), alternates (`BYTE ORDER MARK`) and figments. This matches the standard, which defines a named element by its Name or Name_Alias, and goes beyond ICU, which the standard notes supports only correction aliases.

### §2.4 Bracketed elements and strings

`{}` is the empty string, `{a}` is the single code point `a`, and `{ab}` is a string member. Escapes and named elements are honoured inside braces.

Divergences and extensions:

* **Everything is literal inside braces.** As the standard requires, every character other than `\` and `}` is literal, so `{a b}` is the three-code-point string `"a b"`, `{a-b}` contains a hyphen and `{[}` is the single code point `[`. Single quotes have no quoting role inside braces.
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

* **String-valued properties** such as `Lowercase_Mapping` and `Simple_Case_Folding`, which the `unicode` library does not expose as sets.

Values that the UCD supplies only through `@missing` lines, such as `Joining_Type=Non_Joining` (`jt=U`), `Bidi_Paired_Bracket_Type=None` and `Script=Unknown` (`Zzzz`), and separator-bearing binary aliases such as `Bidi_M`, resolve with `unicode` 2.2 or later.

#### Name and Name_Alias (§2.5.3.4, §2.5.3.5)

Conformant. `\p{Name=X}` is the single character whose Name or Name_Alias matches `X` under UAX44-LM2, and `\p{Name_Alias=X}` is the single character one of whose aliases matches `X`. As the standard states, for every formal alias `X` the two queries are the same set.

| Expression | Result |
| --- | --- |
| `\p{Name=SPACE}`, `\p{na=latin small letter a}` | U+0020, U+0061 |
| `\p{Name=NULL}`, `\p{Name_Alias=NULL}`, `\p{Name_Alias=NUL}` | U+0000 |
| `\p{Name_Alias=SP}` | U+0020 |
| `\p{Name_Alias=SPACE}` | ill-formed: `SPACE` is a Name, not an alias |
| `\p{Name=THIS IS NOT A CHARACTER}` | ill-formed |
| `\P{Name=SPACE}` | every code point but U+0020 |

#### Numeric values (§2.5.3.4)

Conformant. A `Numeric_Value` query accepts the three forms the standard defines and resolves them as it specifies.

| Expression | Result |
| --- | --- |
| `\p{nv=NaN}` | every code point with no numeric value |
| `\p{nv=1/6}`, `\p{nv=2/12}` | the same set, by rational equality: U+2159 ⅙ and its companions |
| `\p{nv=-1/2}` | U+0F33 TIBETAN DIGIT HALF ZERO |
| `\p{nv=0.5}`, `\p{nv=1/2}` | the same set |
| `\p{nv=0.16666666666666667}` | contains U+2159, since it rounds to the same binary64 as 1/6 |
| `\p{nv=0.16666667}` | empty, as the standard notes: the rounded value in `DerivedNumericValues.txt` does not round to 1/6 |
| `\p{nv=16666666666666667/100000000000000000}` | empty, since the rational is not 1/6 |
| `\p{nv=seven}`, `\p{nv=1/0}`, `\p{nv=1e3}` | ill-formed |

A well-formed value that no character carries is the empty set, not an error. Regular-expression matching on numeric properties is undefined by the standard and rejected here.

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

A leading or trailing `-` is a literal hyphen: `[-a]`, `[a-]`, `[a-z-]`, `[-a-]`, `[-]` and `[--]` all contain U+002D. `[]` is the empty set, as is `[ ]`, and `[^ ]` is every code point.

Complement is the *code point* complement (§1.1): `[^{ab}]` is every code point, `[[{ab}a]&[^a]]` is empty, and `[[{ab}a]-[^a]]` is `{a, "ab"}`.

One extension:

* **`[a-a]`.** The standard makes a range whose endpoints are equal ill-formed; this library accepts it as the single code point. Pure extension.
* **`[z-a]`** is rejected, as the standard requires.

The ICU extension of a trailing `$` meaning U+FFFF is not supported; `$` is a literal.

## Section 4: Conformance statement

`unicode_set` implements every production of the UTS #61 set-operation grammar and is therefore *syntactically complete*.

It is *consistent* with UTS #61: no valid expression is evaluated to a different set than the standard specifies. Earlier releases departed from the standard for single-quote quoting (`['a']`) and the empty-set spelling `[-]`; both were brought into line in version 1.9.0.

The following are *pure extensions*, accepted here although ill-formed under the standard: unescaped `^` and `$` mid-set; `[::]`; `\c` followed by a lowercase letter; ignorable format controls as separators; `\u{...}`; multi-code-point `\x{...}`; string ranges; adjacent escaped surrogates; surrogates in strings; `[a-a]`; `Is` and `In` prefixes; POSIX compatibility names; `Any`, `ASCII`, `Assigned`; escapes in property values.

Everything else the standard defines is either evaluated as specified or rejected.

## Checking conformance

The behaviours described in this guide are exercised by `test/tr61_conformance_test.exs` and `test/parser_grammar_test.exs`. The review behind this guide ran a matrix of 242 expressions taken from the standard's own examples and grammar. 194 evaluate as the standard specifies or as a declared extension, 48 are rejected with an error, and none raise. Every rejection is either an expression the standard makes ill-formed or one of the consistent rejections listed above. To check a single expression against your reading of the standard:

```elixir
iex> Unicode.Set.parse_and_reduce!("[[a-z]-[c]&[d]]").parsed
{:in, [{100, 100}]}

iex> Unicode.Set.parse("[\\N{0A:LATIN CAPITAL LETTER A}]")
{:error,
 {Unicode.Set.ParseError,
  "Unable to parse \"[\\\\N{0A:LATIN CAPITAL LETTER A}]\". the code point \"0A\" does not match the character named \"LATIN CAPITAL LETTER A\". Detected at \"]\"."}}
```
