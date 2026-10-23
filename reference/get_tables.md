# Get tables from a PX-Web API

Search for and list statistical tables available on a PX-Web instance.

## Usage

``` r
get_tables(
  api,
  query = NULL,
  id = NULL,
  updated_since = NULL,
  max_results = NULL,
  .timeout = 15,
  cache = FALSE,
  cache_location = pixieweb_cache_dir,
  verbose = FALSE
)
```

## Arguments

- api:

  A `<px_api>` object.

- query:

  Free-text search string (sent to API as server-side search). On v2
  APIs (e.g. SCB) the server-side search is an **exact token match** by
  default — `query = "befolk"` will not find tables with "befolkning" in
  the title. Use explicit wildcards (`query = "befolk*"`) for prefix
  matching. Only *trailing* wildcards are reliably supported: SCB's v2
  search rejects a wildcard at the start of a term (`*arbets*`) with an
  HTTP 500, and pixieweb raises an informative error when that happens.
  For contains-style matching, fetch a broader set and filter
  client-side with
  [`table_search()`](https://lchansson.github.io/pixieweb/reference/table_search.md).
  This is a property of the PX-Web server, not pixieweb; behaviour may
  vary by agency. Case-insensitive. Non-ASCII characters (å/ä/ö etc.)
  are URL-encoded automatically. Note also that v2 search does not index
  legacy subject-area codes ("MI0107"): search in clear text and filter
  on the `subject_code` column instead.

- id:

  Character vector of specific table IDs to retrieve.

- updated_since:

  Only return tables updated in the last N days (integer).

- max_results:

  Maximum number of tables to return.

- .timeout:

  Maximum seconds to spend on v1 hierarchy tree walks (default 15). Only
  relevant when a v1 API lacks a `?query=` search endpoint and must fall
  back to walking the folder tree. Increase for exhaustive searches on
  large APIs. Has no effect on v2 APIs (which have native search).

- cache:

  Logical, cache results locally.

- cache_location:

  Cache directory. Defaults to
  [`pixieweb_cache_dir()`](https://lchansson.github.io/pixieweb/reference/pixieweb_cache_dir.md).

- verbose:

  Print request details.

## Value

A tibble with columns: `id`, `title`, `description`, `category`,
`updated`, `first_period`, `last_period`, `time_unit`, `variables`,
`subject_code`, `subject_path`, `source`, `discontinued`.

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {

  # Server-side search
  get_tables(scb, query = "population")

  # Fetch specific tables by ID
  get_tables(scb, id = c("TAB638", "TAB1278"))

  # Tables updated in the last 30 days
  get_tables(scb, updated_since = 30)
}# }
#> # A tibble: 357 × 13
#>    id      title description category updated first_period last_period time_unit
#>    <chr>   <chr> <chr>       <chr>    <chr>   <chr>        <chr>       <chr>    
#>  1 TAB6964 Expo… ""          public   2026-0… 2026M01      2026M07     Monthly  
#>  2 TAB6966 Impo… ""          public   2026-0… 2026M01      2026M07     Monthly  
#>  3 TAB6990 Trad… ""          public   2026-1… 2025         2025        Annual   
#>  4 TAB1872 Indu… ""          public   2026-1… 2000M01      2026M08     Monthly  
#>  5 TAB1710 Orde… ""          public   2026-1… 2000M01      2026M08     Monthly  
#>  6 TAB1693 Turn… ""          public   2026-1… 2000M01      2026M08     Monthly  
#>  7 TAB4894 Prod… ""          public   2026-1… 2010M01      2026M08     Monthly  
#>  8 TAB4335 Inco… ""          public   2026-1… 2012         2024        Annual   
#>  9 TAB4366 Inco… ""          public   2026-1… 2012         2024        Annual   
#> 10 TAB4379 Inco… ""          public   2026-1… 2012         2024        Annual   
#> # ℹ 347 more rows
#> # ℹ 5 more variables: variables <list>, subject_code <chr>, subject_path <chr>,
#> #   source <chr>, discontinued <lgl>
```
