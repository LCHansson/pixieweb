# Compose a table query URL

Build the URL for querying the tables endpoint (advanced use).

## Usage

``` r
compose_table_query(
  api,
  query = NULL,
  id = NULL,
  updated_since = NULL,
  page = NA,
  per_page = NA
)
```

## Arguments

- api:

  A `<px_api>` object.

- query:

  Free-text search string.

- id:

  Table ID(s).

- updated_since:

  Days since last update.

- page:

  Page number. A single positive whole number, or `NA` (default) to
  leave the parameter out.

- per_page:

  Results per page. A single positive whole number, or `NA` (default) to
  leave the parameter out. `Inf` is not a legal page size — use
  [`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md),
  which paginates transparently.

## Value

A character URL string. All parameter values are percent-encoded, so
multi-word and non-ASCII queries produce a valid URL.

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {
  compose_table_query(scb, query = "population")
}# }
#> [1] "https://api.scb.se/ov0104/v2beta/api/v2/tables?lang=en&query=population"
```
