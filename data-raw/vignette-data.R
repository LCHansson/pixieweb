# Pre-cache API data for vignettes
# Run this script manually: Rscript data-raw/vignette-data.R
# Output: R/sysdata.rda (internal package data)
#
# The cached objects are prefixed `vd_` and are referenced from the
# vignettes via `pixieweb:::vd_*`, mirroring the same pattern used in the
# sibling packages rKolada and rTrafa. Caching the API responses keeps the
# vignettes CRAN-safe (no network calls at build time) and lets us show
# live output for tables, variables, data frames and plots.

library("pixieweb")

stopifnot(px_available(px_api("scb")))

# --- API objects ---------------------------------------------------------

# Use Statistics Sweden as the example API throughout the vignettes.
vd_scb <- px_api("scb", lang = "en")

# Full catalogue of known PX-Web instances (printed in multi-api vignette)
vd_catalogue <- px_api_catalogue()

# --- Table discovery -----------------------------------------------------

# Pedagogical example table throughout the vignettes: SCB's TAB638
# (Population by region, marital status, age, sex and year). It has
# both eliminable variables (Civilstand, Alder, Kon) and mandatory
# ones (Region, ContentsCode, Tid), which lets us showcase the full
# pixieweb data model.
vd_table_id <- "TAB638"

# Server-side search for population tables. The vignette code shows
# `get_tables(scb, query = "population")` with eval=FALSE; this cache
# provides the matching output. We make sure TAB638 is in the result
# set so `table_search()` examples downstream work as expected.
search_tables <- get_tables(vd_scb, query = "population", max_results = 25)
tab_row <- get_tables(vd_scb, id = vd_table_id)
vd_tables <- dplyr::bind_rows(
  tab_row,
  search_tables[search_tables$id != vd_table_id, ]
)
attr(vd_tables, "px_api") <- vd_scb

# --- Variables (dimensions) ----------------------------------------------

vd_variables <- get_variables(vd_scb, vd_table_id)

# Values of the Region variable
vd_region_values <- variable_values(vd_variables, "Region")

# --- Data ----------------------------------------------------------------

# Three largest municipalities: Stockholm, Gothenburg, Malmö
region_codes <- c("0180", "1480", "1280")

vd_pop <- get_data(
  vd_scb, vd_table_id,
  Region = region_codes,
  ContentsCode = "*",
  Tid = px_top(5)
)

# Prepared query object (printed in vignette)
vd_prepared_query <- prepare_query(
  vd_scb, vd_table_id,
  Region = region_codes
)

# Wide output example (single region, all content codes)
vd_wide <- get_data(
  vd_scb, vd_table_id,
  Region = region_codes[1],
  ContentsCode = "*",
  Tid = px_top(5),
  .output = "wide"
)

# Codelists for the Region variable (aggregations like county, NUTS region)
vd_codelists <- get_codelists(vd_scb, vd_table_id, "Region")

# Citation string for the downloaded data
vd_citation <- px_cite(vd_pop)

# --- Save as internal package data --------------------------------------

usethis::use_data(
  vd_scb,
  vd_catalogue,
  vd_tables,
  vd_table_id,
  vd_variables,
  vd_region_values,
  vd_pop,
  vd_prepared_query,
  vd_wide,
  vd_codelists,
  vd_citation,
  overwrite = TRUE,
  internal = TRUE
)
