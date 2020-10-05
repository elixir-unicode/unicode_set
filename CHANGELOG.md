# Changelog for Unicode Set 0.11.0

This is the changelog for Unicode Set 0.11.0 released on October 5th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Bug Fixes

* Fix various bugs in set operations for `Union`, `Difference`, `Intersection` abd `Complement`

* Correctly parse and interpret set complements such as `[^[:^Sc:]]` and more complex sets such as `[^[[:Sc:]-[:^Lu:]]]`

# Changelog for Unicode Set 0.10.0

This is the changelog for Unicode Set 0.10.0 released on October 2nd, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Bug Fixes

* Fix list composition in `Unicode.Set.to_uft8_char/1`

# Changelog for Unicode Set 0.9.0

This is the changelog for Unicode Set 0.9.0 released on October 2nd, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Enhancements

* Support `nimble_parsec` version 1.x. Thanks to @josevalim for the PR.

# Changelog for Unicode Set 0.8.0

This is the changelog for Unicode Set 0.8.0 released on July 12th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Enhancements

* Rewrite `Unicode.Regex` module to better extract character classes, process unicode sets and build Elixir regexs. Now also supports string ranges.

* Supports the property `East Asian Width` (short name `ea`) which is required for implementing the Unicode segmentation algorithms.  Also bumps the minimum requirement for [ex_unicode version 1.8](https://hex.pm/packages/ex_unicode/1.8.0).

# Changelog for Unicode Set 0.7.0

This is the changelog for Unicode Set v.07.0 released on May 18th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Enhancements

* Add `Unicode.Set.character_class/1` which returns a string compatible with `Regex.compile/2`. This supports the idea of expanded Unicode Sets being used in standard Elixir/erlang regular expressions and will underpin implementation of Unicode Transforms in the package `unicode_transform`

* Add `Unicode.Regex.compile/2` to pre-process a regex to expand Unicode Sets and the compile it with `Regex.compile/2`.  `Unicode.Regex.compile!/2` is also added.

## Bug Fixes

* Fixes a bug whereby a Unicode Set intersection would fail with a character class that starts at the same codepoint as the Unicode set.

# Changelog for Unicode Set 0.6.0

This is the changelog for Unicode Set v.06.0 released on May 13th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Enhancements

* Unicode sets are now a `%Unicode.Set{}` struct

* Add `Unicode.Set.Sigil` implementing `sigil_u`

* Add support for `String.Chars` and `Inspect` protocols

## Bug Fixes

* Fixes parsing sets to ignore non-encoded whitespace

* Fixes intersection and difference set operations for sets that include string ranges like `{abc}`

# Changelog for Unicode Set 0.5.1

This is the changelog for Unicode Set v.05.1 released on March 14th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Bug Fixes

* Compacts tuple-ranges in order to minimize the number of generated clauses in guards. Requires at least `ex_unicode` version 1.5.0.

# Changelog for Unicode Set 0.5.0

This is the changelog for Unicode Set v.05.0 released on March 11th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Enhancements

* Updates `ex_unicode` to version `1.4.0` which includes support for [Unicode version 13.0](http://blog.unicode.org/2020/03/announcing-unicode-standard-version-130.html) as well as support for several derived categories related to quote marks.

# Changelog for Unicode Set 0.4.2

This is the changelog for Unicode Set v.04.2 released on February 25th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Bug Fixes

* Allow `\n`, `\t` and `\r`, `\s` as part of character classes

# Changelog for Unicode Set 0.4.1

This is the changelog for Unicode Set v.04.1 released on January 8th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Bug Fixes

* Fix `Unicode.Set.Operation.difference/2` when one list is wholly contained within another

# Changelog for Unicode Set 0.4.0

This is the changelog for Unicode Set v.04.0 released on November 27th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Enhancements

* Bump to [ex_unicode](https://hex.pm/packages/ex_unicode) to version 1.3.0 to support an expanded set of properties resolved by `unicode_set`.

# Changelog for Unicode Set 0.3.0

This is the changelog for Unicode Set v.03.0 released on November 26th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Enhancements

* Support string ranges expressed as `{abc}` or `{abc}-{def}`

* Note that the supported proporties in this release are `script`, `block`, `category` and `combining class`.

# Changelog for Unicode Set 0.2.0

This is the changelog for Unicode Set v.02.0 released on November 24th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Enhancements

* Add `Unicode.Set.compile_pattern/1` and `Unicode.Set.pattern/1` to generate patterns and compiled patterns compatible with `String.split/3` and `String.replace/3`.

* Add `Unicode.Set.utf8_char/1` that generates a list of codepoint ranges compatible with [nimble_parsec](https://hex.pm/packages/nimble_parsec) combinators.

Set the README for example usage.

# Changelog for Unicode Set 0.1.0

This is the changelog for Unicode Set v.01.0 released on November 23rd, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

Initial release.
