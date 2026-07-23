---
editor_options: 
  markdown: 
    wrap: 72
---

# rpx Testing Strategy: pxweb as Control

## Principle

Every rpx function that returns data or metadata should be testable
against an equivalent pxweb call. This gives us a ground-truth oracle:
if pxweb and rpx return the same content (modulo formatting), rpx is
correct.

## Test Architecture

```         
tests/
├── testthat/
│   ├── helper-pxweb-control.R    # Shared setup: pxweb wrapper functions
│   ├── helper-rpx-fixtures.R     # Cached API responses for offline tests
│   ├── test-api.R                # API connection & config
│   ├── test-tables.R             # Table discovery & search
│   ├── test-variables.R          # Variable/dimension metadata
│   ├── test-data.R               # Data fetching & formatting
│   ├── test-codelists.R          # Codelist/aggregation handling
│   ├── test-comments.R           # Footnote/comment extraction
│   └── test-query-splitting.R    # Large query batching
├── fixtures/                     # Recorded API responses (JSON files)
│   ├── scb-tables-search.json
│   ├── scb-metadata-BefolkningNy.json
│   ├── scb-data-BefolkningNy.json
│   └── ...
└── manual/                       # Long-running integration tests
    └── test-all-agencies.R       # Hit every catalogued API
```

## Three Test Tiers

### Tier 1: Unit tests (no network, fast, run on every commit)

Use recorded JSON fixtures to test parsing, tibble construction, search,
describe, and other pure-logic functions. No pxweb dependency.

``` r
test_that("table_search filters by regex", {
  tables <- read_fixture("scb-tables-search.json") |> parse_tables_response()
  result <- tables |> table_search("befolkning")
  expect_s3_class(result, "tbl_df")
  expect_true(all(grepl("befolkning", result$title, ignore.case = TRUE)))
})
```

### Tier 2: Integration tests with pxweb control (network required)

