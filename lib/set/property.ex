defmodule Unicode.Set.Property do
  @moduledoc false

  @doc false
  def fetch_property(:script_or_category, value) do
    range_list =
      Unicode.Script.get(value) ||
        Unicode.GeneralCategory.get(value) ||
        Unicode.Property.get(value)

    if range_list do
      {:ok, range_list}
    else
      {:error, "the unicode script, category or property #{inspect(value)} is not known"}
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
         "the unicode property #{inspect(property)} with value #{inspect(value)} is not known"}
    end
  end
end
