---
editor_options: 
  markdown: 
    wrap: 72
---

# rpx API Design Specification

## Design Principles (inherited from rKolada)

1.  **Tibbles everywhere.** Every function returns a tibble (or a vector
    extracted from one).
2.  **Pipe-friendly.** First argument is always a tibble or API object;
    output is always pipeable.
3.  **Search-then-fetch.** Users discover metadata before downloading
    data.
4.  **NULL on failure.** API errors return NULL with a warning, never
    stop().
5.  **Progressive disclosure.** Simple things are simple; complex things
    are possible.
6.  **Consistent naming.** `get_*`, `*_search`, `*_describe`,
    `*_extract_ids`, `*_minimize`.

## Naming Conventions

Following rKolada's patterns exactly:

| Pattern | Purpose | Example |
|----|----|----|
| `px_*()` | Package-level utilities | `px_api()`, `px_available()` |
| `get_*()` | Fetch from API | `get_tables()`, `get_data()` |
| `*_search()` | Filter tibble by search term | `table_search()` |
| `*_describe()` | Print human-readable summary | `table_describe()` |
| `*_extract_ids()` | Extract ID vector from tibble | `table_extract_ids()` |
| `*_minimize()` | Remove monotonous columns | `variable_minimize()` |
| `compose_*_query()` | Build API URL (advanced) | `compose_table_query()` |
| `*_name_to_id()` etc. | Lookup helpers | `variable_name_to_code()` |

------------------------------------------------------------------------

## Entity Model

rKolada has 5 entities: kpi, kpi_groups, municipality,
municipality_groups, ou.

rpx has a different structure due to PX-Web's hierarchical nature:

| rpx entity   | What it represents              | rKolada analog          |
|--------------|---------------------------------|-------------------------|
| **api**      | A PX-Web instance (SCB, SSB...) | *(implicit — single)*   |
| **table**    | A statistical table             | kpi                     |
| **variable** | A dimension within a table      | *(municipality/period)* |
| **codelist** | An aggregation/value set        | *(kpi_groups)*          |
| **data**     | Downloaded values               | values                  |

------------------------------------------------------------------------

## Function Catalog

### 1. API Connection

``` r
px_api(
  x,                    # Alias ("scb", "ssb") or full base URL
 lang      = NULL,     # Language ("en", "sv", ...) — NULL = API default
  version   = "v2",     # API version
  verbose   = FALSE
)
# Returns: <px_api> object (lightweight list with class attribute)
# Contains: base_url, lang, version, config (max_cells, rate_limit, etc.)
# Fetches /config endpoint on construction to learn limits.
# Prints nicely: "PX-Web API: Statistics Sweden (v2, en)"

px_api_catalogue()
# Returns: tibble with columns: alias, description, url, versions, langs
# Source: bundled JSON, like pxweb's api.json but as a tibble

px_available(api)
# Returns: logical — can we reach this API?
# Equivalent to rKolada's kolada_available()
```

**Usage:**

``` r
scb <- px_api("scb", lang = "sv")
ssb <- px_api("ssb", lang = "no")
custom <- px_api("https://my.statbank.example/api/v2/", lang = "en")
```

### 2. Table Discovery

Tables are the central entity (like KPIs in rKolada).

``` r
get_tables(
  api,                  # <px_api> object
  query      = NULL,    # Free-text search (sent to API as ?query=...)
  id         = NULL,    # Specific table ID(s)
  updated_since = NULL, # Only tables updated in last N days (integer)
  max_results = NULL,   # Max tables to return (pagination handled internally)
  cache      = FALSE,
  cache_location = tempdir,
  verbose    = FALSE
)
# Returns: tibble with columns:
#   id          <chr>  — table ID (e.g. "TAB638", "01222")
#   title       <chr>  — human-readable title
#   category    <chr>  — "public" / "internal" / etc.
#   updated     <dttm> — last update timestamp
#   variables   <list> — character vector of variable codes
#   discontinued <lgl> — whether table is discontinued
#   source      <chr>  — API alias for traceability

table_search(table_df, query, column = NULL)
# Client-side regex filter on an already-fetched table tibble (like kpi_search).
# Complements get_tables(query=...) which does server-side search.
# Server-side: initial broad narrowing. Client-side: further refinement on cached results.
# The same server/client split applies to variable_search() and other *_search() functions.
# Returns: filtered tibble

table_describe(table_df, max_n = 5, format = "inline", heading_level = 2)
# Print human-readable table summaries (like kpi_describe)
# Shows: ID, title, last updated, variable names, discontinued status
# Returns: table_df invisibly (for piping)

table_minimize(table_df, remove_monotonous_data = TRUE)
# Remove monotonous columns (like kpi_minimize)
# Returns: tibble

table_extract_ids(table_df)
# Returns: character vector of table IDs
```