These tests fetch the same data via both rpx and pxweb, then compare.
Gated behind `rpx_test_online()` (like rKolada's `kolada_available()`).

``` r
# helper-pxweb-control.R
# Thin wrappers that call pxweb and normalize output for comparison.

pxweb_control_get_data <- function(url, query,
                                   column.name.type = "code",
                                   variable.value.type = "code") {
  raw <- pxweb::pxweb_get_data(url, query,
    column.name.type = column.name.type,
    variable.value.type = variable.value.type
  )
  # Normalize to tibble with sorted columns and rows
  tibble::as_tibble(raw) |>
    dplyr::arrange(dplyr::across(dplyr::everything()))
}

rpx_control_get_data <- function(api, table_id, ...) {
  # The equivalent rpx call
  result <- get_data(api, table_id, ...)
  result |>
    dplyr::arrange(dplyr::across(dplyr::everything()))
}
```

**Comparison protocol:**

``` r
test_that("rpx returns same values as pxweb for simple query", {
  skip_if_not(rpx_test_online())
  skip_if_not_installed("pxweb")

  api <- px_api("scb", lang = "en")

  # The query: population by region, last 2 years
  rpx_result <- get_data(api, "TAB638",
    Region = c("0180", "0181"),
    Tid = top(2)
  )

  # Equivalent pxweb call
  pxweb_url <- "https://api.scb.se/OV0104/v1/doris/en/ssd/BE/BE0101/BE0101A/BefolkningNy"
  pxweb_query <- list(
    "Region" = c("0180", "0181"),
    "ContentsCode" = c("*"),
    "Tid" = c("*")
  )
  pxweb_result <- pxweb_control_get_data(pxweb_url, pxweb_query)

  # Compare content (not column names or types — those differ by design)
  # Extract the numeric value columns and dimension codes
  expect_equal(nrow(rpx_result), nrow(pxweb_result))
  # Values should match within floating point tolerance
  expect_equal(
    sort(rpx_result$value),
    sort(as.numeric(pxweb_result[[ncol(pxweb_result)]])),
    tolerance = 1e-10
  )
})
```

**What to compare:**

| Aspect          | Compare exactly? | Notes                                     |
|-----------------|------------------|-------------------------------------------|
| Number of rows  | Yes              | Same query must yield same row count      |
| Numeric values  | Yes (tolerance)  | Core correctness check                    |
| Dimension codes | Yes              | Same codes in same rows                   |
| Column names    | No               | rpx uses tidy names, pxweb uses raw       |
| Column types    | No               | rpx returns chr/dbl, pxweb returns factor |
| Row order       | No               | Sort both before comparing                |
| Column order    | No               | Select by name, not position              |

### Tier 3: Comprehensive cross-agency tests (manual/CI nightly)

Test against every catalogued API to catch instance-specific quirks. Run
as a parameterized test matrix:

``` r
# test-all-agencies.R
agencies <- px_api_catalogue()

for (i in seq_len(nrow(agencies))) {
  test_that(glue("get_tables works for {agencies$alias[i]}"), {
    api <- px_api(agencies$alias[i])
    tables <- get_tables(api, n = 5)
    expect_s3_class(tables, "tbl_df")
    expect_gt(nrow(tables), 0)

    # Pick first table, fetch metadata
    vars <- get_variables(api, tables$id[1])
    expect_s3_class(vars, "tbl_df")
    expect_gt(nrow(vars), 0)
  })
}
```

## Fixture Recording

Automate fixture capture from live APIs:

``` r
# Record a fixture for offline use
record_fixture <- function(name, expr) {
  result <- expr
  jsonlite::write_json(result, file.path("tests/fixtures", paste0(name, ".json")),
    auto_unbox = TRUE, pretty = TRUE
  )
  result
}

# Usage:
record_fixture("scb-tables-search", {
  httr2::request("https://statistikdatabasen.scb.se/api/v2/tables") |>
    httr2::req_url_query(query = "befolkning", pageSize = 10) |>
    httr2::req_perform() |>
    httr2::resp_body_json()
})
```

Re-record fixtures periodically (e.g. quarterly) to catch API changes.

## Test Design Rules

1.  **Every exported function gets both a Tier 1 and Tier 2 test.**

2.  **Tier 2 tests always have a pxweb control** unless the function has
    no pxweb equivalent (e.g. `table_describe()`). For those, validate
    against raw API JSON instead.

3.  **Test dimension coverage for data tests:**

    -   Simple query (1-2 dimensions, specific values)
    -   Wildcard query (`"*"` / `all`)
    -   Top/bottom selection
    -   Range/from/to selection (v2)
    -   Codelist/aggregation query
    -   Query that triggers splitting (exceeds cell limit)
    -   Query with elimination variables omitted

4.  **Test across at least 2 agencies** in Tier 2 (e.g. SCB + SSB) to
    catch instance differences.

5.  **Snapshot tests for describe output.** Use
    `testthat::expect_snapshot()` for `*_describe()` functions since
    their output is text, not data.

6.  **Edge cases to cover:**

    -   Table with only 1 variable
    -   Variable with 1 value
    -   Missing/NA values in data (PX-Web uses "." for missing)
    -   Unicode in variable names and values
    -   Very long table IDs (Finland's `.px` suffix pattern)
    -   API returning 403 (cell limit exceeded) — should give clear
        error
    -   API returning 429 (rate limit) — should retry or inform user

## Continuous Integration

``` yaml
# In CI config:
- name: "Unit tests (Tier 1)"
  run: Rscript -e "testthat::test_local(filter = 'test-')"

- name: "Integration tests (Tier 2)"
  if: github.event_name == 'pull_request'
  run: Rscript -e "Sys.setenv(RPX_TEST_ONLINE = 'true'); testthat::test_local()"

- name: "Cross-agency tests (Tier 3)"
  if: github.event_name == 'schedule'  # nightly
  run: Rscript -e "Sys.setenv(RPX_TEST_ONLINE = 'true'); testthat::test_dir('tests/manual')"
```
