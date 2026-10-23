# Remove monotonous columns from a data tibble

Remove monotonous columns from a data tibble

## Usage

``` r
data_minimize(data_df, remove_monotonous_data = TRUE)
```

## Arguments

- data_df:

  A tibble returned by
  [`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md).

- remove_monotonous_data:

  Remove columns where all values are identical.

## Value

A tibble.

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {
  d <- get_data(scb, "TAB638", Region = "0180", ContentsCode = "*",
                Tid = px_top(3))
  d |> data_minimize()
}# }
#> # A tibble: 6 × 5
#>   ContentsCode ContentsCode_text Tid   Tid_text  value
#>   <chr>        <chr>             <chr> <chr>     <dbl>
#> 1 BE0101N1     Population        2022  2022     984748
#> 2 BE0101N1     Population        2023  2023     988943
#> 3 BE0101N1     Population        2024  2024     995574
#> 4 BE0101N2     Population growth 2022  2022       5978
#> 5 BE0101N2     Population growth 2023  2023       4195
#> 6 BE0101N2     Population growth 2024  2024       6631
```
