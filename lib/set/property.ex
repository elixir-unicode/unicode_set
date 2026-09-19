defmodule Unicode.Set.Property do
  @moduledoc false

  # Of this list, only the following are unknown to Unicode
  # * xdigit
  # * word
  # * blank
  # * print
  # * alnum

  @doc false
  def fetch_property(:script_or_category, "alpha") do
    {:ok, Unicode.Set.parse!("\\p{Alphabetic}")}
  end

  def fetch_property(:script_or_category, "lower") do
    {:ok, Unicode.Set.parse!("\\p{Lowercase}")}
  end

  def fetch_property(:script_or_category, "upper") do
    {:ok, Unicode.Set.parse!("\\p{Uppercase}")}
  end

  # `punct` uses the UTS #18 Annex C "POSIX-compatible" definition
  # (`gc=Punctuation` + `gc=Symbol` - `alpha`, ~9,300 codepoints), which matches
  # ICU's POSIX `[:punct:]` and the behaviour most POSIX tooling expects.
  #
  # Tradeoff: this deliberately deviates from the UTS #18 *Standard* recommendation,
  # which is just `gc=Punctuation` (~850 codepoints). The POSIX definition includes
  # symbols such as `+ $ < = > ^ | ~` \`` that the Standard definition excludes.
  # We keep POSIX behaviour for ICU/POSIX compatibility; callers wanting the
  # Standard set should use `\p{gc=Punctuation}` explicitly. See the README
  # "Compatibility Property Names" section.
  def fetch_property(:script_or_category, "punct") do
    {:ok, Unicode.Set.parse!("[\\p{gc=Punctuation}\\p{gc=Symbol}-\\p{alpha}]")}
  end

  def fetch_property(:script_or_category, "digit") do
    {:ok, Unicode.Set.parse!("\\p{gc=Decimal_Number}")}
  end

  def fetch_property(:script_or_category, "xdigit") do
    {:ok, Unicode.Set.parse!("[\\p{gc=Decimal_Number}\\p{Hex_Digit}]")}
  end

  def fetch_property(:script_or_category, "alnum") do
    {:ok, Unicode.Set.parse!("[\\p{alpha}\\p{digit}]")}
  end

  def fetch_property(:script_or_category, "space") do
    {:ok, Unicode.Set.parse!("\\p{Whitespace}")}
  end

  def fetch_property(:script_or_category, "blank") do
    {:ok, Unicode.Set.parse!("[\\p{gc=Space_Separator}\\t]")}
  end

  def fetch_property(:script_or_category, "cntrl") do
    {:ok, Unicode.Set.parse!("\\p{gc=Control}")}
  end

  def fetch_property(:script_or_category, "print") do
    {:ok, Unicode.Set.parse!("[\\p{graph}\\p{blank}-\\p{cntrl}]")}
  end

  def fetch_property(:script_or_category, "word") do
    {:ok,
     Unicode.Set.parse!(
       "[\\p{alpha}\\p{gc=Mark}\\p{digit}\\p{gc=Connector_Punctuation}\\p{Join_Control}]"
     )}
  end

  def fetch_property(:script_or_category, "graph") do
    {:ok,
     Unicode.Set.parse!("[^\\p{Whitespace}\\p{gc=Control}\\p{gc=Surrogate}\\p{gc=Unassigned}]")}
  end

  def fetch_property(:script_or_category, value) do
    range_list =
      Unicode.Script.get(value) ||
        Unicode.GeneralCategory.get(value) ||
        Unicode.Property.get(value)

    if range_list do
      {:ok, range_list}
    else
      {:error, "The unicode script, category or property #{inspect(value)} is not known"}
    end
  end

  def fetch_property("block" = property, value) do
    case Unicode.Block.fetch(value) do
      {:ok, range_list} ->
        {:ok, range_list}

      :error ->
        {:error,
         "The unicode property #{inspect(property)} with value #{inspect(value)} is not known"}
    end
  end

  # Age is cumulative (UTS #61 §2.5.3.1, as in ICU): `\p{Age=6.0}` is every code
  # point assigned in Unicode 6.0 or earlier, and `\p{Age=Unassigned}` (alias
  # `NA`) is every code point that has no age. A version may be written as its
  # alias (`V6_0`) or as a version number with any number of fields, leading
  # zeros and trailing zero fields being ignored (`6`, `6.0`, `06.00.00`).
  def fetch_property("age" = property, value) do
    case age_version(value) do
      {:ok, :unassigned} ->
        {:ok, Unicode.Utils.difference_ranges([{0x0, 0x10FFFF}], ages_up_to(:all))}

      {:ok, version} ->
        {:ok, ages_up_to(version)}

      :error ->
        {:error,
         "The unicode property #{inspect(property)} with value #{inspect(value)} is not known"}
    end
  end

  # `Name` (`na`) and `Name_Alias` are served by `Unicode.CharacterName` rather
  # than by a property module, so they are dispatched here by name.
  def fetch_property(property, value) do
    case Unicode.Utils.downcase_and_remove_whitespace(property) do
      name when name in ["name", "na"] -> fetch_name(property, value)
      alias when alias in ["namealias", "name_alias"] -> fetch_name_alias(property, value)
      _other -> fetch_enumerated_property(property, value)
    end
  end

  defp fetch_enumerated_property(property, value) do
    with {:ok, module} <- Unicode.fetch_property(property),
         {:ok, range_list} <- fetch_value(module, value) do
      {:ok, range_list}
    else
      :error ->
        fetch_binary_property(property, value)
    end
  end

  # `\p{Name=X}` is the single character whose Name or Name_Alias matches `X`
  # under UAX44-LM2 (UTS #61 §2.5.3.4). An unknown name is not a valid value,
  # so the expression is ill-formed.
  defp fetch_name(property, value) do
    case Unicode.CharacterName.to_codepoint(value) do
      {:ok, codepoint} -> {:ok, [{codepoint, codepoint}]}
      :error -> unknown_value(property, value)
    end
  end

  # `\p{Name_Alias=X}` is the single character one of whose Name_Alias values
  # matches `X`; a value that matches only a Name is not valid.
  defp fetch_name_alias(property, value) do
    normalized = Unicode.Utils.downcase_and_remove_whitespace(value)

    with {:ok, codepoint} <- Unicode.CharacterName.to_codepoint(value),
         true <-
           Enum.any?(Unicode.CharacterName.aliases(codepoint), &alias_matches?(&1, normalized)) do
      {:ok, [{codepoint, codepoint}]}
    else
      _other -> unknown_value(property, value)
    end
  end

  defp alias_matches?({_type, alias}, normalized) do
    Unicode.Utils.downcase_and_remove_whitespace(alias) == normalized
  end

  defp unknown_value(property, value) do
    {:error,
     "The unicode property #{inspect(property)} with value #{inspect(value)} is not known"}
  end

  # `unicode` keys numeric values by number (an integer or a reduced
  # `{numerator, denominator}` tuple), so a Numeric_Value query is parsed as
  # UTS #61 §2.5.3.4 specifies before the lookup. Any other property takes the
  # value as written.
  defp fetch_value(Unicode.NumericValue, value), do: fetch_numeric_value(value)
  defp fetch_value(module, value), do: module.fetch(value)

  @rational ~r/^([+-]?\d+)(?:\/(\d*[1-9]\d*))?$/
  @decimal ~r/^[+-]?\d+\.\d+$/

  # A valid Numeric_Value is `NaN` (the code points with no numeric value), a
  # rational `[+-]?[0-9]+(/[0-9]*[1-9][0-9]*)?` matched by rational equality, or
  # a decimal `[+-]?[0-9]+\.[0-9]+` matched by equality of the binary64
  # roundings. A well-formed value that no character has is the empty set;
  # only a malformed value is an error.
  defp fetch_numeric_value(value) do
    # Not `downcase_and_remove_whitespace/1`, which also strips the `-` that
    # carries the sign of a negative value.
    normalized = value |> String.downcase() |> String.replace(~r/\s/u, "")

    cond do
      normalized == "nan" ->
        {:ok,
         Unicode.Utils.difference_ranges(
           [{0x0, 0x10FFFF}],
           numeric_value_ranges(fn _ -> true end)
         )}

      match = Regex.run(@rational, normalized) ->
        key = rational_key(match)
        {:ok, numeric_value_ranges(&(&1 == key))}

      Regex.match?(@decimal, normalized) ->
        float = String.to_float(String.trim_leading(normalized, "+"))
        {:ok, numeric_value_ranges(&(to_float(&1) == float))}

      true ->
        :error
    end
  end

  defp rational_key([_match, numerator]), do: String.to_integer(numerator)

  defp rational_key([_match, numerator, denominator]) do
    numerator = String.to_integer(numerator)
    denominator = String.to_integer(denominator)
    divisor = Integer.gcd(numerator, denominator)

    case {div(numerator, divisor), div(denominator, divisor)} do
      {numerator, 1} -> numerator
      reduced -> reduced
    end
  end

  defp to_float({numerator, denominator}), do: numerator / denominator
  defp to_float(integer), do: integer * 1.0

  defp numeric_value_ranges(selector) do
    Unicode.NumericValue.numeric_values()
    |> Enum.filter(fn {key, _ranges} -> selector.(key) end)
    |> Enum.flat_map(fn {_key, ranges} -> ranges end)
    |> Enum.sort()
    |> Unicode.Utils.compact_ranges()
  end

  # A binary property can be written bare, as `\p{Extended_Pictographic}`, or with
  # an explicit boolean value, as `\p{Extended_Pictographic=True}`. UTS #18 treats
  # the two as equivalent, and a false value selects the complement. Binary
  # properties are served by `Unicode.Property` rather than by a per-property
  # module, so they do not resolve through `Unicode.fetch_property/1` above.

  @truthy ["true", "t", "yes", "y"]
  @falsy ["false", "f", "no", "n"]

  defp fetch_binary_property(property, value) do
    normalized = Unicode.Utils.downcase_and_remove_whitespace(value)

    with true <- normalized in @truthy or normalized in @falsy,
         {:ok, range_list} <- Unicode.Property.fetch(property) do
      if normalized in @truthy do
        {:ok, range_list}
      else
        {:ok, Unicode.Utils.difference_ranges([{0x0, 0x10FFFF}], range_list)}
      end
    else
      _other ->
        {:error,
         "The unicode property #{inspect(property)} with value #{inspect(value)} is not known"}
    end
  end

  @version_number ~r/^\d+(\.\d+)*$/

  # Resolves an Age value to `{:ok, {major, minor}}`, `{:ok, :unassigned}` or
  # `:error`. Numeric forms are compared field-wise after dropping trailing zero
  # fields, so `6`, `6.0`, `6.0.0` and `06.00.00` all denote Unicode 6.0.
  defp age_version(value) do
    normalized = Unicode.Utils.downcase_and_remove_whitespace(value)

    cond do
      normalized in ["unassigned", "na"] ->
        {:ok, :unassigned}

      Regex.match?(@version_number, normalized) ->
        fields = version_fields(normalized)

        case Enum.find(age_versions(), &(version_fields(Atom.to_string(&1)) == fields)) do
          nil -> :error
          age -> {:ok, version_tuple(age)}
        end

      true ->
        case Map.fetch(Unicode.Age.aliases(), normalized) do
          {:ok, age} -> {:ok, version_tuple(age)}
          :error -> :error
        end
    end
  end

  # The Age values that are version numbers. `unicode` 2.2 and later also carry
  # the `Unassigned` default value as a key, which has no version to compare.
  defp age_versions do
    Enum.filter(Unicode.Age.known_ages(), &Regex.match?(@version_number, Atom.to_string(&1)))
  end

  # The integer fields of a dotted version number with trailing zero fields
  # removed: "06.00.00" -> [6], "1.1" -> [1, 1].
  defp version_fields(version) do
    version
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 == 0))
    |> Enum.reverse()
  end

  defp version_tuple(age) do
    case version_fields(Atom.to_string(age)) do
      [major] -> {major, 0}
      [major, minor | _rest] -> {major, minor}
    end
  end

  # The union of the ranges of every known age less than or equal to `version`,
  # or of every known age when `version` is `:all`.
  defp ages_up_to(version) do
    versions = age_versions()

    Unicode.Age.ages()
    |> Enum.filter(fn {age, _ranges} ->
      age in versions and (version == :all or version_tuple(age) <= version)
    end)
    |> Enum.flat_map(fn {_age, ranges} -> ranges end)
    |> Enum.sort()
    |> Unicode.Utils.compact_ranges()
  end

  def fetch_property!(property, value) do
    case fetch_property(property, value) do
      {:ok, range_list} -> range_list
      {:error, reason} -> raise Regex.CompileError, reason
    end
  end

  @doc false
  # Resolution for the `Is<name>` prefix: try the name as a script, general
  # category or binary property first, and only fall back to a block. Raises a
  # `Regex.CompileError` if the name matches none of them.
  def fetch_script_category_or_block(value) do
    case fetch_property(:script_or_category, value) do
      {:ok, result} -> result
      {:error, _reason} -> fetch_property!("block", value)
    end
  end

  @doc false
  # Resolution for a bare `\p{name}` / `[:name:]`. Tries the name as a script,
  # category or binary property; if that fails and the name has a Java-style
  # `In` prefix, tries the remainder as a block (so `\p{InBasicLatin}` resolves)
  # while leaving genuine `In...` scripts/properties (e.g. `Inherited`) alone,
  # since those already resolve at the script/category/property step.
  def fetch_script_category_or_in_block(value) do
    case fetch_property(:script_or_category, value) do
      {:ok, result} -> result
      {:error, reason} -> fetch_in_block_or_raise(value, reason)
    end
  end

  defp fetch_in_block_or_raise("in" <> block, reason) when block != "" do
    case fetch_property("block", block) do
      {:ok, ranges} -> ranges
      {:error, _} -> raise Regex.CompileError, reason
    end
  end

  defp fetch_in_block_or_raise(_value, reason) do
    raise Regex.CompileError, reason
  end
end
