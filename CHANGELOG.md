# Changelog

As of `unicode_set` version 1.4.0, Elixir 1.12 or later is required.

## Unicode Set 1.6.3 (unreleased)

### Bug Fixes

* Backslash-letter escapes are decoded correctly: `\a \b \e \f \v \t \n \r` map to their control codes, and any other `\<char>` maps to that literal character. Previously `\a`–`\f` silently decoded to the wrong codepoint and `\g`–`\z` / `\U` / `\w` raised.
* `Unicode.Set.parse/1` returns `{:error, _}` for genuinely unsupported syntax (`\N{...}`, `\p{emoji=value}`, multi-codepoint `\u{...}`) instead of raising, restoring its documented tagged-tuple contract.
* The empty set `[-]` now reduces to `{:in, []}` and its consumers (`to_pattern/1`, `to_utf8_char/1`, `to_regex_string/1`) return an empty result or a never-matching regex instead of crashing.
* A union of complements such as `[[^a][^b]]` now reduces correctly (per De Morgan) and no longer crashes `to_regex_string/1` or the `match?/2` search-tree path.
* `to_pattern/1` and `compile_pattern/1` return a tagged error for complement (`[^...]`) sets rather than raising; the `!` variants continue to raise.
* `Unicode.Set.match?/2` and the search tree no longer crash when matched against an empty string, and `generate_matches/2` no longer crashes on a complement set.
* Set operations now bind strictly left-to-right, including across an implicit-union boundary: `[[a-f]-[b][g]&[g-z]]` is now `{g}` and the README precedence example evaluates as documented. Previously a trailing `&` or `-` bound only to its immediate neighbour.
* `union/2` merges overlapping and adjacent ranges, so a union feeding a difference or intersection no longer retains codepoints that should have been subtracted; `symmetric_difference/2` is likewise correct for overlapping inputs.
* Reversed character ranges (`[z-a]`) and mismatched-length string ranges (`[{abc}-{de}]`) are rejected with a clear error instead of being silently accepted.
* String members and string ranges are PCRE-escaped when emitted as a regex, so `[{a.c}]` matches the literal string and sets containing regex metacharacters no longer produce an uncompilable pattern (RE-1).
* Sets of multiple string members no longer emit a bogus empty `[[][]]` class, and string-range alternations are wrapped in `(?:...)` so they compose correctly when embedded in a larger regex (SR-1, RE-4).
* Character ranges with a surrogate endpoint are clipped rather than emitting a dangling `-` or dropping codepoints, and a surrogate-only set emits a never-matching `(?!)` instead of the uncompilable `[]` (RE-2, RE-5).
* The regex splitter correctly handles a character class containing an escaped backslash such as `[\\]` (RS-2), and passes `\Q...\E` literal spans and `(?#...)` comments through verbatim rather than expanding any `[...]` inside them (RS-1, RS-4).
* The `Is<name>` prefix now resolves as a script, general category or binary property before falling back to a block, so `\p{IsAlphabetic}`, `\p{IsLatin}` and `[:IsLowercase:]` resolve instead of erroring; `Is<Block>` names such as `\p{IsBasicLatin}` still resolve to their block (GAP-ISPREFIX).
* Digit-bearing block names such as `\p{block=Latin-1 Supplement}` now resolve, working around a `Unicode.Block.fetch/1` bug present in the `unicode` dependency (PS-7).

### Enhancements

* Added the `\UHHHHHHHH` (8 hex digit) escape, the single-digit `\xH` escape, and single-codepoint bracketed `\u{...}` / `\x{...}` escapes (including astral codepoints such as `\u{1F600}`).
* Added octal `\0ooo` escapes and `\cX` control escapes.
* Multi-codepoint bracketed escapes such as `\u{41 42 43}` are now a string member (equivalent to `{ABC}`).
* Implemented single-quote quoting: text within `'...'` is literal and `''` is a literal quote (CLDR TR35).
* `\N{NAME}` now resolves to its codepoint when built against `unicode ~> 2.0` (which provides the character-name table); on earlier versions it returns a clean error.
* Whitespace immediately after `[` or `[^` is now ignored, consistent with whitespace elsewhere in a set.
* Hyphens are now accepted and ignored in property names per UAX44-LM3, so `\p{White-Space}` and `[:Quotation-Mark:]` resolve (PS-1).
* Accept the Java-style `In<Block>` prefix, so `\p{InBasicLatin}` resolves to the block while genuine `In...` names such as `\p{Inherited}` are unaffected (PS-8).
* The empty set is now written `[]` as well as `[-]`, the empty-string member `[{}]` is supported, and a hyphen at the start or end of a set (`[-a]`, `[a-]`, `[a-z-]`) is treated as a literal hyphen, matching ICU.

