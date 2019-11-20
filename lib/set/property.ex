defmodule Unicode.Set.Property do

  # Known script names in Unicode
  script_names =
    Unicode.Script.known_scripts()
    |> Enum.map(fn k -> {String.downcase(String.replace(k, " ", "_")), k} end)
    |> Map.new

  # Known block names in Unicode
  block_names =
    Unicode.Block.known_blocks()
    |> Enum.map(fn k -> {String.downcase(String.replace(Atom.to_string(k), " ", "_")), k} end)
    |> Map.new

  # Known category names in Unicode
  category_names =
    Unicode.Category.known_categories()
    |> Enum.map(fn k -> {String.downcase(Atom.to_string(k)), k} end)
    |> Map.new

  # Known ccc names in Unicode
  ccc_names =
    Unicode.CombiningClass.known_combining_classes()
    |> Enum.map(fn k -> {String.downcase(Integer.to_string(k)), k} end)
    |> Map.new

  def fetch_property("block", value) do
    case Map.fetch(unquote(Macro.escape(block_names)), value) do
      {:ok, value} -> {:ok, {:block, value}}
      :error -> {:error, "the unicode block #{inspect value} is not known"}
    end
  end

  def fetch_property("script", value) do
    case Map.fetch(unquote(Macro.escape(script_names)), value) do
      {:ok, value} -> {:ok, {:script, value}}
      :error -> {:error, "the unicode script #{inspect value} is not known"}
    end
  end

  def fetch_property("category", value) do
    case Map.fetch(unquote(Macro.escape(category_names)), value) do
      {:ok, value} -> {:ok, {:category, value}}
      :error -> {:error, "the unicode category #{inspect value} is not known"}
    end
  end

  def fetch_property("general_category", value) do
    fetch_property("category", value)
  end

  def fetch_property("ccc", value) do
    case Map.fetch(unquote(Macro.escape(ccc_names)), value) do
      {:ok, value} -> {:ok, {:ccc, value}}
      :error -> {:error, "the unicode canonical combining class #{inspect value} is not known"}
    end
  end

  def fetch_property(:script_or_category, value) do
    with return <- fetch_property("script", value),
         {:ok, {property, value}} <- maybe(return, value, fn -> fetch_property("category", value) end) do
      {:ok, {property, value}}
    end
  end

  defp maybe({:ok, value}, _value, _fun) do
    {:ok, value}
  end

  defp maybe({:error, _reason}, value, fun) do
    with {:ok, return} <- fun.() do
      {:ok, return}
    else
      _ -> {:error, "the unicode script or category #{inspect value} is not known"}
    end
  end
end