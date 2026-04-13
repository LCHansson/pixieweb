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
#> # A tibble: 100 × 9
#>    id    title updated first_period last_period time_unit variables subject_code
#>    <chr> <chr> <chr>   <chr>        <chr>       <chr>     <list>    <chr>       
#>  1 TAB1… Inco… 2015-1… 1995         2013        Annual    <list>    LE          
#>  2 TAB9… Fami… 2015-1… 1995         2013        Annual    <list>    LE          
#>  3 TAB4… Popu… 2025-0… 1960         2023        Annual    <list>    MI          
#>  4 TAB6… Popu… 2026-0… 2025M01      2026M02     Monthly   <list>    BE          
#>  5 TAB1… Popu… 2025-0… 2000M01      2024M12     Monthly   <list>    BE          
#>  6 TAB6… Popu… 2026-0… 2025         2025        Annual    <list>    BE          
#>  7 TAB5… Popu… 2025-0… 2000         2024        Annual    <list>    BE          
#>  8 TAB4… Popu… 2025-0… 2000         2023        Annual    <list>    MI          
#>  9 TAB9… Fami… 2015-1… 1995         2013        Annual    <list>    LE          
#> 10 TAB4… Gain… 2022-0… 2015         2020        Annual    <list>    MI          
#> # ℹ 90 more rows
#> # ℹ 1 more variable: subject_path <chr>
```
