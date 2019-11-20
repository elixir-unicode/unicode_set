defmodule Unicode.Set.Property do

  def fetch_property("block", value) do
    case Unicode.Block.fetch(value) do
      {:ok, range_list} -> {:ok, range_list}
      :error -> {:error, "the unicode block #{inspect value} is not known"}
    end
  end

  def fetch_property("script", value) do
    case Unicode.Script.fetch(value) do
      {:ok, range_list} -> {:ok, range_list}
      :error -> {:error, "the unicode script #{inspect value} is not known"}
    end
  end

  def fetch_property("category", value) do
    case Unicode.Category.fetch(value) do
      {:ok, range_list} -> {:ok, range_list}
      :error -> {:error, "the unicode category #{inspect value} is not known"}
    end
  end

  def fetch_property("general_category", value) do
    fetch_property("category", value)
  end

  def fetch_property("ccc", value) do
    case Unicode.CombiningClass.fetch(value) do
      {:ok, range_list} -> {:ok, range_list}
      :error -> {:error, "the unicode combining class #{inspect value} is not known"}
    end
  end

  def fetch_property(:script_or_category, value) do
    with return <- Unicode.Script.fetch(value),
         {:ok, range_list} <- maybe(return, value, &Unicode.Category.fetch/1) do
      {:ok, range_list}
    end
  end

  defp maybe({:ok, range_list}, _value, _fun) do
    {:ok, range_list}
  end

  defp maybe(:error, value, fun) do
    with {:ok, range_list} <- fun.(value) do
      {:ok, range_list}
    else
      _ -> {:error, "the unicode script or category #{inspect value} is not known"}
    end
  end
end