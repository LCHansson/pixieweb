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
#> # A tibble: 350 × 11
#>    id     title description updated first_period last_period time_unit variables
#>    <chr>  <chr> <chr>       <chr>   <chr>        <chr>       <chr>     <list>   
#>  1 TAB17… Inco… ""          2015-1… 1995         2013        Annual    <list>   
#>  2 TAB934 Fami… ""          2015-1… 1995         2013        Annual    <list>   
#>  3 TAB45… Popu… ""          2025-0… 1960         2023        Annual    <list>   
#>  4 TAB64… Popu… ""          2026-0… 2025M01      2026M02     Monthly   <list>   
#>  5 TAB16… Popu… ""          2025-0… 2000M01      2024M12     Monthly   <list>   
#>  6 TAB64… Popu… ""          2026-0… 2025         2025        Annual    <list>   
#>  7 TAB51… Popu… ""          2025-0… 2000         2024        Annual    <list>   
#>  8 TAB45… Popu… ""          2025-0… 2000         2023        Annual    <list>   
#>  9 TAB938 Fami… ""          2015-1… 1995         2013        Annual    <list>   
#> 10 TAB49… Gain… ""          2022-0… 2015         2020        Annual    <list>   
#> # ℹ 340 more rows
#> # ℹ 3 more variables: subject_code <chr>, subject_path <chr>, source <chr>
```
