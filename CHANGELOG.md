# Changelog for Unicode Set v0.6.0

This is the changelog for Unicode Set v0.6.0 released on May 13th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Enhancements

* Unicode sets are now a `%Unicode.Set{}` struct

* Add `Unicode.Set.Sigil` implementing `sigil_u`

* Add support for `String.Chars` and `Inspect` protocols

## Bug Fixes

* Fixes parsing sets to ignore non-encoded whitespace

* Fixes intersection and difference set operations for sets that include string ranges like `{abc}`

# Changelog for Unicode Set v0.5.1

This is the changelog for Unicode Set v0.5.1 released on March 14th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Bug Fixes

* Compacts tuple-ranges in order to minimize the number of generated clauses in guards. Requires at least `ex_unicode` version 1.5.0.

# Changelog for Unicode Set v0.5.0

This is the changelog for Unicode Set v0.5.0 released on March 11th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Enhancements

* Updates `ex_unicode` to version `1.4.0` which includes support for [Unicode version 13.0](http://blog.unicode.org/2020/03/announcing-unicode-standard-version-130.html) as well as support for several derived categories related to quote marks.

# Changelog for Unicode Set v0.4.2

This is the changelog for Unicode Set v0.4.2 released on February 25th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Bug Fixes

* Allow `\n`, `\t` and `\r`, `\s` as part of character classes

# Changelog for Unicode Set v0.4.1

This is the changelog for Unicode Set v0.4.1 released on January 8th, 2020.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Bug Fixes

* Fix `Unicode.Set.Operation.difference/2` when one list is wholly contained within another

# Changelog for Unicode Set v0.4.0

This is the changelog for Unicode Set v0.4.0 released on November 27th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Enhancements

* Bump to [ex_unicode](https://hex.pm/packages/ex_unicode) to version 1.3.0 to support an expanded set of properties resolved by `unicode_set`.

# Changelog for Unicode Set v0.3.0

This is the changelog for Unicode Set v0.3.0 released on November 26th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Enhancements

* Support string ranges expressed as `{abc}` or `{abc}-{def}`

* Note that the supported proporties in this release are `script`, `block`, `category` and `combining class`.

# Changelog for Unicode Set v0.2.0

This is the changelog for Unicode Set v0.2.0 released on November 24th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Enhancements

* Add `Unicode.Set.compile_pattern/1` and `Unicode.Set.pattern/1` to generate patterns and compiled patterns compatible with `String.split/3` and `String.replace/3`.

* Add `Unicode.Set.utf8_char/1` that generates a list of codepoint ranges compatible with [nimble_parsec](https://hex.pm/packages/nimble_parsec) combinators.

Set the README for example usage.

# Changelog for Unicode Set v0.1.0

This is the changelog for Unicode Set v0.1.0 released on November 23rd, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

Initial release.
