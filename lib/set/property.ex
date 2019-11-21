defmodule Unicode.Set.Property do
  @moduledoc false

  def fetch_property(:script_or_category, value) do
    with return <- Unicode.Script.fetch(value),
         {:ok, range_list} <- maybe(return, value, &Unicode.Category.fetch/1) do
      {:ok, range_list}
    end
  end

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

  defp maybe({:ok, range_list}, _value, _fun) do
    {:ok, range_list}
  end

  defp maybe(:error, value, fun) do
    with {:ok, range_list} <- fun.(value) do
      {:ok, range_list}
    else
      _ -> {:error, "the unicode script or category #{inspect(value)} is not known"}
    end
  end
end
