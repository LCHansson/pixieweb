# Changelog

## pixieweb 0.1.1.9006

### Bug fixes

- **[`compose_table_query()`](https://lchansson.github.io/pixieweb/reference/compose_table_query.md)
  now percent-encodes its parameters.** The exported URL builder pasted
  `query=` in raw, so a multi-word search
  (`"nyregistrerade personbilar"`) produced a URL with a literal space
  that curl refuses outright (“Malformed input to a URL function”), and
  non-ASCII terms produced a URL the server could not match.
  [`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md)
  itself has encoded correctly since 0.1.1.9001; the low-level builder
  had been left behind. Encoding now lives in one place —
  `px_query_string()` / `px_url_append()` in `utils.R` — and both
  [`compose_table_query()`](https://lchansson.github.io/pixieweb/reference/compose_table_query.md)
  and `get_tables_v2()` go through it, so a call site cannot forget it
  again. `px_url_query()` also picks `&` over `?` when the URL already
  carries a query string.
- **Impossible page sizes are rejected instead of being sent.**
  `compose_table_query(per_page = Inf)` put `pageSize=Inf` in the URL
  and SCB answered HTTP 400. `per_page`/`page` must now be a single
  positive whole number, and the error for `Inf` names the remedy
  (`get_tables(..., max_results = Inf)`, which paginates transparently).
  `get_tables(max_results = ...)` gained the same guard: `Inf` and
  `NULL` both mean “all matching tables”, while `NA`, `0`, negatives,
  fractions and non-numerics now fail with a clear message rather than
  an opaque HTTP error or an internal `NA` comparison.
- **[`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md)
  names the mandatory variables a v2 API demands.** PX-Web v2 rejects a
  data query that omits any variable whose metadata has
  `elimination = FALSE` — including `ContentsCode` and the time variable
  — and its HTTP 400 body
  (`"Missing selection for mandantory variable"`) does not say which
  one.
  [`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md)
  surfaced that as an unactionable warning and returned `NULL`. It now
  checks client-side, where the variable metadata is already in hand,
  and errors with the missing variables, a copy-pasteable selection for
  each, and which variables may legitimately be omitted. Verified
  against SCB `TAB5166`, where the genuinely eliminable variable is
  `Storleksklass` and the missing ones were `SNI2007` and
  `ContentsCode`. The check is v2-only: PX-Web v1 expands an omitted
  non-eliminable variable rather than rejecting the request (verified
  against Konjunkturinstitutet’s `Indikatorm.px`).
  [`prepare_query()`](https://lchansson.github.io/pixieweb/reference/prepare_query.md)
  already filled the mandatory variables and is unaffected. Variable
  metadata is now fetched once per
  [`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md)
  call and shared between this check and the chunk planner. All three
  reported in `paket/DEV_BACKLOG.md` 2026-08-20.

### Documentation

- **Examples that omitted a mandatory variable are corrected.** The new
  check turned up several `TAB638` examples in
  [`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md),
  [`data_legend()`](https://lchansson.github.io/pixieweb/reference/data_legend.md),
  [`data_minimize()`](https://lchansson.github.io/pixieweb/reference/data_minimize.md),
  [`data_comments()`](https://lchansson.github.io/pixieweb/reference/data_comments.md),
  [`px_cite()`](https://lchansson.github.io/pixieweb/reference/px_cite.md),
  [`compose_data_query()`](https://lchansson.github.io/pixieweb/reference/compose_data_query.md)
  and
  [`execute_query()`](https://lchansson.github.io/pixieweb/reference/execute_query.md),
  plus two README snippets, that left out `ContentsCode`. They had been
  quietly returning `NULL` against the live API; they now pass
  `ContentsCode = "*"`. The vignettes were already correct.
- **[`table_enrich()`](https://lchansson.github.io/pixieweb/reference/table_enrich.md)’s
  example no longer writes into the working directory.** It opened a
  cache at the literal path `"cache.sqlite"`, which `R CMD check` flags
  as a non-standard file in the check directory. It now uses
  [`tempfile()`](https://rdrr.io/r/base/tempfile.html). This had been
  masked: the example run used to abort earlier, at one of the `TAB638`
  examples above, before reaching it.

## pixieweb 0.1.1.9005

### New features

- **Tillväxtanalys added to the API catalogue** (alias `tva`), bringing
  the catalogue to 14 sources. A PxWeb **v1** instance, Swedish only, at
  `https://statistik.tillvaxtanalys.se/PxWeb/api/v1` — the statistics
  authority for Swedish business demography: bankruptcies and
  composition proceedings, new enterprises, foreign-owned firms, and
  groups with subsidiaries abroad. Verified with
  [`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md)
  (14 bankruptcy tables found) and
  [`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md)
  (monthly bankruptcies by industry, 2009M01–, 1 688 observations over
  eight industries). Its database id and every folder segment are
  clear-text strings with spaces and åäö (“Konkurser och offentliga
  ackord”), the same shape as the `sjv` entry — `px_encode_path()`
  (0.1.1.9003) already handles it, so no code change was needed.
  Reported in `paket/DEV_BACKLOG.md` 2026-08-20.

## pixieweb 0.1.1.9004

### Bug fixes

- **v1 auto-chunking no longer crashes**
  (`"Variable selection must be a character vector or a px_*() helper"`):
  v1 variable metadata stores value codes as list-columns, and the chunk
  splitter passed those lists straight into the per-chunk selections.
  Codes are now normalized to character in `check_query_size()`, and
  chunked v1 fetches verified byte-identical to unchunked ones (konj
  Indikatorm.px, 30 828 cells / 3 chunks).
- **Split-variable choice ignores eliminated variables correctly**: the
  splittable set was subset with a logical index of the wrong length
  when a variable was eliminated (assigning `NULL` into a list removes
  the element); now indexed by name.
- **Leading wildcards fail loudly**: SCB’s v2 search rejects a wildcard
  at the start of a term with HTTP 500, which surfaced as a silent
  zero-hit warning.
  [`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md)
  now raises an informative error suggesting a trailing wildcard or
  client-side
  [`table_search()`](https://lchansson.github.io/pixieweb/reference/table_search.md).
  Documentation no longer claims mid-term wildcards work, and notes that
  legacy subject-area codes (“MI0107”) are not indexed by the v2 search.

## pixieweb 0.1.1.9003

### Bug fixes

- **v1 catalog walks now reach databases with spaces in their ids**
  (e.g. sjv’s “Jordbruksverkets statistikdatabas”): all v1 URL path
  segments are percent-encoded via the new internal `px_encode_path()`.
  Previously
  [`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md)
  silently returned zero tables for such APIs.
- **msb catalogue entry updated**: MSB’s statistics moved to MCF —
  `https://statistik.mcf.se/PXWeb/api/v1`.

### New features

- **Clear-text `subject_path` for v1 tree walks**: the walk now
  accumulates each folder’s text label, so v1 tables get a readable
  subject path (“Folkhälsodata/ANDTS/…”) instead of `NA`.
- **`px_range(from)` without `to`** is now an open-ended range
  (equivalent to `px_from(from)`), so stored query specs can express
  “from year X onwards” without hard-coding an end period.
- **[`px_api()`](https://lchansson.github.io/pixieweb/reference/px_api.md)
  config fetches are memoized** per base_url (24 h TTL) — saves an
  ~80–100 ms round-trip on every repeated
  [`px_api()`](https://lchansson.github.io/pixieweb/reference/px_api.md)
  call.

## pixieweb 0.1.1.9002

### New features

- **[`get_variables()`](https://lchansson.github.io/pixieweb/reference/get_variables.md)
  gains `cache` and `cache_location` arguments**, matching the interface
  of
  [`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md)
  and
  [`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md).
  Variable metadata can now be cached to the shared SQLite backend via
  an `nxt_handle` from nordstatExtras, or to the legacy `.rds`
  directory. Previously, callers that passed these arguments (reasonably
  assuming parity with the other `get_*` functions) received a silent
  error via consumer-side `tryCatch` wrapping.

### Documentation

- **`get_tables(query = ...)` documentation now covers wildcard
  behaviour.** On v2 APIs the server-side search is an exact token match
  by default; `"befolk"` will not find `"befolkning"`. Use explicit
  wildcards (`"befolk*"`, `"*arbets*"`) for prefix or substring
  matching.

## pixieweb 0.1.1.9001

### Bug fixes

- **[`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md)
  now paginates transparently on v2 APIs.** Previously, the v2 code path
  sent a single request with `pageSize = max_results` (default 100). For
  SCB, which holds tens of thousands of tables, users had to discover
  the undocumented workaround of setting `max_results = 100000L` to
  avoid silently capped results. The new implementation loops over
  `pageNumber` in 1000-row chunks, stopping when the API reports
  `totalPages` reached, when `max_results` is satisfied, when a short
  page is returned, or at a 50000-row safety cap for the rare “no
  filter, no `max_results`” full-listing case. `max_results = NULL` (the
  default) now means “all matching tables”, consistent with
  `rKolada::get_kpi()` and `rTrafa::get_products()`. A user query for
  “befolkning” on SCB that previously returned 100 tables now returns
  all 205 in roughly 1 second.

- **`get_tables(query = ...)` now URL-encodes the query parameter.**
  Previously, `get_tables_v2` built the request URL with a plain
  [`paste()`](https://rdrr.io/r/base/paste.html) call, unlike the v1
  code path which correctly used
  [`utils::URLencode()`](https://rdrr.io/r/utils/URLencode.html). As a
  result, any search term containing non-ASCII characters (å/ä/ö,
  accented letters, spaces, punctuation) silently returned zero tables
  even when matching tables existed. For SCB searches this meant almost
  all Swedish queries failed. Verified against the SCB API:
  `query = "arbetslöshet"` now correctly returns tables such as TAB203
  *Arbetslösa 16-64 år (AKU)*.

## pixieweb 0.1.1

### New features

- **[`data_legend()`](https://lchansson.github.io/pixieweb/reference/data_legend.md)
  gains `lang`, `omit_varname` and `omit_desc` arguments**, mirroring
  the same API in the sibling package `rTrafa`. `lang` (default `"EN"`,
  settable via `getOption("pixieweb.lang", "EN")`) toggles the source
  prefix between `"Source: …, table X"` and `"Källa: …, tabell X"`.
  `omit_varname` drops the raw variable codes from the variable list;
  `omit_desc` shows only the codes.
- **[`data_legend()`](https://lchansson.github.io/pixieweb/reference/data_legend.md)’s
  `var_df` argument is now optional.** When omitted, the caption
  contains only the source line derived from the `px_source` attribute
  attached by
  [`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md).
- **Optional SQLite-backed caching via nordstatExtras.**
  [`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md),
  [`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md),
  and
  [`table_enrich()`](https://lchansson.github.io/pixieweb/reference/table_enrich.md)
  now accept `cache = TRUE` with a `.sqlite` `cache_location` for
  shared, multi-process cache backed by the
  [nordstatExtras](https://github.com/LCHansson/nordstatExtras) package.
  Cell-level deduplication for data; per-table incremental enrichment
  with resume-on-crash and `async = TRUE` support for
  [`table_enrich()`](https://lchansson.github.io/pixieweb/reference/table_enrich.md).
  Falls back to the existing `.rds` cache when nordstatExtras is not
  installed.

### Documentation

- **Vignette data is now pre-cached on disk** via
  `data-raw/vignette-data.R` and `R/sysdata.rda`, mirroring the approach
  used in `rKolada` and `rTrafa`. Vignettes render offline and show real
  API output for tables, variables, prepared queries, codelists and
  plots.
- **Introduction vignette rewritten**: the `Kolada`-comparison table in
  the “data model” section is replaced with a dedicated, pedagogical
  explanation of the PX-Web data cube (API → table → variables → content
  codes → codelists → data), following the same structure as the
  `rKolada` and `rTrafa` introduction vignettes.
- Vignette plots now convert `Tid` to `Date` before plotting and use
  `scale_x_date(date_breaks = "1 year", date_labels = "%Y")`, so axis
  breaks land on whole years rather than on decimal years like
  `2020, 2022.5, 2025`. This pattern is explained inline and is
  consistent with the sibling packages `rKolada` and `rTrafa`.
- README and all vignettes now cross-link to the sibling packages
  `rKolada` and `rTrafa`, and list `install.packages("pixieweb")` as the
  primary install path.
- README now includes a section on enhanced caching with nordstatExtras.

## pixieweb 0.1.0

CRAN release: 2026-03-26

Initial CRAN release.

### Documentation

- Improved quickstart vignette: explains ContentsCode, elimination,
  `_text` columns, and adds inline ggplot comments.
- Improved introduction vignette: navigation help, clearer elimination
  explanation, “Advanced features” marker, and motivation for
  codelists/wide output/query composition/saved queries.
- Improved multi-api vignette: honest framing of cross-country
  challenges, guidance on finding comparable tables, actionable tips,
  and cross-references.
- Fixed Unicode `≤` in
  [`prepare_query()`](https://lchansson.github.io/pixieweb/reference/prepare_query.md)
  documentation that caused LaTeX PDF manual errors.

### Features

- **API connection**:
  [`px_api()`](https://lchansson.github.io/pixieweb/reference/px_api.md)
  creates reusable connection objects for any PX-Web API (SCB, SSB,
  Statistics Finland, etc.) with automatic version detection (v1/v2).
- **API availability**:
  [`px_available()`](https://lchansson.github.io/pixieweb/reference/px_available.md)
  performs a lightweight connectivity check, used to guard examples and
  tests.
- **Table discovery**:
  [`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md)
  searches and lists available tables with support for both v1
  (tree-walking) and v2 (search endpoint) APIs.
- **Variable inspection**:
  [`get_variables()`](https://lchansson.github.io/pixieweb/reference/get_variables.md)
  retrieves variable metadata for any table, including value lists and
  selection types.
- **Data retrieval**:
  [`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md)
  downloads data with automatic query construction, chunking for large
  requests, and rate limiting.
- **Codelists**:
  [`get_codelists()`](https://lchansson.github.io/pixieweb/reference/get_codelists.md)
  retrieves codelist metadata;
  [`codelist_values()`](https://lchansson.github.io/pixieweb/reference/codelist_values.md)
  and
  [`codelist_describe()`](https://lchansson.github.io/pixieweb/reference/codelist_describe.md)
  for inspection.
- **Selection helpers**:
  [`px_all()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
  [`px_top()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
  [`px_bottom()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
  [`px_from()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
  [`px_to()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
  [`px_range()`](https://lchansson.github.io/pixieweb/reference/px_selections.md)
  for concise variable selections.
- **Query workflow**:
  [`prepare_query()`](https://lchansson.github.io/pixieweb/reference/prepare_query.md)
  for interactive query building;
  [`compose_table_query()`](https://lchansson.github.io/pixieweb/reference/compose_table_query.md),
  [`compose_data_query()`](https://lchansson.github.io/pixieweb/reference/compose_data_query.md),
  [`execute_query()`](https://lchansson.github.io/pixieweb/reference/execute_query.md)
  for programmatic access.
- **Saved queries**:
  [`save_query()`](https://lchansson.github.io/pixieweb/reference/save_query.md)
  and
  [`get_saved_query()`](https://lchansson.github.io/pixieweb/reference/get_saved_query.md)
  for persisting and reloading query specifications.
- **Table helpers**:
  [`table_search()`](https://lchansson.github.io/pixieweb/reference/table_search.md),
  [`table_describe()`](https://lchansson.github.io/pixieweb/reference/table_describe.md),
  [`table_enrich()`](https://lchansson.github.io/pixieweb/reference/table_enrich.md),
  [`table_minimize()`](https://lchansson.github.io/pixieweb/reference/table_minimize.md),
  [`table_extract_ids()`](https://lchansson.github.io/pixieweb/reference/table_extract_ids.md)
  for working with table metadata.
- **Variable helpers**:
  [`variable_search()`](https://lchansson.github.io/pixieweb/reference/variable_search.md),
  [`variable_describe()`](https://lchansson.github.io/pixieweb/reference/variable_describe.md),
  [`variable_minimize()`](https://lchansson.github.io/pixieweb/reference/variable_minimize.md),
  [`variable_extract_ids()`](https://lchansson.github.io/pixieweb/reference/variable_extract_ids.md),
  [`variable_name_to_code()`](https://lchansson.github.io/pixieweb/reference/variable_name_to_code.md),
  [`variable_values()`](https://lchansson.github.io/pixieweb/reference/variable_values.md)
  for working with variables.
- **Data helpers**:
  [`data_minimize()`](https://lchansson.github.io/pixieweb/reference/data_minimize.md),
  [`data_comments()`](https://lchansson.github.io/pixieweb/reference/data_comments.md),
  [`data_legend()`](https://lchansson.github.io/pixieweb/reference/data_legend.md)
  for working with downloaded data.
- **Persistent caching**:
  [`pixieweb_cache_dir()`](https://lchansson.github.io/pixieweb/reference/pixieweb_cache_dir.md)
  and
  [`pixieweb_clear_cache()`](https://lchansson.github.io/pixieweb/reference/pixieweb_clear_cache.md)
  for managing cached API responses using
  [`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html).
- **Citations**:
  [`px_cite()`](https://lchansson.github.io/pixieweb/reference/px_cite.md)
  generates citations for downloaded data.
- **HTTP resilience**: Automatic retry with exponential backoff for
  transient errors and rate limiting (HTTP 429).
- **Built-in API catalogue**: Ships with a catalogue of known PX-Web
  APIs for Nordic and European statistical agencies.
