# Enrich a table tibble with full metadata

Fetches the metadata endpoint for each table and adds columns with
notes, contents description, contact information, and more. This is an
extra API call per table, so it's separated from
[`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md)
to give users control over when the cost is incurred.

## Usage

``` r
table_enrich(
  table_df,
  api = NULL,
  cache = FALSE,
  cache_location = pixieweb_cache_dir,
  async = FALSE,
  verbose = FALSE
)
```

## Arguments

- table_df:

  A tibble returned by
  [`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md).

- api:

  A `<px_api>` object. Optional — if omitted, the API connection stored
  by
  [`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md)
  is used automatically.

- cache:

  Logical. If `TRUE`, stores the enriched result locally and loads it on
  subsequent calls instead of re-fetching metadata.

- cache_location:

  Either a directory path (legacy `.rds` cache), a path to a `.sqlite`
  file, or an `nxt_handle` from
  [`nordstatExtras::nxt_open()`](https://rdrr.io/pkg/nordstatExtras/man/nxt_open.html).
  Defaults to
  [`pixieweb_cache_dir()`](https://lchansson.github.io/pixieweb/reference/pixieweb_cache_dir.md).

- async:

  Logical. When `TRUE` (and `cache_location` is a SQLite backend),
  missing rows are fetched in a background `mirai` task;
  `table_enrich()` returns immediately with the currently-cached subset
  plus NA placeholders for pending rows. The return value carries
  `attr(x, "nxt_pending_ids")` (IDs still fetching) and
  `attr(x, "nxt_promise")` (a `mirai` task the caller can await or
  bridge to `promises::then()`). Ignored when the backend is not SQLite
  or when `cache = FALSE`.

- verbose:

  Print request details.

## Value

The input tibble with additional columns: `notes`, `contents`,
`subject_area`, `official_statistics`, `contact`.

## Details

When `cache_location` points at a SQLite file (or `nxt_handle` from the
nordstatExtras package) the cache is **per table** rather than per
enrich call. That gives three properties you don't get from the legacy
`.rds` path: (1) enrichment results are reused across any
`table_enrich()` call that touches the same `table_id`; (2) a long
enrich run can be interrupted and resumes from where it left off; and
(3) with `async = TRUE`, the call returns immediately with whatever is
already cached and keeps fetching in the background.

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {

  # API is picked up automatically from the tibble
  get_tables(scb, query = "population", max_results = 5) |>
    table_enrich() |>
    table_describe()

  # Cache enriched results for offline use (legacy .rds path)
  get_tables(scb, query = "population", cache = TRUE) |>
    table_enrich(cache = TRUE)

  # Per-table cache in a shared SQLite file
  handle <- nordstatExtras::nxt_open("cache.sqlite")
  get_tables(scb, query = "population", cache = TRUE,
             cache_location = handle) |>
    table_enrich(cache = TRUE, cache_location = handle)
}# }
#> ℹ Enriching 5 table(s) with metadata.
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■■■■         80% | ETA:  1s
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100% | ETA:  0s
#> ── TAB1743: Income standard (median) for families with children aged 0-17 living at home, by population groups. Year 1995-2013  
#>   Contents: Income standard (median) for families with children living at home aged 0-17
#>   Subject: Living conditions
#>   Period: 1995 – 2013 (Annual)
#>   Updated: 2015-10-01T07:30:00Z
#>   Category: public
#>   Variables: population group, observations, year
#>   Source: Statistics Sweden
#>   Contact: Nikolaus Koutakis, Statistics Sweden
#>   Official statistics: Yes 
#> 
#> ── TAB934: Family´s disposable income per consumption unit in SEK thousands. Children in families living at home aged 0-17, by population groups. Year 1995-2013  
#>   Contents: Family´s disposable income per consumption unit in families with children living at home aged 0-17
#>   Subject: Living conditions
#>   Period: 1995 – 2013 (Annual)
#>   Updated: 2015-10-01T07:30:00Z
#>   Category: public
#>   Variables: population group, observations, year
#>   Source: Statistics Sweden
#>   Contact: Nikolaus Koutakis, Statistics Sweden
#>   Official statistics: Yes 
#> 
#> ── TAB4552: Population connected to public network. Year 1960-2023 ────────────── 
#>   Contents: Population connected to public network
#>   Subject: Environment
#>   Period: 1960 – 2023 (Annual)
#>   Updated: 2025-06-12T06:00:00Z
#>   Category: public
#>   Variables: type of network, observations, year
#>   Source: Statistics Sweden
#>   Contact: Jerker Moström, Statistics Sweden
#>   Official statistics: Yes 
#>   Notes:
#>     This table contains data on usual resident population connected to
#>     public water and waste water services. The information is organised in
#>     order to enable studies on the long-term trend on national level. Data
#>     covers the situation every fifth year from the 1960s up to present
#>     date. Data from 1960 - 1995 are based on information collected by the
#>     Swedish Water and Wastewater Association. As full completeness of these
#>     early surveys cannot be fully guaranteed, caution should be exercised
#>     when comparing changes over time. Data covering the situation from 2000
#>     and onwards, are based on the Real Estate Tax Assessment Register in
#>     combination with data from the Total Population Register. For regional
#>     break-down of statistics on water and wastewater services, use the
#>     following tables: -Number of one- or two-dwelling units by region, type
#>     of real estate and wastewater disposal methods.  -Number of one- or
#>     two-dwelling units by region, type of real estates and source of water.
#>     -Population by region and source of water.  -Population by region and
#>     type of wastewater disposal methods. 
#> 
#> ── TAB6473: Population statistics by region and sex.  Month 2025M01-2026M02 ───── 
#>   Contents: Population
#>   Subject: Population
#>   Period: 2025M01 – 2026M02 (Monthly)
#>   Updated: 2026-04-10T06:00:00Z
#>   Category: public
#>   Variables: region, population changes, sex, observations, month
#>   Source: Statistics Sweden
#>   Contact: Statistikservice, Statistics Sweden
#>   Official statistics: Yes 
#>   Notes:
#>     From the reference year 2025 onwards, a small controlled random
#>     uncertainty is introduced in all reported data. The uncertainty has
#>     been added to protect individuals so that no one risks being exposed in
#>     the statistics. As a result, the reported totals are not always equal
#>     to the sum of their reported components.  If reported statistical
#>     values are added together to create a new total, the uncertainty is
#>     also added. There is therefore a risk that the new total contains
#>     greater uncertainty than that which – under the method – would have
#>     been added to a single value.  The method used for disclosure control
#>     is called Cell Key Method (CKM). You can read more about the method
#>     here: <a
#>     href='https://www.scb.se/en/documentation/statististical-methods/protection-methods-for-disclosure-control/'>Protection
#>     methods for disclosure control</a> and here: <a
#>     href='https://www.scb.se/en/documentation/statistical-areas-under-change/development-of-disclosure-protection/'>Development
#>     of disclosure protection.</a> 
#>     Population Changes (Births, Deaths and Migrations) are reported
#>     according to the regional division at the beginning of the year (1
#>     January). 
#>     Events that cannot be traced to a specific month during the year are
#>     reported on January. It is usually deaths that are affected. 
#>     Population growth is defined as the difference between the population
#>     at the beginning and end of the month. Some of the population increase
#>     cannot be explained by a birth surplus and Net Migration during the
#>     Month and the difference is reported as a Adjustment. 
#>     The population as of December 31 (Month 20XXM12) refers to the regional
#>     division of January 1 the following year. The population as of 31
#>     March, 30 June and 30 September refers to the regional division at the
#>     beginning of the year (1 January). Information about the population
#>     size is reported about 5-6 weeks after the time of measurement and is
#>     not revised afterwards in this table. 
#>     The statistics of births, deaths and migrations for the last calendar
#>     year are preliminary and will be revised until the statistics for
#>     December are published (month 20XXM12). The statistics for previous
#>     years are final and will not be revised. 
#>     Statistics for 2024 and previous years are available here: <a
#>     href='https://www.statistikdatabasen.scb.se/pxweb/en/ssd/START__BE__BE0101__BE0101G/ManadBefStatRegion/'>Population
#>     statistics by region and sex.. Year 2000-2024</a> 
#> 
#> ── TAB1625: Population statistics by region and sex. Month 2000M01-2024M12 ────── 
#>   Contents: Population
#>   Subject: Population
#>   Period: 2000M01 – 2024M12 (Monthly)
#>   Updated: 2025-02-21T07:00:00Z
#>   Category: public
#>   Variables: region, population changes, sex, observations, month
#>   Source: Statistics Sweden
#>   Contact: Statistikservice, Statistics Sweden
#>   Official statistics: Yes 
#>   Notes:
#>     Population Changes (Births, Deaths and Migrations) are reported
#>     according to the regional division at the beginning of the year (1
#>     January). 
#>     Events that cannot be traced to a specific month during the year are
#>     reported on January. It is usually deaths that are affected. 
#>     Population growth is defined as the difference between the population
#>     at the beginning and end of the month. Some of the population increase
#>     cannot be explained by a birth surplus and Net Migration during the
#>     Month and the difference is reported as a Adjustment. 
#>     The population as of December 31 (Month 20XXM12) refers to the regional
#>     division of January 1 the following year. The population as of 31
#>     March, 30 June and 30 September refers to the regional division at the
#>     beginning of the year (1 January). Information about the population
#>     size is reported about 5-6 weeks after the time of measurement and is
#>     not revised afterwards in this table. 
#>     The statistics of births, deaths and migrations for the last calendar
#>     year are preliminary and will be revised until the statistics for
#>     December are published (month 20XXM12). The statistics for previous
#>     years are final and will not be revised. 
#>     Statistict for 2025 and onwards are available here: <a
#>     href='https://www.statistikdatabasen.scb.se/pxweb/en/ssd/START__BE__BE0101__BE0101G/MBefStatRegionCKM/'>Population
#>     statistics by region and sex. Year 2025--</a> 
#> 
#> ℹ Enriching 100 table(s) with metadata.
#> Fetching metadata ■■                                 3% | ETA: 36s
#> Fetching metadata ■■■                                7% | ETA: 45s
#> Fetching metadata ■■■■                              11% | ETA:  1m
#> Fetching metadata ■■■■■■                            16% | ETA:  1m
#> Fetching metadata ■■■■■■■                           19% | ETA:  1m
#> Fetching metadata ■■■■■■■■                          23% | ETA:  1m
#> Fetching metadata ■■■■■■■■■■                        29% | ETA: 46s
#> Fetching metadata ■■■■■■■■■■■                       34% | ETA: 42s
#> Fetching metadata ■■■■■■■■■■■■■                     39% | ETA: 38s
#> Fetching metadata ■■■■■■■■■■■■■■                    43% | ETA: 36s
#> Fetching metadata ■■■■■■■■■■■■■■■                   47% | ETA: 34s
#> Fetching metadata ■■■■■■■■■■■■■■■■■                 52% | ETA: 31s
#> Fetching metadata ■■■■■■■■■■■■■■■■■■                56% | ETA: 29s
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■               60% | ETA: 26s
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■              64% | ETA: 24s
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■             68% | ETA: 21s
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■■           72% | ETA: 19s
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■■■          77% | ETA: 15s
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■■■■■        82% | ETA: 12s
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■■■■■■       86% | ETA:  9s
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■■■■■■■      90% | ETA:  7s
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■     93% | ETA:  5s
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■    98% | ETA:  1s
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100% | ETA:  0s
#> ℹ Enriching 100 table(s) with metadata.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■                                 3% | ETA: 37s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■                               9% | ETA: 41s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■■                             15% | ETA: 40s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■■■■■                          22% | ETA: 37s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■■■■■■                         28% | ETA: 34s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■■■■■■■■                       34% | ETA: 32s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■■■■■■■■■■                     40% | ETA: 29s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■■■■■■■■■■■■                   46% | ETA: 26s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■■■■■■■■■■■■■■                 52% | ETA: 23s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■               59% | ETA: 20s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■             65% | ETA: 17s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■            71% | ETA: 14s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■■■          77% | ETA: 11s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■■■■■        83% | ETA:  8s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■■■■■■■      89% | ETA:  5s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■     95% | ETA:  2s
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Warning: Unknown or uninitialised column: `description`.
#> Warning: Unknown or uninitialised column: `id`.
#> Warning: Unknown or uninitialised column: `title`.
#> Fetching metadata ■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■  100% | ETA:  0s
#> # A tibble: 100 × 18
#>    id      title description category updated first_period last_period time_unit
#>    <chr>   <chr> <chr>       <chr>    <chr>   <chr>        <chr>       <chr>    
#>  1 TAB1743 Inco… ""          public   2015-1… 1995         2013        Annual   
#>  2 TAB934  Fami… ""          public   2015-1… 1995         2013        Annual   
#>  3 TAB4552 Popu… ""          public   2025-0… 1960         2023        Annual   
#>  4 TAB6473 Popu… ""          public   2026-0… 2025M01      2026M02     Monthly  
#>  5 TAB1625 Popu… ""          public   2025-0… 2000M01      2024M12     Monthly  
#>  6 TAB6481 Popu… ""          public   2026-0… 2025         2025        Annual   
#>  7 TAB5169 Popu… ""          public   2025-0… 2000         2024        Annual   
#>  8 TAB4562 Popu… ""          public   2025-0… 2000         2023        Annual   
#>  9 TAB938  Fami… ""          public   2015-1… 1995         2013        Annual   
#> 10 TAB4951 Gain… ""          public   2022-0… 2015         2020        Annual   
#> # ℹ 90 more rows
#> # ℹ 10 more variables: variables <list>, subject_code <chr>,
#> #   subject_path <chr>, source <chr>, discontinued <lgl>, notes <list>,
#> #   contents <chr>, subject_area <chr>, official_statistics <lgl>,
#> #   contact <chr>
```
