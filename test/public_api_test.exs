defmodule Unicode.Set.PublicApiTest do
  use ExUnit.Case, async: true

  describe "parse!/1" do
    test "returns a struct on success" do
      assert %Unicode.Set{} = Unicode.Set.parse!("[abc]")
    end

    test "raises a ParseError on failure" do
      assert_raise Unicode.Set.ParseError, fn ->
        Unicode.Set.parse!("[:zzzz:]")
      end
    end
  end

  describe "parse_and_reduce!/1" do
    test "returns a reduced struct on success" do
      set = Unicode.Set.parse_and_reduce!("[abc]")
      assert set.state == :reduced
    end

    test "raises on failure" do
      assert_raise Unicode.Set.ParseError, fn ->
        Unicode.Set.parse_and_reduce!("[:zzzz:]")
      end
    end
  end

  describe "to_pattern/1 and to_pattern!/1" do
    test "to_pattern/1 returns an ok tuple" do
      assert {:ok, ["a", "b", "c"]} = Unicode.Set.to_pattern("[abc]")
    end

    test "to_pattern!/1 returns the pattern directly" do
      assert ["a", "b", "c"] = Unicode.Set.to_pattern!("[abc]")
    end

    test "to_pattern!/1 raises on an invalid set" do
      assert_raise Unicode.Set.ParseError, fn ->
        Unicode.Set.to_pattern!("[:zzzz:]")
      end
    end
  end

  describe "compile_pattern/1 and compile_pattern!/1" do
    test "compile_pattern/1 returns a compiled pattern usable by String.split/2" do
      {:ok, pattern} = Unicode.Set.compile_pattern("[[:digit:]]")
      assert String.split("a1b2c3", pattern) == ["a", "b", "c", ""]
    end

    test "compile_pattern!/1 returns the compiled pattern directly" do
      pattern = Unicode.Set.compile_pattern!("[abc]")
      assert String.split("xaybzc", pattern) == ["x", "y", "z", ""]
    end

    test "compile_pattern!/1 raises on an invalid set" do
      assert_raise Unicode.Set.ParseError, fn ->
        Unicode.Set.compile_pattern!("[:zzzz:]")
      end
    end
  end

  describe "to_utf8_char/1 and to_utf8_char!/1" do
    test "to_utf8_char/1 returns an ok tuple of ranges" do
      assert {:ok, [{:not, 97..100}]} = Unicode.Set.to_utf8_char("[^abcd]")
    end

    test "to_utf8_char!/1 returns the ranges directly" do
      assert [97..99] = Unicode.Set.to_utf8_char!("[abc]")
    end

    test "to_utf8_char!/1 raises on an invalid set" do
      assert_raise Unicode.Set.ParseError, fn ->
        Unicode.Set.to_utf8_char!("[:zzzz:]")
      end
    end
  end

  describe "to_regex_string/1 and to_regex_string!/1" do
    test "to_regex_string/1 returns an ok tuple" do
      assert {:ok, "[\\x{61}-\\x{63}]"} = Unicode.Set.to_regex_string("[abc]")
    end

    test "to_regex_string!/1 returns the string directly" do
      assert "[\\x{61}-\\x{63}]" = Unicode.Set.to_regex_string!("[abc]")
    end

    test "to_regex_string!/1 raises on an invalid set" do
      assert_raise Unicode.Set.ParseError, fn ->
        Unicode.Set.to_regex_string!("[:zzzz:]")
      end
    end

    test "negative set with string ranges is rejected" do
      assert {:error, {Unicode.Set.ParseError, _}} =
               Unicode.Set.to_regex_string("[^{ab}]")
    end

    test "positive string ranges expand to alternation" do
      assert {:ok, regex} = Unicode.Set.to_regex_string("[{ab}{cd}]")
      assert regex =~ "ab"
      assert regex =~ "cd"
    end
  end

  describe "generate_matches/2" do
    test "returns a guard plus strings for a mixed set" do
      assert {:ok, matches} = Unicode.Set.generate_matches("[abc{de}]", quote(do: var))
      assert is_list(matches)
      assert "de" in matches
    end

    test "returns only strings when there is no character guard" do
      assert {:ok, ["de"]} = Unicode.Set.generate_matches("[{de}]", quote(do: var))
    end

    test "propagates parse errors" do
      assert {:error, {Unicode.Set.ParseError, _}} =
               Unicode.Set.generate_matches("[:zzzz:]", quote(do: var))
    end
  end

  describe "match?/2 outside a guard" do
    test "matches a codepoint against a set at runtime" do
      require Unicode.Set
      assert Unicode.Set.match?(?๓, "[[:digit:]]")
      refute Unicode.Set.match?(?a, "[[:digit:]]")
    end

    test "matches a string by its leading codepoint" do
      require Unicode.Set
      assert Unicode.Set.match?("3abc", "[[:digit:]]")
      refute Unicode.Set.match?("abc", "[[:digit:]]")
    end

    test "matches a string against the complement of a set" do
      require Unicode.Set
      assert Unicode.Set.match?("abc", "[^[:digit:]]")
      refute Unicode.Set.match?("3abc", "[^[:digit:]]")
    end

    test "raises when the set is not a compile-time binary" do
      require Unicode.Set

      assert_raise ArgumentError, fn ->
        Code.eval_quoted(
          quote do
            require Unicode.Set
            set = "[abc]"
            Unicode.Set.match?(?a, set)
          end
        )
      end
    end
  end
end
