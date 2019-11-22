defmodule Unicode.Guards do
  @moduledoc """
  Defines a set of guards that can be used with
  Elixir functions.

  Each guard operates on a UTF8 codepoint since
  the permitted operators in a guard clause
  are restricted to simple comparisons that do
  not include string comparators.

  The data that underpins these guards is generated
  from the Unicode character database and therefore
  includes a broad range of scripts well beyond
  the basic ASCII definitions.

  """

  require Unicode.Set
  import Unicode.Set, only: [matches?: 2]

  @doc """
  Guards whether a UTF8 codepoint is an upper case
  character.

  The match is for any UTF8 character that is defined
  in Unicode to be an upper case character in any
  script.

  """
  defguard is_upper(codepoint) when is_integer(codepoint) and matches?(codepoint, "[[:Lu:]]")

  @doc """
  Guards whether a UTF8 codepoint is a lower case
  character.

  The match is for any UTF8 character that is defined
  in Unicode to be an lower case character in any
  script.

  """
  defguard is_lower(codepoint) when is_integer(codepoint) and matches?(codepoint, "[[:Ll:]]")

  @doc """
  Guards whether a UTF8 codepoint is a digit
  character.

  This guard will match any digit character from any
  Unicode script, not only the ASCII decimal digits.

  """
  defguard is_digit(codepoint) when is_integer(codepoint) and matches?(codepoint, "[[:Nd:]]")

  @doc """
  Guards whether a UTF8 codepoint is a currency symbol
  character.

  """
  defguard is_currency_symbol(codepoint)
           when is_integer(codepoint) and matches?(codepoint, "[[:Sc:]]")


  @doc """
  Guards whether a UTF8 codepoint is a whitespace symbol
  character.

  """
  defguard is_whitespace(codepoint) when is_integer(codepoint) and matches?(codepoint, "[[:Zs:]]")
end
