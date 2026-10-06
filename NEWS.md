# pixieweb 0.1.1.9014

## Bug fixes

- **`get_data()`: a split fetch is all or nothing.** When a query is too
  large for one request it is split into several. If one of them failed (a
  connection error, a rate limit that outlasted the retries, an HTTP
  error), the rows of the others were bound and returned with only a
  warning, so the caller got a table that lacked a block of regions or
  periods and looked whole. `get_data()` now stops with an error of class
  `pixieweb_chunks_failed` that says how many requests failed, which ones,
  and the values of the split variable each asked for (also as fields
  `failed`, `n_chunks`, `split_var`). The warning that says why each
  request failed is kept. A query that fits in one request is unchanged
  (`NULL` with a warning on failure).

# pixieweb 0.1.1.9013

## New features

- **`px_get_data()`: `get_data()` under a name that cannot be masked.**
  rTrafa exports a `get_data()` too, so in a script that attaches both
  packages the one attached last masks the other, and every call to the
  masked one fails on the wrong argument check. `px_get_data()` forwards
  to `get_data()` unchanged (rTrafa gains `trafa_get_data()`), and
  attaching pixieweb while rTrafa is attached now prints a one-line note
  naming the two safe calls. `get_data()` itself is unchanged.

# pixieweb 0.1.1.9012

## New features

- **`get_codelists()` keeps the value map.** A v2 codelist says which of
  the table's values each of its own values stands for (`valueMap`): for
  an aggregation that is the total-to-parts mapping, the thing that says a
  county is these municipalities. It was dropped. The nested `values`
  tibble now has a list-column `value_map` beside `code` and `text`, and
  the result has the codelist's own `elimination` and
  `elimination_value_code`. Existing columns are unchanged.

# pixieweb 0.1.1.9011

## New features

- **`get_contents()` returns the unit of every measure in a table.** The
  unit (`tkr` or `mnkr`?) never reached the caller: `get_variables()` reads
  the labels of the contents variable and drops the `unit` block beside
  them, along with the measuring type (stock or flow), price type (current
  or fixed), adjustment and reference period. `get_contents(api, table_id)`
  returns one row per measure with those fields. For v2 it is one metadata
  request. A v1 API states no unit in its metadata but does in a json-stat2
  data response, so for v1 the function asks for a single cell in that
  form, and once more for all values of the contents variable: at most two
  small data requests. `get_variables()` is unchanged.

# pixieweb 0.1.1.9010

## Bug fixes

- **v1 results carry labels in `<var>_text`.** A v1 data response holds
  codes only, so the twin column repeated the code (`Bränsle_text` was
  `"0"`, `"1"` in the tables of Energimyndigheten) while a pivoted contents
  column did get a real label: the column existed but meant different
  things per table. `get_data()` now fills it from the variable metadata
  it has already fetched, wherever the twin still equals the code.
- **`get_variables()` returns plain character `code`/`text` for v1.** The
  nested `values` tibble held list-columns for v1 and character columns
  for v2, so `setNames(vals$text, vals$code)` gave an unusable lookup
  without an error. Both versions now give character columns.
- **The contents variable a v1 response folds into `ContentsCode` is
  named.** For `*_Cont.px` tables the variable is called `Mått` going in
  and `ContentsCode` coming out. The column name is unchanged (stored
  specs read it); the name the source uses is now in
  `attr(x, "px_contents_variable")`.

# pixieweb 0.1.1.9009

## Bug fixes

- **v1 fetches are paced by the instance's own limits.** `px_api()` read
  the limits only for v2, so every v1 instance was paced by the package
  default of 30 calls per 10 s. Konjunkturinstitutet allows 10 per 10 s:
  a chunked fetch ran three times too tight and risked HTTP 429. `px_api()`
  now also asks a v1 instance (`<base>/<lang>/?config`) and fills
  `api$config` with `max_cells`, `max_calls` and `time_window`, memoized
  for 24 h like the v2 config. An instance that does not answer leaves
  `config` `NULL`, silently, and the defaults apply as before.
- **The chunk planner counts a ranged selection by its own size.**
  `px_from()`, `px_to()` and `px_range()` were estimated as *all* values of
  the variable. A query with `Tid = px_range("2015")` was therefore split
  more often than needed, and when the split ran along the time variable
  the batches listed every period code, fetching periods outside the range.
  The planner now resolves each helper to the codes it stands for.
- **A split along a `px_top()`/`px_bottom()` time selection keeps the right
  periods.** For the time variable the server counts from the latest
  period (`px_top(3)` is the three latest), but the planner took the first
  three codes, so a chunked fetch returned the earliest periods instead.

# pixieweb 0.1.1.9008

## Bug fixes

