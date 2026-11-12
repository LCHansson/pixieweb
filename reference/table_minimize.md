# Remove monotonous columns from a table tibble

Remove monotonous columns from a table tibble

## Usage

``` r
table_minimize(table_df, remove_monotonous_data = TRUE)
```

## Arguments

- table_df:

  A tibble returned by
  [`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md).

- remove_monotonous_data:

  Remove columns where all values are identical.

## Value

A tibble.

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {
  get_tables(scb, query = "population") |> table_minimize()
}# }
#> # A tibble: 319 × 10
#>    id    title updated first_period last_period time_unit variables subject_code
#>    <chr> <chr> <chr>   <chr>        <chr>       <chr>     <list>    <chr>       
#>  1 TAB4… Popu… 2026-0… 1960         2024        Annual    <list>    MI          
#>  2 TAB6… Popu… 2026-1… 2025M01      2026M09     Monthly   <list>    BE          
#>  3 TAB1… Popu… 2025-0… 2000M01      2024M12     Monthly   <list>    BE          
#>  4 TAB6… Popu… 2026-1… 2025         2026        Annual    <list>    BE          
#>  5 TAB5… Popu… 2025-0… 2000         2024        Annual    <list>    BE          
#>  6 TAB4… Popu… 2026-0… 2000         2024        Annual    <list>    MI          
#>  7 TAB4… Gain… 2022-0… 2015         2020        Annual    <list>    MI          
#>  8 TAB4… Popu… 2026-0… 2000         2024        Annual    <list>    MI          
#>  9 TAB4… Popu… 2022-1… 2000         2020        Annual    <list>    MI          
#> 10 TAB3… Popu… 2025-1… 1993         2024        Annual    <list>    UF          
#> # ℹ 309 more rows
#> # ℹ 2 more variables: subject_path <chr>, source <chr>
```
