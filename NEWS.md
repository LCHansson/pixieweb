# pixieweb 0.1.1

## New features

- **`data_legend()` gains `lang`, `omit_varname` and `omit_desc`
  arguments**, mirroring the same API in the sibling package `rTrafa`.
  `lang` (default `"EN"`, settable via `getOption("pixieweb.lang",
  "EN")`) toggles the source prefix between `"Source: …, table X"` and
  `"Källa: …, tabell X"`. `omit_varname` drops the raw variable codes
  from the variable list; `omit_desc` shows only the codes.
- **`data_legend()`'s `var_df` argument is now optional.** When
  omitted, the caption contains only the source line derived from the
  `px_source` attribute attached by `get_data()`.
- **Optional SQLite-backed caching via nordstatExtras.** `get_data()`,
  `get_tables()`, and `table_enrich()` now accept `cache = TRUE` with a
  `.sqlite` `cache_location` for shared, multi-process cache backed by
  the [nordstatExtras](https://github.com/LCHansson/nordstatExtras)
  package. Cell-level deduplication for data; per-table incremental
  enrichment with resume-on-crash and `async = TRUE` support for
  `table_enrich()`. Falls back to the existing `.rds` cache when
  nordstatExtras is not installed.

## Documentation

- **Vignette data is now pre-cached on disk** via `data-raw/vignette-data.R`
  and `R/sysdata.rda`, mirroring the approach used in `rKolada` and
  `rTrafa`. Vignettes render offline and show real API output for
  tables, variables, prepared queries, codelists and plots.
- **Introduction vignette rewritten**: the `Kolada`-comparison table in
  the "data model" section is replaced with a dedicated, pedagogical
  explanation of the PX-Web data cube (API → table → variables →
  content codes → codelists → data), following the same structure as
  the `rKolada` and `rTrafa` introduction vignettes.
- Vignette plots now convert `Tid` to `Date` before plotting and use
  `scale_x_date(date_breaks = "1 year", date_labels = "%Y")`, so axis
  breaks land on whole years rather than on decimal years like `2020,
  2022.5, 2025`. This pattern is explained inline and is consistent
  with the sibling packages `rKolada` and `rTrafa`.
- README and all vignettes now cross-link to the sibling packages
  `rKolada` and `rTrafa`, and list `install.packages("pixieweb")` as
  the primary install path.
- README now includes a section on enhanced caching with nordstatExtras.

# pixieweb 0.1.0

Initial CRAN release.

## Documentation

* Improved quickstart vignette: explains ContentsCode, elimination, `_text` columns, and adds inline ggplot comments.
* Improved introduction vignette: navigation help, clearer elimination explanation, "Advanced features" marker, and motivation for codelists/wide output/query composition/saved queries.
* Improved multi-api vignette: honest framing of cross-country challenges, guidance on finding comparable tables, actionable tips, and cross-references.
* Fixed Unicode `≤` in `prepare_query()` documentation that caused LaTeX PDF manual errors.

## Features

* **API connection**: `px_api()` creates reusable connection objects for any PX-Web API (SCB, SSB, Statistics Finland, etc.) with automatic version detection (v1/v2).
* **API availability**: `px_available()` performs a lightweight connectivity check, used to guard examples and tests.
* **Table discovery**: `get_tables()` searches and lists available tables with support for both v1 (tree-walking) and v2 (search endpoint) APIs.
* **Variable inspection**: `get_variables()` retrieves variable metadata for any table, including value lists and selection types.
* **Data retrieval**: `get_data()` downloads data with automatic query construction, chunking for large requests, and rate limiting.
* **Codelists**: `get_codelists()` retrieves codelist metadata; `codelist_values()` and `codelist_describe()` for inspection.
* **Selection helpers**: `px_all()`, `px_top()`, `px_bottom()`, `px_from()`, `px_to()`, `px_range()` for concise variable selections.
* **Query workflow**: `prepare_query()` for interactive query building; `compose_table_query()`, `compose_data_query()`, `execute_query()` for programmatic access.
* **Saved queries**: `save_query()` and `get_saved_query()` for persisting and reloading query specifications.
* **Table helpers**: `table_search()`, `table_describe()`, `table_enrich()`, `table_minimize()`, `table_extract_ids()` for working with table metadata.
* **Variable helpers**: `variable_search()`, `variable_describe()`, `variable_minimize()`, `variable_extract_ids()`, `variable_name_to_code()`, `variable_values()` for working with variables.
* **Data helpers**: `data_minimize()`, `data_comments()`, `data_legend()` for working with downloaded data.
* **Persistent caching**: `pixieweb_cache_dir()` and `pixieweb_clear_cache()` for managing cached API responses using `tools::R_user_dir()`.
* **Citations**: `px_cite()` generates citations for downloaded data.
* **HTTP resilience**: Automatic retry with exponential backoff for transient errors and rate limiting (HTTP 429).
* **Built-in API catalogue**: Ships with a catalogue of known PX-Web APIs for Nordic and European statistical agencies.
