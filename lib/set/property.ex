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
   {:ok,  Unicode.Set.parse!("\\p{Alphabetic}")}
  end

  def fetch_property(:script_or_category, "lower") do
    {:ok, Unicode.Set.parse!("\\p{Lowercase}")}
  end

  def fetch_property(:script_or_category, "upper") do
    {:ok, Unicode.Set.parse!("\\p{Uppercase}")}
  end

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
    {:ok, Unicode.Set.parse!("[\\p{alpha}\\p{gc=Mark}\\p{digit}\\p{gc=Connector_Punctuation}\\p{Join_Control}]")}
  end

  def fetch_property(:script_or_category, "graph") do
    {:ok, Unicode.Set.parse!("[^\\p{space}\\p{gc=Control}\\p{gc=Surrogate}\\p{gc=Unassigned}]")}
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
      {:ok, range_list} -> range_list
      {:error, reason} -> raise Regex.CompileError, reason
    end
  end

end
