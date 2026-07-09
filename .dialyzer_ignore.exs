# Dialyzer false positive in the NimbleParsec-generated parser for
# `defparsecp :one_set` (lib/unicode_set.ex). Dialyzer cannot see that a
# generated guard test is reachable.
#
# Each entry is a Regex matched against the warning's short description.
[
  # The `≠` operator is `utf8_char([0x2260])`; 0x2260 = 8800 is compared to a byte().
  # Only emitted on some OTP/Elixir versions in the CI matrix.
  ~r/=:= 8800 can never succeed/
]