### Changes

* Corrected README examples: the block name `Sundanese` (was `sudanese`), a working `\p{General_Category=...}` property spelling, the single-dash `print` compatibility definition, and the `to_regex_string/1` doc example.
* Removed the unused `:parse_many` parser combinator.
* Moved the Dialyzer ignore list to the term-format `.dialyzer_ignore.exs`.
* Added a "Conformance" section to the README documenting supported syntax, deliberate tailorings, and current limitations, and a note explaining the POSIX-compatible `[:punct:]` definition.

## Unicode Set 1.6.2

This is the changelog for Unicode Set 1.6.2 released on July 8th, 2026. For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Changes

* Allow `unicode ~> 2.0`.
* Add Credo, test coverage and CI hardening across the Elixir 1.17 to 1.20 / OTP 27 to 29 matrix.

## Unicode Set 1.6.1

This is the changelog for Unicode Set 1.6.1 released on March 16th, 2026. For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Bug Fixes

* Fix a bug where a set starting with "-" was interpreted as negation.

## Unicode Set 1.6.0

This is the changelog for Unicode Set 1.6.0 released on January 19th, 2026. For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Bug Fixes

* Fix tests for OTP 28 and Elixir 1.20.

### Enhancements

* Updates to [Unicode 17.0](https://unicode.org/versions/Unicode17.0.0/) data.

## Unicode Set 1.5.0

This is the changelog for Unicode Set 1.5.0 released on March 29th, 2025. For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Bug Fixes

* Converts all compile-time regex compilation to runtime to be compatible with OTP 28. Performance implications are not yet known.

## Unicode Set 1.4.1

This is the changelog for Unicode Set 1.4.1 released on January 1st, 2025. For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Bug Fixes

* Work around the Elixir type checker for now.

## Unicode Set 1.4.0

This is the changelog for Unicode Set 1.4.0 released on May 26th, 2024. For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Bug Fixes

* Fix warnings for Elixir 1.17. Thanks to @alco for the PR.

## Unicode Set 1.3.0

This is the changelog for Unicode Set 1.3.0 released on February 18th, 2023. For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Bug Fixes

* Correct the code examples in README.md.  Thanks to @DianaOlympos for the PR. Closes #9.

### Enhancements

* Add `Unicode.Set.compile_pattern!/1` to accompany `Unicode.Set.compile_pattern/1`.

## Unicode Set 1.2.0

This is the changelog for Unicode Set 1.2.0 released on September 15th, 2022. For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* Update parsing code to ensure compatibility against future deprecations. Thanks to @josevalim.

* Fix library name in doc links. Thanks to @zmaril for the PR.

* Update dependencies. Thanks to @kianmeng.

## Unicode Set 1.1.0

This is the changelog for Unicode Set 1.1.0 released on September 15th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* `ex_unicode` is renamed to `unicode` in collaboration with @Qqwy and therefore this release updates the dependency name.

## Unicode Set 1.0.0

This is the changelog for Unicode Set 1.0.0 released on September 14th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* Update to use [Unicode 14](https://unicode.org/versions/Unicode14.0.0)

## Unicode Set 0.13.1

This is the changelog for Unicode Set 0.13.1 released on May 25th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Bug Fixes

* Update dependency configuration to mark `ex_doc` and `benchee` as optional.  Thanks to @fireproofsocks.

## Unicode Set 0.13.0

This is the changelog for Unicode Set 0.13.0 released on April 4th, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* Adds `Unicode.Set.to_generate_matches/1` that returns a tuple whose first element is the AST of a guard clause and the second element is a list of strings. This function is marked private and is implemented to support [unicode_transform](https://hex.pm/unicode_transform) which uses this information to generate optimised code for matching unicode sets in a `case` expression.

## Unicode Set 0.12.0

This is the changelog for Unicode Set 0.12.0 released on February 23rd, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* Adds support for "isBlockName" Perl and POSIX regex syntax. Used in a regex as `[[:isLatin1]]` or `\p{isLatin1}` or their inverse forms `[[:^isLatin1]]` and `\P{isLatin1}`.

## Unicode Set 0.11.0

This is the changelog for Unicode Set 0.11.0 released on October 5th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* Add recursively defined sets to support compatibility with Posix classes. See `Unicode.Set.Property`.

### Bug Fixes

* Fix various bugs in set operations for `Union`, `Difference`, `Intersection` abd `Complement`

* Correctly parse and interpret set complements such as `[^[:^Sc:]]` and more complex sets such as `[^[[:Sc:]-[:^Lu:]]]`

## Unicode Set 0.10.0

This is the changelog for Unicode Set 0.10.0 released on October 2nd, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Bug Fixes

* Fix list composition in `Unicode.Set.to_uft8_char/1`

## Unicode Set 0.9.0

This is the changelog for Unicode Set 0.9.0 released on October 2nd, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* Support `nimble_parsec` version 1.x. Thanks to @josevalim for the PR.

## Unicode Set 0.8.0

This is the changelog for Unicode Set 0.8.0 released on July 12th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* Rewrite `Unicode.Regex` module to better extract character classes, process unicode sets and build Elixir regexs. Now also supports string ranges.

* Supports the property `East Asian Width` (short name `ea`) which is required for implementing the Unicode segmentation algorithms.  Also bumps the minimum requirement for [ex_unicode version 1.8](https://hex.pm/packages/ex_unicode/1.8.0).

## Unicode Set 0.7.0

This is the changelog for Unicode Set v.07.0 released on May 18th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* Add `Unicode.Set.character_class/1` which returns a string compatible with `Regex.compile/2`. This supports the idea of expanded Unicode Sets being used in standard Elixir/erlang regular expressions and will underpin implementation of Unicode Transforms in the package `unicode_transform`

* Add `Unicode.Regex.compile/2` to pre-process a regex to expand Unicode Sets and the compile it with `Regex.compile/2`.  `Unicode.Regex.compile!/2` is also added.

### Bug Fixes

* Fixes a bug whereby a Unicode Set intersection would fail with a character class that starts at the same codepoint as the Unicode set.

## Unicode Set 0.6.0

This is the changelog for Unicode Set v.06.0 released on May 13th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* Unicode sets are now a `%Unicode.Set{}` struct

* Add `Unicode.Set.Sigil` implementing `sigil_u`

* Add support for `String.Chars` and `Inspect` protocols

### Bug Fixes

* Fixes parsing sets to ignore non-encoded whitespace

* Fixes intersection and difference set operations for sets that include string ranges like `{abc}`

## Unicode Set 0.5.1

This is the changelog for Unicode Set v.05.1 released on March 14th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Bug Fixes

* Compacts tuple-ranges in order to minimize the number of generated clauses in guards. Requires at least `ex_unicode` version 1.5.0.

## Unicode Set 0.5.0

This is the changelog for Unicode Set v.05.0 released on March 11th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* Updates `ex_unicode` to version `1.4.0` which includes support for [Unicode version 13.0](http://blog.unicode.org/2020/03/announcing-unicode-standard-version-130.html) as well as support for several derived categories related to quote marks.

## Unicode Set 0.4.2

This is the changelog for Unicode Set v.04.2 released on February 25th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Bug Fixes

* Allow `\n`, `\t` and `\r`, `\s` as part of character classes

## Unicode Set 0.4.1

This is the changelog for Unicode Set v.04.1 released on January 8th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Bug Fixes

* Fix `Unicode.Set.Operation.difference/2` when one list is wholly contained within another

## Unicode Set 0.4.0

This is the changelog for Unicode Set v.04.0 released on November 27th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* Bump to [ex_unicode](https://hex.pm/packages/ex_unicode) to version 1.3.0 to support an expanded set of properties resolved by `unicode_set`.

## Unicode Set 0.3.0

This is the changelog for Unicode Set v.03.0 released on November 26th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* Support string ranges expressed as `{abc}` or `{abc}-{def}`

* Note that the supported proporties in this release are `script`, `block`, `category` and `combining class`.

## Unicode Set 0.2.0

This is the changelog for Unicode Set v.02.0 released on November 24th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* Add `Unicode.Set.compile_pattern/1` and `Unicode.Set.pattern/1` to generate patterns and compiled patterns compatible with `String.split/3` and `String.replace/3`.

* Add `Unicode.Set.utf8_char/1` that generates a list of codepoint ranges compatible with [nimble_parsec](https://hex.pm/packages/nimble_parsec) combinators.

Set the README for example usage.

## Unicode Set 0.1.0

This is the changelog for Unicode Set v.01.0 released on November 23rd, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

Initial release.
