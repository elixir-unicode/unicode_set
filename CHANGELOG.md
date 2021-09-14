# Changelog

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

* Adds `Unicode.Set.to_generate_matches/1` that returns a tuple whose first element is the AST of a guard clause and the second element is a list of strings. This function is marked private and is implemented to suport [unicode_transform](https://hex.pm/unicode_transform) which uses this information to generate optimised code for matching unicode sets in a `case` expression.

## Unicode Set 0.12.0

This is the changelog for Unicode Set 0.12.0 released on February 23rd, 2021.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* Adds support for "isBlockName" Perl and POSIX regex syntax. Used in a regex as `[[:isLatin1]]` or `\p{isLatin1}` or their inverse forms `[[:^isLatin1]]` and `\P{isLatin1}`.

## Unicode Set 0.11.0

This is the changelog for Unicode Set 0.11.0 released on October 5th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

### Enhancements

* Add recurively defined sets to support compatibility with Posix classes. See `Unicode.Set.Property`.

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