**Canonical workflow:**

``` r
scb <- px_api("scb", lang = "en")

scb |> 
  get_tables(query = "population") |>
  table_search("municipality") |>
  table_describe() |>
  table_extract_ids()
#> [1] "TAB638" "TAB4968" ...
```

### 3. Variable & Metadata Exploration

This is the key new concept that has no direct rKolada analog. In
rKolada, the dimensions are fixed (kpi, municipality, period). In
PX-Web, each table has its own set of arbitrary dimensions that the user
must discover.

``` r
get_variables(
  api,                  # <px_api> object
  table_id,             # Single table ID (character)
  verbose    = FALSE
)
# Returns: tibble with columns:
#   code         <chr>  — variable code (e.g. "Region", "Tid", "Kon")
#   text         <chr>  — human-readable name (e.g. "Region", "Year", "Sex")
#   n_values     <int>  — number of available values
#   elimination  <lgl>  — can this variable be omitted from queries?
#   time         <lgl>  — is this a time variable?
#   values       <list> — tibble(code <chr>, text <chr>) of all available values
#   codelists    <list> — tibble(id <chr>, text <chr>) of available codelists, or NULL
#   table_id     <chr>  — back-reference to parent table

variable_search(var_df, query, column = NULL)
# Filter variables or their values by regex
# Searches across code, text, and (optionally) nested value texts
# Returns: filtered tibble

variable_describe(var_df, max_n = 10, format = "inline", heading_level = 2)
# Print human-readable variable summaries
# Shows: code, text, mandatory/optional, n values, first few values
# Returns: var_df invisibly

variable_extract_ids(var_df)
# Returns: character vector of variable codes (like kpi_extract_ids)

variable_minimize(var_df)
# Drop nested columns (values, codelists) for a compact overview
# Returns: tibble

variable_name_to_code(var_df, name)
# Convert human-readable variable names to codes
# Returns: named character vector

variable_values(var_df, variable_code)
# Extract the values tibble for a specific variable
# Returns: tibble(code, text) — the unnested values for one variable
# Convenience shortcut for: var_df |> filter(code == x) |> pull(values) |> first()
```

**Canonical workflow:**

``` r
scb <- px_api("scb", lang = "en")

vars <- scb |> get_variables("TAB638")
vars |> variable_describe()
#> ── Region (Region) ─────────────────────────
#>   290 values, mandatory
#>   First values: 0114 Upplands Väsby, 0115 Vallentuna, ...
#>
#> ── Kon (Sex) ───────────────────────────────
#>   3 values, optional (elimination)
#>   Values: 1 Male, 2 Female, 1+2 Total
#> ...

# Look at what values a specific variable has:
vars |> variable_values("Kon")
#> # A tibble: 3 × 2
#>   code  text
#> 1 1     Male
#> 2 2     Female
#> 3 1+2   Total
```

### 4. Codelists (Aggregations & Value Sets)

Codelists allow alternative groupings of variable values (e.g.
municipalities grouped into counties). Analogous to rKolada's
kpi_groups/municipality_groups.