- **`table_search()` says what is wrong when it is handed an api object.**
  `table_search(px_api("scb"), "utsläpp")` died inside the shared search
  helper with "missing value where TRUE/FALSE needed". It filters a tibble
  from `get_tables()`; given a `<px_api>` (or anything else that is not a
  data frame) it now errors with the two calls that do work:
  `get_tables(api, query = ...)` and `get_tables(api) |> table_search(...)`.

# pixieweb 0.1.1.9007

## New features

- **`get_data(.status = TRUE)` keeps the source's status symbol.** PX-Web
  marks a cell it withholds or cannot give with a symbol such as `".."`
  (not available or suppressed) or `"."` (not applicable). Both arrived as
  a plain `NA` in `value`, so a caller could not tell "the source withholds
  this" from "no value". With `.status = TRUE` the result gains a character
  column `status` after `value`: the symbol exactly as sent, `NA` where the
  cell has a value. Works for v2 (json-stat2 `status`, in its object, array
  and single-string forms) and v1 (the symbol is the cell's own string),
  also across chunked fetches. Opt-in: the default result is unchanged.
  Long output only; the SQLite cell cache is bypassed for such a call.

# pixieweb 0.1.1.9006

## Bug fixes

- **`compose_table_query()` now percent-encodes its parameters.** The
  exported URL builder pasted `query=` in raw, so a multi-word search
  (`"nyregistrerade personbilar"`) produced a URL with a literal space that
  curl refuses outright ("Malformed input to a URL function"), and
  non-ASCII terms produced a URL the server could not match. `get_tables()`
  itself has encoded correctly since 0.1.1.9001; the low-level builder had
  been left behind. Encoding now lives in one place — `px_query_string()` /
  `px_url_append()` in `utils.R` — and both `compose_table_query()` and
  `get_tables_v2()` go through it, so a call site cannot forget it again.
  `px_url_query()` also picks `&` over `?` when the URL already carries a
  query string.
- **Impossible page sizes are rejected instead of being sent.**
  `compose_table_query(per_page = Inf)` put `pageSize=Inf` in the URL and
  SCB answered HTTP 400. `per_page`/`page` must now be a single positive
  whole number, and the error for `Inf` names the remedy
  (`get_tables(..., max_results = Inf)`, which paginates transparently).
  `get_tables(max_results = ...)` gained the same guard: `Inf` and `NULL`
  both mean "all matching tables", while `NA`, `0`, negatives, fractions
  and non-numerics now fail with a clear message rather than an opaque
  HTTP error or an internal `NA` comparison.
- **`get_data()` names the mandatory variables a v2 API demands.** PX-Web
  v2 rejects a data query that omits any variable whose metadata has
  `elimination = FALSE` — including `ContentsCode` and the time variable —
  and its HTTP 400 body (`"Missing selection for mandantory variable"`)
  does not say which one. `get_data()` surfaced that as an unactionable
  warning and returned `NULL`. It now checks client-side, where the
  variable metadata is already in hand, and errors with the missing
  variables, a copy-pasteable selection for each, and which variables may
  legitimately be omitted. Verified against SCB `TAB5166`, where the
  genuinely eliminable variable is `Storleksklass` and the missing ones
  were `SNI2007` and `ContentsCode`. The check is v2-only: PX-Web v1
  expands an omitted non-eliminable variable rather than rejecting the
  request (verified against Konjunkturinstitutet's `Indikatorm.px`).
  `prepare_query()` already filled the mandatory variables and is
  unaffected. Variable metadata is now fetched once per `get_data()` call
  and shared between this check and the chunk planner.
  All three reported in `paket/DEV_BACKLOG.md` 2026-08-20.

## Documentation

- **Examples that omitted a mandatory variable are corrected.** The new
  check turned up several `TAB638` examples in `get_data()`,
  `data_legend()`, `data_minimize()`, `data_comments()`, `px_cite()`,
  `compose_data_query()` and `execute_query()`, plus two README snippets,
  that left out `ContentsCode`. They had been quietly returning `NULL`
  against the live API; they now pass `ContentsCode = "*"`. The vignettes
  were already correct.
- **`table_enrich()`'s example no longer writes into the working
  directory.** It opened a cache at the literal path `"cache.sqlite"`,
  which `R CMD check` flags as a non-standard file in the check directory.
  It now uses `tempfile()`. This had been masked: the example run used to
  abort earlier, at one of the `TAB638` examples above, before reaching it.

# pixieweb 0.1.1.9005

## New features

- **Tillväxtanalys added to the API catalogue** (alias `tva`), bringing the
  catalogue to 14 sources. A PxWeb **v1** instance, Swedish only, at
  `https://statistik.tillvaxtanalys.se/PxWeb/api/v1` — the statistics
  authority for Swedish business demography: bankruptcies and composition
  proceedings, new enterprises, foreign-owned firms, and groups with
  subsidiaries abroad. Verified with `get_tables()` (14 bankruptcy tables
  found) and `get_data()` (monthly bankruptcies by industry, 2009M01–,
  1 688 observations over eight industries).
  Its database id and every folder segment are clear-text strings with
  spaces and åäö ("Konkurser och offentliga ackord"), the same shape as the
  `sjv` entry — `px_encode_path()` (0.1.1.9003) already handles it, so no
  code change was needed. Reported in `paket/DEV_BACKLOG.md` 2026-08-20.

# pixieweb 0.1.1.9004

## Bug fixes

- **v1 auto-chunking no longer crashes** (`"Variable selection must be a
  character vector or a px_*() helper"`): v1 variable metadata stores value
  codes as list-columns, and the chunk splitter passed those lists straight
  into the per-chunk selections. Codes are now normalized to character in
  `check_query_size()`, and chunked v1 fetches verified byte-identical to
  unchunked ones (konj Indikatorm.px, 30 828 cells / 3 chunks).
- **Split-variable choice ignores eliminated variables correctly**: the
  splittable set was subset with a logical index of the wrong length when a
  variable was eliminated (assigning `NULL` into a list removes the element);
  now indexed by name.
- **Leading wildcards fail loudly**: SCB's v2 search rejects a wildcard at
  the start of a term with HTTP 500, which surfaced as a silent zero-hit
  warning. `get_tables()` now raises an informative error suggesting a
  trailing wildcard or client-side `table_search()`. Documentation no longer
  claims mid-term wildcards work, and notes that legacy subject-area codes
  ("MI0107") are not indexed by the v2 search.

# pixieweb 0.1.1.9003

## Bug fixes

- **v1 catalog walks now reach databases with spaces in their ids** (e.g.
  sjv's "Jordbruksverkets statistikdatabas"): all v1 URL path segments are
  percent-encoded via the new internal `px_encode_path()`. Previously
  `get_tables()` silently returned zero tables for such APIs.
- **msb catalogue entry updated**: MSB's statistics moved to MCF —
  `https://statistik.mcf.se/PXWeb/api/v1`.

## New features

- **Clear-text `subject_path` for v1 tree walks**: the walk now accumulates
  each folder's text label, so v1 tables get a readable subject path
  ("Folkhälsodata/ANDTS/…") instead of `NA`.
- **`px_range(from)` without `to`** is now an open-ended range (equivalent
  to `px_from(from)`), so stored query specs can express "from year X
  onwards" without hard-coding an end period.
- **`px_api()` config fetches are memoized** per base_url (24 h TTL) —
  saves an ~80–100 ms round-trip on every repeated `px_api()` call.

# pixieweb 0.1.1.9002

## New features

- **`get_variables()` gains `cache` and `cache_location` arguments**,
  matching the interface of `get_tables()` and `get_data()`. Variable
  metadata can now be cached to the shared SQLite backend via an
  `nxt_handle` from nordstatExtras, or to the legacy `.rds` directory.
  Previously, callers that passed these arguments (reasonably assuming
  parity with the other `get_*` functions) received a silent error via
  consumer-side `tryCatch` wrapping.

## Documentation

- **`get_tables(query = ...)` documentation now covers wildcard
  behaviour.** On v2 APIs the server-side search is an exact token
  match by default; `"befolk"` will not find `"befolkning"`. Use
  explicit wildcards (`"befolk*"`, `"*arbets*"`) for prefix or
  substring matching.

# pixieweb 0.1.1.9001

## Bug fixes

- **`get_tables()` now paginates transparently on v2 APIs.** Previously,
  the v2 code path sent a single request with `pageSize = max_results`
  (default 100). For SCB, which holds tens of thousands of tables,
  users had to discover the undocumented workaround of setting
  `max_results = 100000L` to avoid silently capped results. The new
  implementation loops over `pageNumber` in 1000-row chunks, stopping
  when the API reports `totalPages` reached, when `max_results` is
  satisfied, when a short page is returned, or at a 50000-row safety
  cap for the rare "no filter, no `max_results`" full-listing case.
  `max_results = NULL` (the default) now means "all matching tables",
  consistent with `rKolada::get_kpi()` and `rTrafa::get_products()`.
  A user query for "befolkning" on SCB that previously returned 100
  tables now returns all 205 in roughly 1 second.

- **`get_tables(query = ...)` now URL-encodes the query parameter.**
  Previously, `get_tables_v2` built the request URL with a plain
  `paste()` call, unlike the v1 code path which correctly used
  `utils::URLencode()`. As a result, any search term containing
  non-ASCII characters (å/ä/ö, accented letters, spaces, punctuation)
  silently returned zero tables even when matching tables existed. For
  SCB searches this meant almost all Swedish queries failed. Verified
  against the SCB API: `query = "arbetslöshet"` now correctly returns
  tables such as TAB203 *Arbetslösa 16-64 år (AKU)*.

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
