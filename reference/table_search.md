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
#> # A tibble: 19 × 13
#>    id      title description category updated first_period last_period time_unit
#>    <chr>   <chr> <chr>       <chr>    <chr>   <chr>        <chr>       <chr>    
#>  1 TAB683  Popu… ""          public   2020-1… 2018         2018        Annual   
#>  2 TAB6574 Popu… ""          public   2026-0… 2010         2025        Annual   
#>  3 TAB6570 Popu… ""          public   2026-0… 2010         2025        Annual   
#>  4 TAB6572 Popu… ""          public   2026-0… 2010         2025        Annual   
#>  5 TAB6569 Popu… ""          public   2026-0… 2010         2025        Annual   
#>  6 TAB6571 Popu… ""          public   2026-0… 2010         2025        Annual   
#>  7 TAB5880 Popu… ""          public   2022-1… 2019         2021        Annual   
#>  8 TAB6534 Popu… ""          public   2025-0… 2024         2024        Annual   
#>  9 TAB660  Gain… ""          public   2020-1… 2018         2018        Annual   
#> 10 TAB682  Gain… ""          public   2020-1… 2018         2018        Annual   
#> 11 TAB5843 Gain… ""          public   2022-1… 2019         2021        Annual   
#> 12 TAB6091 Pass… "NULL"      public   2024-0… 2015         2023        Annual   
#> 13 TAB6589 Pass… "NULL"      public   2026-0… 2024         2025        Annual   
#> 14 TAB5956 Popu… ""          public   2024-0… 2015         2023        Annual   
#> 15 TAB5842 Gain… ""          public   2022-1… 2019         2021        Annual   
#> 16 TAB1744 Inco… ""          public   2015-1… 1995         2013        Annual   
#> 17 TAB947  Fami… ""          public   2015-1… 1995         2013        Annual   
#> 18 TAB939  Fami… ""          public   2015-1… 1995         2013        Annual   
#> 19 TAB4594 Muni… ""          public   2025-1… 2015         2024        Annual   
#> # ℹ 5 more variables: variables <list>, subject_code <chr>, subject_path <chr>,
#> #   source <chr>, discontinued <lgl>
```
