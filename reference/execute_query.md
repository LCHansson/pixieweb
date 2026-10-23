# Execute a composed query

Low-level function to execute a query built with
[`compose_data_query()`](https://lchansson.github.io/pixieweb/reference/compose_data_query.md).
Handles rate limiting, retries, and error handling.

## Usage

``` r
execute_query(api, url, body = NULL, verbose = FALSE)
```

## Arguments

- api:

  A `<px_api>` object.

- url:

  API endpoint URL.

- body:

  JSON body as a list, or `NULL` for GET requests.

- verbose:

  Print request details.

## Value

Parsed JSON as a list, or `NULL` on failure.

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {
  q <- compose_data_query(scb, "TAB638", Region = "0180",
                          ContentsCode = "*", Tid = px_top(3))
  raw <- execute_query(scb, q$url, q$body)
}# }
```
