defimpl String.Chars, for: Unicode.Set do
  def to_string(%Unicode.Set{set: set}) do
    set
  end
end

defimpl Inspect, for: Unicode.Set do
  def inspect(%Unicode.Set{set: set}, _) do
    "#Unicode.Set<" <> set <> ">"
  end
end
