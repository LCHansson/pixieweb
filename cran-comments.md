## R CMD check results

0 errors | 0 warnings | 0 notes

## Test environments

- Local: Windows 11, R 4.5.2
- GitHub Actions: ubuntu-latest (R-release, R-devel, R-oldrel-1),
  macOS-latest (R-release), windows-latest (R-release)

## Changes since 0.1.0

- `data_legend()` gains `lang`, `omit_varname`, `omit_desc` arguments
  and an optional `var_df` parameter.
- Optional SQLite-backed caching via nordstatExtras (in Suggests, available
  on GitHub at https://github.com/LoveHansson/nordstatExtras). `get_data()`,
  `get_tables()`, and `table_enrich()` support a shared SQLite cache with
  cell-level deduplication and async enrichment. All integration points
  use `requireNamespace()` with graceful fallback to standard `.rds` file
  caching. No functionality is lost without it.
- mirai (in Suggests) is used optionally for async background enrichment
  in `table_enrich(async = TRUE)`.

## Downstream dependencies

No downstream dependencies at this time.
