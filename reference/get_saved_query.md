# Execute a saved query

PX-Web v2 saved queries are server-side stored query definitions
(table + variable selections) that can be shared via ID/URL.

## Usage

``` r
get_saved_query(
  api,
  query_id,
  .output = "long",
  simplify = TRUE,
  verbose = FALSE
)
```

## Arguments

- api:

  A `<px_api>` object.

- query_id:

  Saved query ID (character).

- .output:

  `"long"` (default) or `"wide"`.

- simplify:

  Add text label columns.

- verbose:

  Print request details.

## Value

A tibble in the same format as
[`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md).

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {
  get_saved_query(scb, "some-query-id")
}# }
#> Warning: PX-Web API returned HTTP 404 for: https://statistikdatabasen.scb.se/api/v2/savedqueries/some-query-id/data?lang=en&outputFormat=json-stat2
#> NULL
```
