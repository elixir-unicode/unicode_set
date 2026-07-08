defmodule Unicode.Set.ParserTest do
  use ExUnit.Case, async: true

  defp parse(set), do: Unicode.Set.parse(set)
  defp reduce(set), do: Unicode.Set.parse_and_reduce(set)

  describe "basic sets and ranges" do
    test "a single character" do
      assert {:ok, %Unicode.Set{}} = parse("[a]")
    end

    test "a character range" do
      assert {:ok, set} = reduce("[a-z]")
      assert {:in, [{?a, ?z}]} = set.parsed
    end

    test "a union of individual characters" do
      assert {:ok, set} = reduce("[abc]")
      assert {:in, [{?a, ?c}]} = set.parsed
    end

    test "the empty set [-]" do
      assert {:ok, %Unicode.Set{}} = parse("[-]")
    end

    test "an escaped syntax character" do
      assert {:ok, _} = parse("[\\:]")
      assert {:ok, _} = parse("[\\-]")
      assert {:ok, _} = parse("[\\[\\]]")
    end
  end

  describe "quoted / escaped characters" do
    test "control-character escapes" do
      require Unicode.Set
      assert Unicode.Set.match?(?\n, "[\\n]")
      assert Unicode.Set.match?(?\t, "[\\t]")
      assert Unicode.Set.match?(?\r, "[\\r]")
    end

    test "four digit \\u hex" do
      assert {:ok, set} = reduce("[\\u0041]")
      assert {:in, [{?A, ?A}]} = set.parsed
    end

    test "two digit \\x hex" do
      assert {:ok, set} = reduce("[\\x41]")
      assert {:in, [{?A, ?A}]} = set.parsed
    end

    test "bracketed \\u{...} hex" do
      assert {:ok, set} = reduce("[\\u{1F600}]")
      assert {:in, [{0x1F600, 0x1F600}]} = set.parsed

      # multi-codepoint bracketed escapes are not (yet) supported
      assert {:error, _} = parse("[\\u{41 42}]")
    end
  end

  describe "posix properties" do
    test "positive posix property" do
      assert {:ok, %Unicode.Set{}} = parse("[:Lu:]")
    end

    test "negated posix property" do
      assert {:ok, set} = reduce("[:^Lu:]")
      assert {:not_in, _} = set.parsed
    end

    test "block via Is prefix" do
      assert {:ok, %Unicode.Set{}} = parse("[:IsBasicLatin:]")
    end

    test "property = value syntax" do
      assert {:ok, %Unicode.Set{}} = parse("[:block=BasicLatin:]")
    end
  end

  describe "perl properties" do
    test "positive perl property" do
      assert {:ok, %Unicode.Set{}} = parse("\\p{Lu}")
    end

    test "negated perl property with capital P" do
      assert {:ok, set} = reduce("\\P{Lu}")
      assert {:not_in, _} = set.parsed
    end

    test "perl property = value" do
      assert {:ok, %Unicode.Set{}} = parse("\\p{gc=Lu}")
    end

    test "perl block via Is prefix" do
      assert {:ok, %Unicode.Set{}} = parse("\\p{IsBasicLatin}")
    end
  end

  describe "set operations" do
    test "union of nested sets" do
      assert {:ok, %Unicode.Set{}} = parse("[[abc][def]]")
    end

    test "intersection" do
      assert {:ok, set} = reduce("[[a-m]&[h-z]]")
      assert {:in, [{?h, ?m}]} = set.parsed
    end

    test "difference" do
      assert {:ok, set} = reduce("[[a-z]-[a-c]]")
      assert {:in, [{?d, ?z}]} = set.parsed
    end

    test "complement of a set" do
      assert {:ok, set} = reduce("[^abc]")
      assert {:not_in, _} = set.parsed
    end

    test "complement of a complement round trips" do
      assert {:ok, set} = reduce("[^[^abc]]")
      assert {:in, _} = set.parsed
    end
  end

  describe "string ranges" do
    test "a single string range element" do
      assert {:ok, _} = parse("[{ab}]")
    end

    test "a string range {ab}-{cd}" do
      assert {:ok, _} = parse("[{ab}-{cd}]")
    end

    test "a one-character string range is rejected" do
      assert {:error, {Unicode.Set.ParseError, message}} = parse("[{a}-{cd}]")
      assert message =~ "String ranges must be longer than one character"
    end
  end

  describe "errors" do
    test "unknown posix property" do
      assert {:error, {Unicode.Set.ParseError, message}} = parse("[:zzzz:]")
      assert message =~ "is not known"
    end

    test "unknown perl property" do
      assert {:error, {Unicode.Set.ParseError, _}} = parse("[\\p{zzzz}]")
    end
  end
end
