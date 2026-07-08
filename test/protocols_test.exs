defmodule Unicode.Set.ProtocolsTest do
  use ExUnit.Case, async: true

  require Unicode.Set.Sigil
  import Unicode.Set.Sigil

  describe "~u sigil" do
    test "parses a unicode set into a struct" do
      set = ~u"[[:Lu:]&[:thai:]]"
      assert %Unicode.Set{} = set
      assert set.set == "[[:Lu:]&[:thai:]]"
      assert set.state == :parsed
    end

    test "expands set operations at compile time" do
      set = ~u"[[a-z]&[p-z]]"
      assert %Unicode.Set{} = set
      assert set.set == "[[a-z]&[p-z]]"
    end
  end

  describe "String.Chars protocol" do
    test "to_string/1 returns the original set binary" do
      set = ~u"[[:digit:]]"
      assert to_string(set) == "[[:digit:]]"
      assert "#{set}" == "[[:digit:]]"
    end
  end

  describe "Inspect protocol" do
    test "inspect/1 wraps the set binary" do
      set = ~u"[[:digit:]]"
      assert inspect(set) == "#Unicode.Set<[[:digit:]]>"
    end
  end

  describe "Unicode.Set.ParseError" do
    test "exception/1 builds a struct with the message" do
      exception = Unicode.Set.ParseError.exception("boom")
      assert %Unicode.Set.ParseError{message: "boom"} = exception
    end

    test "can be raised and rescued" do
      assert_raise Unicode.Set.ParseError, "boom", fn ->
        raise Unicode.Set.ParseError, "boom"
      end
    end
  end
end
