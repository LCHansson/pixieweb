# Client-side search on a table tibble

Filter an already-fetched table tibble by regex. Complements
`get_tables(query = ...)` which does server-side search. Use this for
further refinement on cached results.

## Usage

``` r
table_search(table_df, query, column = NULL)
```

## Arguments

- table_df:

  A tibble returned by
  [`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md).

- query:

  Character vector of search terms (combined with OR).

- column:

  Column names to search. `NULL` searches all character columns.

## Value

A filtered tibble.

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {
  tables <- get_tables(scb, query = "population")

  # Further filter by regex
  tables |> table_search("municipality")
}# }
#> # A tibble: 26 × 13
#>    id      title description category updated first_period last_period time_unit
#>    <chr>   <chr> <chr>       <chr>    <chr>   <chr>        <chr>       <chr>    
#>  1 TAB6574 Popu… ""          public   2026-0… 2010         2025        Annual   
#>  2 TAB6570 Popu… ""          public   2026-0… 2010         2025        Annual   
#>  3 TAB6572 Popu… ""          public   2026-0… 2010         2025        Annual   
#>  4 TAB6569 Popu… ""          public   2026-0… 2010         2025        Annual   
#>  5 TAB6571 Popu… ""          public   2026-0… 2010         2025        Annual   
#>  6 TAB6534 Popu… ""          public   2026-0… 2024         2025        Annual   
#>  7 TAB5956 Popu… ""          public   2024-0… 2015         2023        Annual   
#>  8 TAB683  Popu… ""          public   2020-1… 2018         2018        Annual   
#>  9 TAB5880 Popu… ""          public   2022-1… 2019         2021        Annual   
#> 10 TAB660  Gain… ""          public   2020-1… 2018         2018        Annual   
#> # ℹ 16 more rows
#> # ℹ 5 more variables: variables <list>, subject_code <chr>, subject_path <chr>,
#> #   source <chr>, discontinued <lgl>
```
