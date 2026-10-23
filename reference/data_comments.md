# Extract comments from data

Extract comments from data

## Usage

``` r
data_comments(data_df)
```

## Arguments

- data_df:

  A tibble returned by
  [`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md)
  with `.comments = TRUE`.

## Value

A tibble with columns `variable`, `value`, `comment`, or `NULL`.

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {
  d <- get_data(scb, "TAB638", Region = "0180", ContentsCode = "*",
                Tid = px_top(3), .comments = TRUE)
  data_comments(d)
}# }
#> NULL
```
