require Unicode.Set

Benchee.run(%{
  "Unicode.Set"  => fn -> Unicode.Set.match?(?A, "[\\p{Lu}\\p{Ll}]") end,
  "Regex" => fn -> Regex.match?(~r/\p{Lu}\p{Ll}/u, "A") end
  })