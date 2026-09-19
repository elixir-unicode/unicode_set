defmodule Unicode.Set.TR61ConformanceTest do
  use ExUnit.Case, async: true

  # Regression tests for the UTS #61 conformance review. Each `describe`
  # corresponds to a section of `guides/tr61_conformance.md`.

  defp ranges(expression) do
    {:in, ranges} = Unicode.Set.parse_and_reduce!(expression).parsed
    ranges
  end

  defp member?(expression, codepoint) do
    Enum.any?(ranges(expression), fn
      {from, to} when is_integer(from) -> codepoint in from..to
      _string -> false
    end)
  end

  defp count(expression) do
    Enum.reduce(ranges(expression), 0, fn
      {from, to}, acc when is_integer(from) -> acc + to - from + 1
      _string, acc -> acc + 1
    end)
  end

  describe "string members under set operations (UTS #61 §2.4, §3.1)" do
    test "a string member whose code points are not ascending is kept as written" do
      assert Unicode.Set.to_regex_string("[[{ba}]-[a]]") == {:ok, "(?:ba)"}
      assert Unicode.Set.to_regex_string("[[{zaz}]&[{zaz}]]") == {:ok, "(?:zaz)"}
      assert Unicode.Set.parse_and_reduce!("[[{ba}]-[a]]").parsed == {:in, [{~c"ba", ~c"ba"}]}
    end

    test "intersection keeps only the common string members" do
      assert Unicode.Set.to_regex_string("[[{ba}{ab}]&[{ab}]]") == {:ok, "(?:ab)"}
    end

    test "a string range still expands as a range" do
      assert Unicode.Set.to_regex_string("[[{ab}-{ad}a]-[a]]") == {:ok, "(?:ad|ac|ab)"}
    end
  end

  describe "the empty-string member {} (UTS #61 §2.4.1)" do
    test "is emitted as an empty alternative in a regex" do
      assert Unicode.Set.to_regex_string("[{}]") == {:ok, "(?:)"}
      assert Unicode.Set.to_regex_string("[{}a]") == {:ok, "(?:[\\x{61}]|)"}
      assert Unicode.Set.to_regex_string("[[{}a]-[a]]") == {:ok, "(?:)"}
    end

    test "is dropped from a compiled binary pattern" do
      assert {:ok, _pattern} = Unicode.Set.compile_pattern("[{}a]")
      assert Unicode.Set.to_pattern("[{}]") == {:ok, [""]}
    end

    test "a set with no non-empty members cannot be compiled to a pattern" do
      assert {:error, {Unicode.Set.ParseError, message}} = Unicode.Set.compile_pattern("[{}]")
      assert message =~ "cannot be compiled to a pattern"
      assert {:error, {Unicode.Set.ParseError, _}} = Unicode.Set.compile_pattern("[]")
    end
  end

  describe "named elements (UTS #61 §2.3)" do
    test "the three forms of a named element" do
      assert ranges("[\\N{SPACE}]") == [{32, 32}]
      assert ranges("[\\N{0020:SPACE}]") == [{32, 32}]
      assert ranges("[\\N{20: :SPACE}]") == [{32, 32}]
      assert ranges("[\\N{41:A:LATIN CAPITAL LETTER A}]") == [{65, 65}]
    end

    test "a named element is a range endpoint" do
      assert ranges("[\\N{LATIN SMALL LETTER A}-\\N{LATIN SMALL LETTER Z}]") == [{97, 122}]
    end

    test "an unknown name is an error, not a literal N" do
      assert {:error, {_, message}} = Unicode.Set.parse("[\\N{THIS IS NOT A CHARACTER}]")
      assert message =~ "is not known"
    end

    test "a code point that does not match the name is an error" do
      assert {:error, {_, message}} = Unicode.Set.parse("[\\N{0A:LATIN CAPITAL LETTER A}]")
      assert message =~ "does not match"
    end

    test "a character that does not match the name is an error" do
      assert {:error, {_, message}} = Unicode.Set.parse("[\\N{41:a:LATIN CAPITAL LETTER A}]")
      assert message =~ "does not match"
    end

    test "\\N without a braced name is an error" do
      assert {:error, {_, message}} = Unicode.Set.parse("[\\NX]")
      assert message =~ "must be followed by a character name"
      assert {:error, {_, _}} = Unicode.Set.parse("[\\N{SPACE]")
    end

    test "a named element inside a string member" do
      assert ranges("[{a\\N{SPACE}}]") == [{~c"a ", ~c"a "}]
    end
  end

  describe "everything inside braces is literal (UTS #61 §2.4)" do
    test "white space is part of the string" do
      assert ranges("[{a b}]") == [{~c"a b", ~c"a b"}]
      assert ranges("[{ }]") == [{32, 32}]
      assert ranges("[{a" <> <<0x2028::utf8>> <> "b}]") == [{[?a, 0x2028, ?b], [?a, 0x2028, ?b]}]
    end

    test "set-syntax characters are literal" do
      assert ranges("[{a-b}]") == [{~c"a-b", ~c"a-b"}]
      assert ranges("[{a[b]}]") == [{~c"a[b]", ~c"a[b]"}]
      assert ranges("[{a&b}]") == [{~c"a&b", ~c"a&b"}]
      assert ranges("[{[}]") == [{?[, ?[}]
      assert ranges("[{'}]") == [{?', ?'}]
    end

    test "escapes are still honoured" do
      assert ranges("[{a\\}b}]") == [{~c"a}b", ~c"a}b"}]
      assert ranges("[{a\\\\b}]") == [{~c"a\\b", ~c"a\\b"}]
    end

    test "string ranges are unaffected" do
      assert Unicode.Set.to_regex_string("[{ab}-{ad}]") == {:ok, "(?:ab|ac|ad)"}
    end
  end

  describe "Pattern_White_Space (UTS #61 §2)" do
    test "the non-ASCII white-space characters are ignored between elements" do
      assert ranges("[a" <> <<0x2028::utf8>> <> "b]") == [{97, 98}]
      assert ranges("[a" <> <<0x2029::utf8>> <> "b]") == [{97, 98}]
      assert ranges("[" <> <<0x85::utf8>> <> "a]") == [{97, 97}]
    end

    test "a left-to-right mark may separate the parts of a range" do
      assert ranges("[a " <> <<0x200E::utf8>> <> "-z]") == [{97, 122}]
      assert ranges("[a" <> <<0x200F::utf8>> <> "-z]") == [{97, 122}]
    end
  end

  describe "escaped elements (UTS #61 §2.2.1)" do
    test "hexadecimal digits that are not a code point are ill-formed" do
      assert {:error, {_, message}} = Unicode.Set.parse("[\\x{110000}]")
      assert message =~ "not a code point"
      assert {:error, {_, _}} = Unicode.Set.parse("[\\U00110000]")
      assert {:error, {_, _}} = Unicode.Set.parse("[\\u{110000}]")
    end

    test "octal escapes are one to three digits without a leading zero" do
      assert ranges("[\\7]") == [{7, 7}]
      assert ranges("[\\134]") == [{0x5C, 0x5C}]
      assert ranges("[\\0]") == [{0, 0}]
      assert ranges("[\\00]") == [{0, 0}]
      assert ranges("[\\0 0]") == [{0, 0}, {?0, ?0}]
      # maximal munch: three digits, then a literal 4
      assert ranges("[\\1234]") == [{?4, ?4}, {0o123, 0o123}]
      # 8 and 9 are not octal digits, so `\8` is the literal digit
      assert ranges("[\\8]") == [{?8, ?8}]
    end

    test "the standard's U+0007 and U+005C examples all agree" do
      for escape <- ["\\a", "\\7", "\\x7", "\\cG"] do
        assert ranges("[#{escape}]") == [{7, 7}], escape
      end

      for escape <- ["\\\\", "\\134", "\\x5C", "\\u005C", "\\x{05C}", "\\U0000005C"] do
        assert ranges("[#{escape}]") == [{0x5C, 0x5C}], escape
      end
    end

    test "\\c takes @, A-Z, [, backslash, ], ^ or _ and ANDs with 0x1F" do
      assert ranges("[\\c@]") == [{0, 0}]
      assert ranges("[\\cA]") == [{1, 1}]
      assert ranges("[\\cH]") == [{8, 8}]
      assert ranges("[\\c[]") == [{0x1B, 0x1B}]
      assert ranges("[\\c\\]") == [{0x1C, 0x1C}]
      assert ranges("[\\c]]") == [{0x1D, 0x1D}]
      assert ranges("[\\c^]") == [{0x1E, 0x1E}]
      assert ranges("[\\c_]") == [{0x1F, 0x1F}]
      # lowercase is an extension
      assert ranges("[\\cg]") == [{7, 7}]
    end

    test "\\c followed by anything else is an error" do
      for expression <- ["[\\c?]", "[\\c']", "[\\c1]", "[\\c" <> <<0x1226D::utf8>> <> "]"] do
        assert {:error, {_, message}} = Unicode.Set.parse(expression), expression
        assert message =~ "must be followed by one of"
      end
    end

    test "the last code point is still accepted" do
      assert ranges("[\\x{10FFFF}]") == [{0x10FFFF, 0x10FFFF}]
      assert ranges("[\\U0010FFFF]") == [{0x10FFFF, 0x10FFFF}]
    end
  end

  describe "Age queries (UTS #61 §2.5.3.1)" do
    test "Age=X is every code point assigned in version X or earlier" do
      # U+20AC EURO SIGN was assigned in Unicode 2.1
      assert member?("\\p{Age=6.0}", 0x20AC)
      # U+1F600 GRINNING FACE was assigned in Unicode 6.1
      refute member?("\\p{Age=6.0}", 0x1F600)
      assert member?("\\p{Age=6.1}", 0x1F600)
      # Private use, surrogate and noncharacter code points have an age too
      assert member?("\\p{Age=6.0}", 0xE000)
      assert member?("\\p{Age=6.0}", 0xD800)
      assert member?("\\p{Age=6.0}", 0xFFFF)
      assert count("\\p{Age=6.0}") > count("\\p{Age=5.2}")
    end

    test "leading zeros and trailing zero fields are ignored" do
      expected = ranges("\\p{Age=6.0}")
      assert ranges("\\p{Age=6}") == expected
      assert ranges("\\p{Age=6.0.0}") == expected
      assert ranges("\\p{Age=06.00.00}") == expected
      assert ranges("\\p{Age=V6_0}") == expected
    end

    test "V1_1 is an alias for 1.1, not 11" do
      assert ranges("\\p{Age=v11}") == ranges("\\p{Age=1.1}")
      refute ranges("\\p{Age=v11}") == ranges("\\p{Age=11}")
    end

    test "Unassigned (NA) is every code point without an age" do
      assert ranges("\\p{Age=Unassigned}") == ranges("\\p{Age=NA}")
      assert count("[\\p{Age=18.0}\\p{Age=NA}]") == 0x110000
      assert count("[\\p{Age=18.0}&\\p{Age=NA}]") == 0
    end

    test "a version that is not a Unicode version is an error" do
      assert {:error, {_, message}} = Unicode.Set.parse("\\p{Age=5.99.99}")
      assert message =~ "is not known"
    end
  end
end
