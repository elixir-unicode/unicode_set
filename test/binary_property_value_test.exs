defmodule Unicode.Set.BinaryPropertyValueTest do
  use ExUnit.Case, async: true

  # A binary property may be written bare or with an explicit boolean value.
  # UTS #18 treats the two as equivalent; a false value selects the complement.
  # The Unicode segmentation state machine data files use the `=True` form.

  describe "binary properties with an explicit boolean value" do
    test "an affirmative value matches the bare property" do
      {:ok, bare} = Unicode.Set.parse_and_reduce("[\\p{Extended_Pictographic}]")

      for value <- ~w(True T Yes Y true t yes y) do
        {:ok, explicit} = Unicode.Set.parse_and_reduce("[\\p{Extended_Pictographic=#{value}}]")
        assert explicit.parsed == bare.parsed
      end
    end

    test "a negative value selects the complement" do
      {:ok, affirmative} = Unicode.Set.parse_and_reduce("[\\p{Extended_Pictographic=True}]")
      {:ok, negative} = Unicode.Set.parse_and_reduce("[\\p{Extended_Pictographic=False}]")

      refute affirmative.parsed == negative.parsed
      assert {:in, [{0x0, _} | _]} = negative.parsed
    end

    test "an unknown value is an error, not a match" do
      assert {:error, {_module, message}} =
               Unicode.Set.parse_and_reduce("[\\p{Extended_Pictographic=Maybe}]")

      assert message =~ "is not known"
    end

    test "an unknown binary property is still an error" do
      assert {:error, _} = Unicode.Set.parse_and_reduce("[\\p{Not_A_Property=True}]")
    end
  end

  describe "property values defaulted by a UCD @missing annotation" do
    test "the Other value of a segmentation property resolves" do
      for expr <- [
            "[\\p{Grapheme_Cluster_Break=Other}]",
            "[\\p{Word_Break=Other}]",
            "[\\p{Sentence_Break=Other}]"
          ] do
        assert {:ok, _} = Unicode.Set.parse_and_reduce(expr)
      end
    end

    test "the age alias form resolves to the same set as the numeric form" do
      {:ok, alias_form} = Unicode.Set.parse_and_reduce("[\\p{age=V18_0}]")
      {:ok, numeric_form} = Unicode.Set.parse_and_reduce("[\\p{age=18.0}]")
      assert alias_form.parsed == numeric_form.parsed
    end
  end
end
