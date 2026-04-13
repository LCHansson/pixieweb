# Fetch data from a PX-Web table

The core function for downloading statistical data. Variable selections
are passed as named arguments via `...`, or via a prepared query object
from
[`prepare_query()`](https://lchansson.github.io/pixieweb/reference/prepare_query.md).

## Usage

``` r
get_data(
  api,
  table_id,
  ...,
  query = NULL,
  .codelist = NULL,
  .output = "long",
  .comments = FALSE,
  simplify = TRUE,
  auto_chunk = TRUE,
  max_results = NULL,
  cache = FALSE,
  cache_location = NULL,
  verbose = FALSE
)
```

## Arguments

- api:

  A `<px_api>` object.

- table_id:

  A single table ID (character). Vectors are not supported; use
  [`purrr::map()`](https://purrr.tidyverse.org/reference/map.html) +
  [`dplyr::bind_rows()`](https://dplyr.tidyverse.org/reference/bind_rows.html)
  for multiple tables. Ignored when `query` is provided.

- ...:

  Variable selections as named arguments. Each name is a variable code,
  each value is one of:

  - A character vector of specific value codes (item selection)

  - `"*"` for all values

  - A
    [px_selections](https://lchansson.github.io/pixieweb/reference/px_selections.md)
    helper:
    [`px_all()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
    [`px_top()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
    [`px_bottom()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
    [`px_from()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
    [`px_to()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
    [`px_range()`](https://lchansson.github.io/pixieweb/reference/px_selections.md)

  - Omitted variables are eliminated if the API allows it Ignored when
    `query` is provided.

- query:

  A `<px_query>` object from
  [`prepare_query()`](https://lchansson.github.io/pixieweb/reference/prepare_query.md).
  When provided, `table_id`, `...`, and `.codelist` are taken from the
  query object.

- .codelist:

  Named list of codelist overrides (e.g.
  `list(Region = "agg_RegionLan")`).

- .output:

  `"long"` (default, tidy) or `"wide"` (pivot content variables).

- .comments:

  Include footnotes/comments as an attribute.

- simplify:

  Add human-readable text label columns alongside codes.

- auto_chunk:

  Automatically split large queries that exceed the cell limit into
  multiple requests. When `TRUE` (default), the variable with the most
  values is split into batches, each request staying under the limit. A
  progress bar is shown. Set to `FALSE` to error instead.

- max_results:

  Override the API's cell limit. When set, this value is used instead of
  the limit reported by the API's config endpoint. Useful for keeping
  result size manageable or for testing chunking behavior.

- cache:

  Logical. If `TRUE` and `cache_location` points at a SQLite file (or an
  `nxt_handle` from nordstatExtras), the data is cached at cell
  granularity in that database. Supports concurrent multi-process
  read/write and cross-query cell reuse. Requires `nordstatExtras`.

- cache_location:

  Either a path to a `.sqlite` file or an `nxt_handle` from
  [`nordstatExtras::nxt_open()`](https://rdrr.io/pkg/nordstatExtras/man/nxt_open.html).
  Ignored unless `cache = TRUE`.

- verbose:

  Print request details.

## Value

A tibble of data. See Details for column structure.

## Details

When `simplify = TRUE` and `.output = "long"` (defaults), columns are:

- `table_id`: back-reference to the source table

- One pair per dimension: `{code}` (raw code) + `{code}_text` (label)

- `value`: the numeric measurement

When `simplify = FALSE`, only raw codes and `value` are returned.

When `.output = "wide"`, content variables are pivoted into separate
columns.

When `auto_chunk = TRUE` and the query would exceed the API's cell
limit, `get_data()` automatically splits the request. It picks the
variable with the most values and batches its values so each request
fits under the limit. Requests are paced to respect the API's rate
limit.

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {

  # Fetch with explicit selections
  get_data(scb, "TAB638",
    Region = c("0180", "1480"),
    Tid = px_top(5)
  )

  # Fetch from a prepared query
  q <- prepare_query(scb, "TAB638", Region = c("0180"))
  get_data(scb, query = q)
}# }
#> Warning: PX-Web API returned HTTP 400: {"type":"Parameter error","title":"Missing selection for mandantory variable","status":400}
#> ── Query: TAB638 ──────────────────────────────────────────────────────────────── 
#>   Estimated cells: 20 / 150000 (0% of limit)
#> 
#>   Region = c("0180")
#>     user override
#>   Civilstand = <eliminated>
#>     eliminated (4 values available)
#>   Alder = <eliminated>
#>     eliminated (102 values available)
#>   Kon = <eliminated>
#>     eliminated (2 values available)
#>   ContentsCode = "*"
#>     all 2 content variable(s)
#>   Tid = px_top(10)
#>     latest 10 of 57 periods
#> # A tibble: 20 × 8
#>    table_id Region Region_text ContentsCode ContentsCode_text Tid   Tid_text
#>    <chr>    <chr>  <chr>       <chr>        <chr>             <chr> <chr>   
#>  1 TAB638   0180   Stockholm   BE0101N1     Population        2015  2015    
#>  2 TAB638   0180   Stockholm   BE0101N1     Population        2016  2016    
#>  3 TAB638   0180   Stockholm   BE0101N1     Population        2017  2017    
#>  4 TAB638   0180   Stockholm   BE0101N1     Population        2018  2018    
#>  5 TAB638   0180   Stockholm   BE0101N1     Population        2019  2019    
#>  6 TAB638   0180   Stockholm   BE0101N1     Population        2020  2020    
#>  7 TAB638   0180   Stockholm   BE0101N1     Population        2021  2021    
#>  8 TAB638   0180   Stockholm   BE0101N1     Population        2022  2022    
#>  9 TAB638   0180   Stockholm   BE0101N1     Population        2023  2023    
#> 10 TAB638   0180   Stockholm   BE0101N1     Population        2024  2024    
#> 11 TAB638   0180   Stockholm   BE0101N2     Population growth 2015  2015    
#> 12 TAB638   0180   Stockholm   BE0101N2     Population growth 2016  2016    
#> 13 TAB638   0180   Stockholm   BE0101N2     Population growth 2017  2017    
#> 14 TAB638   0180   Stockholm   BE0101N2     Population growth 2018  2018    
#> 15 TAB638   0180   Stockholm   BE0101N2     Population growth 2019  2019    
#> 16 TAB638   0180   Stockholm   BE0101N2     Population growth 2020  2020    
#> 17 TAB638   0180   Stockholm   BE0101N2     Population growth 2021  2021    
#> 18 TAB638   0180   Stockholm   BE0101N2     Population growth 2022  2022    
#> 19 TAB638   0180   Stockholm   BE0101N2     Population growth 2023  2023    
#> 20 TAB638   0180   Stockholm   BE0101N2     Population growth 2024  2024    
#> # ℹ 1 more variable: value <dbl>
```
