defmodule Unicode.Set.Property do
  @moduledoc false

  @doc false
  def property(:script_or_category, :alpha) do
    Unicode.Set.parse("\\p{Alphabetic}")
  end

  def property(:script_or_category, :lower) do
    Unicode.Set.parse("\\p{Lowercase}")
  end

  def property(:script_or_category, :upper) do
    Unicode.Set.parse("\\p{Uppercase}")
  end

  def property(:script_or_category, :punct) do
    Unicode.Set.parse("\\p{gc=Punctuation}\\p{gc=Symbol}-\\p{alpha}")
  end

  def property(:script_or_category, :digit) do
    Unicode.Set.parse("\\p{gc=Decimal_Number}")
  end

  def property(:script_or_category, :xdigit) do
    Unicode.Set.parse("\\p{gc=Decimal_Number}\\p{Hex_Digit}")
  end

  def property(:script_or_category, :alnum) do
    Unicode.Set.parse("\\p{alpha}\\p{digit}")
  end

  def property(:script_or_category, :space) do
    Unicode.Set.parse("\\p{Whitespace}")
  end

  def property(:script_or_category, :blank) do
    Unicode.Set.parse("[\\p{gc=Space_Separator}\t]")
  end

  def property(:script_or_category, :cntrl) do
    Unicode.Set.parse("\\p{gc=Control}")
  end

  def property(:script_or_category, :print) do
    Unicode.Set.parse("\\p{graph}\\p{blank}-\\p{cntrl}")
  end

  def property(:script_or_category, :word) do
    Unicode.Set.parse("\\p{alpha}\\p{gc=Mark}\\p{digit}\\p{gc=Connector_Punctuation}\\p{Join_Control}")
  end

  def property(:script_or_category, :graph) do
    Unicode.Set.parse("[^\\p{space}\\p{gc=Control}\\p{gc=Surrogate}\\p{gc=Unassigned}]")
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

  @doc false
  def fetch_property(property, value) do
    with {:ok, module} <- Unicode.fetch_property(property),
         {:ok, range_list} <- module.fetch(value) do
      {:ok, range_list}
    else
      :error ->
        {:error,
         "The unicode property #{inspect(property)} with value #{inspect(value)} is not known"}
    end
  end

  def fetch_property!(property, value) do
    case fetch_property(property, value) do
      {:ok, range_list} -> {:ok, range_list}
      {:error, reason} -> raise Regex.CompileError, reason
    end
  end



end
