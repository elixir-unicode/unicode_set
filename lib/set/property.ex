defmodule Unicode.Set.Property do
  @moduledoc false

  # Canonical block lookup keyed by the fully normalized (downcased, separator
  # stripped) block name. `Unicode.Block.fetch/1` cannot resolve some blocks
  # whose canonical alias is absent from the dependency's alias table (e.g.
  # digit-bearing names such as "Latin-1 Supplement" -> "latin1supplement"),
  # because on an alias miss it looks the still-string name up against the
  # atom-keyed block map and fails. We rebuild a canonical name -> atom key map
  # directly from `Unicode.Block.blocks/0` so every real block resolves.
  @block_by_canonical_name Unicode.Block.blocks()
                           |> Map.keys()
                           |> Map.new(fn key ->
                             {Unicode.Utils.downcase_and_remove_whitespace(key), key}
                           end)

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

  @doc false
  def fetch_property("block" = property, value) do
    case Unicode.Block.fetch(value) do
      {:ok, range_list} ->
        {:ok, range_list}

      :error ->
        normalized = Unicode.Utils.downcase_and_remove_whitespace(value)

        case Map.fetch(@block_by_canonical_name, normalized) do
          {:ok, block_key} ->
            Unicode.Block.fetch(block_key)

          :error ->
            {:error,
             "The unicode property #{inspect(property)} with value #{inspect(value)} is not known"}
        end
    end
  end

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
      {:ok, result} ->
        result

      {:error, reason} ->
        case value do
          "in" <> block when block != "" ->
            case fetch_property("block", block) do
              {:ok, ranges} -> ranges
              {:error, _} -> raise Regex.CompileError, reason
            end

          _ ->
            raise Regex.CompileError, reason
        end
    end
  end
end