``` r
get_codelists(
  api,                  # <px_api> object
  table_id,             # Table ID
  variable_code,        # Variable code (e.g. "Region")
  verbose    = FALSE
)
# Returns: tibble with columns:
#   id          <chr>  — codelist ID
#   text        <chr>  — codelist description
#   type        <chr>  — "Aggregation" or "ValueSet"
#   values      <list> — tibble(code, text) of codelist values

codelist_describe(cl_df, max_n = 5, format = "inline", heading_level = 2)
# Print codelist summaries
# Returns: cl_df invisibly

codelist_extract_ids(cl_df)
# Returns: character vector of codelist IDs

codelist_values(cl_df, codelist_id)
# Extract values for a specific codelist
# Returns: tibble(code, text)
```

### 5. Data Fetching — The Core

This is the most important function and the biggest design challenge. It
must handle PX-Web's variable-dimension queries while feeling as natural
as rKolada's `get_values(kpi, municipality, period)`.

``` r
get_data(
  api,                  # <px_api> object
  table_id,             # Single table ID
  ...,                  # Variable selections as named arguments (see below)
  .codelist  = NULL,    # Named list of codelist overrides
  .output    = "long",  # "long" (tidy, long tibble) or "wide" (pivot wider on content)
  .comments  = FALSE,   # Include footnotes/comments as attribute?
  simplify   = TRUE,    # Add human-readable labels? (like rKolada)
  max_results = NULL,   # Safety limit on number of cells
  verbose    = FALSE
)
```

**The `...` interface — variable selections:**

Each named argument corresponds to a variable code. The value can be:

| R expression            | PX-Web filter   | Meaning                        |
|-------------------------|-----------------|--------------------------------|
| `c("0180", "0181")`     | item            | Specific values                |
| `"*"`                   | all             | All values                     |
| `px_all("01*")`         | all (pattern)   | Wildcard pattern               |
| `px_top(5)`             | top             | First N values                 |
| `px_bottom(3)`          | bottom (v2)     | Last N values                  |
| `px_from("2020")`       | from (v2)       | From value onward              |
| `px_to("2022")`         | to (v2)         | Up to value                    |
| `px_range("2020","23")` | range (v2)      | Inclusive range                |
| *(omitted)*             | *(elimination)* | Variable eliminated if allowed |

**The `.codelist` argument:**

``` r
# Use a codelist to aggregate regions into counties:
get_data(scb, "TAB638",
  Region = "*",
  Tid = px_top(5),
  .codelist = list(Region = "agg_RegionLän")
)
```

**Selection helper functions:**

``` r
px_all(pattern = "*")    # All values, optional glob pattern
px_top(n)                # First n values
px_bottom(n)             # Last n values (v2 only)
px_from(value)           # From value onward (v2 only, inclusive)
px_to(value)             # Up to value (v2 only, inclusive)
px_range(from, to)       # Inclusive range (v2 only)
```

Each returns a small S3 object (`<px_selection>`) that `get_data()`
translates to the appropriate API filter.

**Return value (simplify = TRUE, .output = "long"):**

```         
# A tibble: N × M
  table_id  Region  Region_text       Kon  Kon_text  Tid   value
  <chr>     <chr>   <chr>             <chr> <chr>    <chr>  <dbl>
  TAB638    0180    Stockholm kommun  1     Male     2023   510000
  ...
```

Columns: - `table_id` — back-reference (useful when binding data from
multiple tables) - One pair of columns per dimension: `{code}` (raw
code) + `{code}_text` (label) - `value` — the numeric measurement (or
multiple: `value_1`, `value_2`... if multiple contents) - When multiple
ContentsCode variables: one `value` column per content code, named by
content text

**Return value (.output = "wide"):**

Pivots the content variables into separate columns:

```         
  Region  Region_text       Kon  Kon_text  Tid   Population  Deaths
  0180    Stockholm kommun  1    Male      2023  510000      3200
```

**Return value (simplify = FALSE):**

Raw codes only, no text columns, no table_id prefix:

```         
  Region  Kon  Tid   value
  0180    1    2023  510000
```

### 6. Data Utilities

``` r
data_minimize(data_df, remove_monotonous_data = TRUE)
# Remove columns where all values are identical (like values_minimize)
# Returns: tibble

data_legend(data_df, var_df)
# Generate caption text for plots from variable metadata
# (like values_legend)
# Returns: character string

data_comments(data_df)
# Extract comments/footnotes from data (stored as attribute by get_data)
# Returns: tibble(variable, value, comment) or NULL
```

