# Generate a citation for downloaded data

Produces a citation string from metadata attached to data by
[`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md).

## Usage

``` r
px_cite(data_df)
```

## Arguments

- data_df:

  A tibble returned by
  [`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md).

## Value

A character string (formatted citation).

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {
  d <- get_data(scb, "TAB638", Region = "0180", ContentsCode = "*",
                Tid = px_top(3))
  px_cite(d)
}# }
#> [1] "Statistics Sweden (SCB). Table: TAB638. Retrieved via pixieweb on 2026-10-23."
```
