# Fetch a single enriched-row tibble for one table_id.

Extracted from the original
[`table_enrich()`](https://lchansson.github.io/pixieweb/reference/table_enrich.md)
loop body so both the sync path and the mirai background path can call
it. Returns a one-row tibble with the enrichment columns (notes,
contents, subject_area, official_statistics, contact). On API failure
returns a row of NA placeholders rather than aborting — the caller can
decide what to do with a partial enrich run.

## Usage

``` r
fetch_single_enriched(api, tid, verbose = FALSE)
```
