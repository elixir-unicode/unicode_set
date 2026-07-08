# Dialyzer false positives in the NimbleParsec-generated parser for
# `defparsecp :one_set` (lib/unicode_set.ex). Dialyzer cannot see that the
# generated guard tests and success continuations are reachable.
#
# Each entry is a Regex matched against the warning's short description.
[
  # The `≠` operator is `utf8_char([0x2260])`; 0x2260 = 8800 is compared to a byte().
  ~r/=:= 8800 can never succeed/,
  # Success continuations after the always-failing `\N{...}` branch look unused.
  ~r/one_set__\d+.* will never be called/
]