### 7. Query Composition (Advanced / Power Users)

For users who want to inspect or modify the raw API query before
execution.

``` r
compose_table_query(
  api,
  query = NULL, id = NULL, past_days = NULL,
  page = NA, per_page = NA
)
# Returns: character (URL string for the tables endpoint)

compose_data_query(
  api,
  table_id,
  ...,                  # Same ... interface as get_data
  .codelist = NULL
)
# Returns: list with two elements:
#   $url   — the API endpoint URL
#   $body  — the JSON query body (as an R list, serializable with jsonlite)
# Users can inspect, modify, and then pass to a lower-level fetch function.

execute_query(api, url, body = NULL, verbose = FALSE)
# Low-level: execute a composed query. Returns parsed JSON as list.
# Handles rate limiting, retries, error handling.
```

### 8. Saved Queries (v2 feature)

``` r
## Saved Queries
#
# PX-Web v2 saved queries are server-side stored query definitions: a table ID
# plus variable selections, persisted and shareable via a unique ID/URL.
# Think of them as bookmarks for specific data extractions that can be shared
# between users or used in reproducible workflows.
#
# In the tidy/piping design:
# - get_saved_query() is a convenience fetcher: takes an ID, returns data as a
#   tibble in the same format as get_data(). Fits naturally in pipelines.
# - save_query() persists selections server-side, returning an ID the user can
#   share or re-use later. Completes the round-trip and exposes the full API.

get_saved_query(
  api,
  query_id,             # Saved query ID (character)
  .output    = "long",  # Same output options as get_data()
  simplify   = TRUE,
  verbose    = FALSE
)
# Returns: tibble (data result of executing the saved query, same format as get_data())

save_query(
  api,
  table_id,
  ...,                  # Same ... as get_data
  .codelist  = NULL,
  verbose    = FALSE
)
# Returns: character (saved query ID that can be passed to get_saved_query())
```

### 9. Package-Level Utilities

``` r
px_cite(data_df)
# Generate citation for downloaded data (from metadata stored as attribute)
# Returns: character (bibentry-formatted citation)

rpx_clear_cache()
# Clear all cached API responses (created by the internal cache handler).
# Same pattern should be exported to rKolada as rkolada_clear_cache().
# Returns: invisible(NULL)
```

------------------------------------------------------------------------

## Complete Workflow Examples

### Example 1: Basic Discovery and Download

``` r
library(rpx)

# Connect to Statistics Sweden
scb <- px_api("scb", lang = "en")

# Find tables about population
tables <- get_tables(scb, query = "population") |>
  table_search("municipality") |>
  table_minimize()

tables |> table_describe(max_n = 3)

# Pick a table and explore its variables
vars <- get_variables(scb, "TAB638")
vars |> variable_describe()

# See what regions are available
vars |> variable_values("Region")

# Download data: Stockholm & Gothenburg, last 5 years, both sexes
pop <- get_data(scb, "TAB638",
  Region = c("0180", "1480"),
  Kon = "1+2",
  Tid = px_top(5)
)

pop
#> # A tibble: 10 × 8
#>   table_id Region Region_text       Kon Kon_text Tid   value
#>   <chr>    <chr>  <chr>             <chr> <chr>  <chr> <dbl>
#>   TAB638   0180   Stockholm kommun  1+2  Total   2024  1000000
#>   ...
```

### Example 2: Using Codelists for Aggregation

``` r
ssb <- px_api("ssb", lang = "en")

# What codelists are available for Region in this table?
cls <- get_codelists(ssb, "01222", "Region")
cls |> codelist_describe()

# Download with county-level aggregation
county_pop <- get_data(ssb, "01222",
  Region = "*",
  ContentsCode = "Folketallet1",
  Tid = px_from("2020K1"),
  .codelist = list(Region = "vs_Fylker")
)
```

### Example 3: Piped Workflow (rKolada-style)

