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
  matching. Wildcards can also appear mid-term (e.g. `*arbets*`). This
  is a property of the PX-Web server, not pixieweb; behaviour may vary
  by agency. Case-insensitive. Non-ASCII characters (å/ä/ö etc.) are
  URL-encoded automatically.

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
#> # A tibble: 322 × 13
#>    id      title description category updated first_period last_period time_unit
#>    <chr>   <chr> <chr>       <chr>    <chr>   <chr>        <chr>       <chr>    
#>  1 TAB1872 Indu… ""          public   2026-0… 2000M01      2026M02     Monthly  
#>  2 TAB4370 Pres… ""          public   2026-0… 2013         2023        Annual   
#>  3 TAB1710 Orde… ""          public   2026-0… 2000M01      2026M02     Monthly  
#>  4 TAB1693 Turn… ""          public   2026-0… 2000M01      2026M02     Monthly  
#>  5 TAB4894 Prod… ""          public   2026-0… 2010M01      2026M02     Monthly  
#>  6 TAB4810 Prod… ""          public   2026-0… 2010K1       2025K4      Quarterly
#>  7 TAB4248 Part… ""          public   2026-0… 2017         2025        Annual   
#>  8 TAB2612 Part… ""          public   2026-0… 2017         2025        Annual   
#>  9 TAB3789 Part… ""          public   2026-0… 2017         2025        Annual   
#> 10 TAB4203 Part… ""          public   2026-0… 2017         2025        Annual   
#> # ℹ 312 more rows
#> # ℹ 5 more variables: variables <list>, subject_code <chr>, subject_path <chr>,
#> #   source <chr>, discontinued <lgl>
```
