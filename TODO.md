* [ ] String ranges {ab}-{cd}
* [ ] Intersection and Difference and Union of string ranges

Online checker: https://unicode.org/cldr/utility/list-unicodeset.jsp?a=%5B%7Bab%7D-%7Bcd%7D%5D&g=&i=


# Starting point for enumerating string
# ranges

for(x <- '👦🏻', do: for(y <- '👦🏿', do: [x, y]))

[a, b] = Enum.zip('ab', 'cd') |> Enum.map(&Tuple.to_list/1) |> Enum.map(fn [x, y] -> x..y end)
for(x <- a, y <- b, do: [x, y]) |> Enum.map(&List.to_string/1)

a = quote, do: x <- a
b = quote, do: y <- b