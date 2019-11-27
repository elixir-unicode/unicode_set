# Changelog for Unicode Set v0.4.0

This is the changelog for Unicode Set v0.4.0 released on November 27th, 2019.  For older changelogs please consult the release tag on [GitHub](https://github.com/elixir-unicode/unicode_set/tags)

## Enhancements

* Bump to [ex_unicode](https://hex.pm/packages/ex_unicode) to version 1.3.0 to support an expanded set of properties resovled by `unicode_set`.

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