``` r
scb <- px_api("scb", lang = "en")

# One pipeline from discovery to data
get_tables(scb, query = "income") |>
  table_search("taxable") |>
  table_describe(max_n = 3) |>
  table_extract_ids() |>
  (\(ids) get_data(scb, ids[1], Tid = px_top(3)))()
```

### Example 4: Multi-Table Comparison

``` r
scb <- px_api("scb", lang = "en")

# Fetch same dimensions from two tables, bind results
tables <- c("TAB638", "TAB4968")
results <- purrr::map(tables, \(id) {
  get_data(scb, id,
    Region = c("0180", "1480"),
    Tid = px_top(3)
  )
}) |>
  dplyr::bind_rows()

# table_id column lets you distinguish the source
results |> dplyr::count(table_id)
```

### Example 5: Wide Output for Analysis

``` r
# When a table has multiple content variables (e.g. population + deaths),
# .output = "wide" pivots them into separate columns:
demo <- get_data(scb, "TAB638",
  Region = c("0180"),
  Tid = px_top(5),
  .output = "wide"
)

demo
#> # A tibble: 5 × 6
#>   Region Region_text       Kon Kon_text Tid   Folkmängd  Födda
#>   <chr>  <chr>             <chr> <chr>  <chr> <dbl>      <dbl>
#>   0180   Stockholm kommun  1+2  Total   2024  1000000    12000
```

------------------------------------------------------------------------

## API Version Handling

The design targets PX-Web v2 as the primary protocol. For v1
compatibility:

| Feature               | v2                        | v1 fallback              |
|-----------------------|---------------------------|--------------------------|
| Table search          | GET /tables               | Recursive level walking  |
| Metadata              | GET /tables/{id}/metadata | GET table URL            |
| Data query (GET)      | Yes                       | No (POST only)           |
| Selection expressions | Full set                  | item/all/top/agg/vs      |
| Codelists endpoint    | Yes                       | Embedded in metadata     |
| Config endpoint       | Yes                       | Hardcoded from catalogue |
| Saved queries         | Yes                       | No                       |

The `px_api()` constructor detects the version and the internal query
composers dispatch accordingly. User-facing function signatures stay the
same.

Selection helpers degrade gracefully: - `px_from()`, `px_to()`,
`px_range()`, `px_bottom()` → error with informative message if used
against a v1 API

------------------------------------------------------------------------

## Internal Architecture (brief)

```         
R/
├── api.R              # px_api(), px_api_catalogue(), px_available()
├── tables.R           # get_tables(), table_search/describe/minimize/extract_ids
├── variables.R        # get_variables(), variable_search/describe/values/...
├── codelists.R        # get_codelists(), codelist_describe/extract_ids/values
├── data.R             # get_data(), data_minimize/legend/comments
├── selections.R       # px_all/top/bottom/from/to/range, <px_selection> class
├── query.R            # compose_table_query(), compose_data_query(), execute_query()
├── query_split.R      # Internal: split large queries into batches
├── saved_queries.R    # get_saved_query(), save_query()
├── cite.R             # px_cite()
├── cache.R            # Cache handler (like rKolada's cache_handler)
├── utils.R            # Shared internals: HTTP, pagination, NULL-on-error, etc.
├── describe.R         # Shared *_describe() glue templating
└── zzz.R              # .onLoad, pipe re-export
```

------------------------------------------------------------------------

## Resolved Design Decisions

1.  **Single table_id in `get_data()`.** If the user passes a vector,
    throw an informative error showing the `purrr::map() |> bind_rows()`
    pattern with their actual table IDs filled in (truncated if many).

2.  **Dual columns for simplify=TRUE.** Keep `{code}` + `{code}_text`
    column pairs. No attributes — an extra column is preferable.

3.  **v1 support at launch.** Both v1 and v2 will be supported. Main v1
    work: recursive level-walking for table discovery, POST-only data
    queries, hardcoded config from catalogue. \~30% additional code.

4.  **`...` interface for variable selections.** Ship with `...` in
    `get_data()`. A chainable query-builder can be added later if
    needed.

5.  **Rate limiting: verbose message + progress bar.** Silent under
    normal conditions. When rate-limited, show a message. For large
    queries that require multiple batches/sleeps, show a progress bar.
