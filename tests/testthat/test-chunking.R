# Offline tests for the auto-chunking split plan (check_query_size) and the
# leading-wildcard search error. No network required.

fake_api_v2 <- function() {
  structure(
    list(base_url = "https://example.com/api/v2",
         alias = "test", lang = "en", version = "v2",
         config = list(max_cells = 100000)),
    class = "px_api"
  )
}

# v2-style variable metadata: values tibbles with plain character columns
make_vars_v2 <- function() {
  tibble::tibble(
    code = c("Region", "Tid"),
    n_values = c(4L, 10L),
    values = list(
      tibble::tibble(code = paste0("R", 1:4), text = paste0("Region ", 1:4)),
      tibble::tibble(code = paste0("Y", 1:10), text = paste0("Year ", 1:10))
    )
  )
}

# v1-style variable metadata: values tibbles with LIST-columns (each code a
# length-1 list element) — this is what the v1 parser produces and what broke
# chunked selections (backlog 2026-08-03).
make_vars_v1 <- function() {
  tibble::tibble(
    code = c("Region", "Tid"),
    n_values = c(4L, 10L),
    values = list(
      tibble::tibble(code = as.list(paste0("R", 1:4)),
                     text = as.list(paste0("Region ", 1:4))),
      tibble::tibble(code = as.list(paste0("Y", 1:10)),
                     text = as.list(paste0("Year ", 1:10)))
    )
  )
}

test_that("split plan yields character split_values for v2-style metadata", {
  ci <- pixieweb:::check_query_size(
    list(Region = "*", Tid = "*"),
    api = fake_api_v2(), table_id = "X",
    max_cells = 12, verbose = FALSE, vars = make_vars_v2()
  )
  expect_true(ci$needs_chunking)
  expect_identical(ci$split_var, "Tid")
  expect_type(ci$split_values, "character")
  expect_identical(ci$split_values, paste0("Y", 1:10))
})

test_that("split plan yields character split_values for v1 list-column metadata", {
  ci <- pixieweb:::check_query_size(
    list(Region = "*", Tid = "*"),
    api = fake_api_v2(), table_id = "X",
    max_cells = 12, verbose = FALSE, vars = make_vars_v1()
  )
  expect_true(ci$needs_chunking)
  expect_identical(ci$split_var, "Tid")
  # Regression: these used to come back as a bare list, which
  # resolve_selection_v1() rejects when the chunk queries are composed.
  expect_type(ci$split_values, "character")
  expect_identical(ci$split_values, paste0("Y", 1:10))
})

test_that("eliminated variables do not distort the split-variable choice", {
  # Three variables where the ELIMINATED one has the most values. The old
  # logical-index subset recycled over the wrong length and could yield an
  # empty splittable set; indexing by name must pick 'Tid'.
  vars <- tibble::tibble(
    code = c("Elim", "Tid", "Small"),
    n_values = c(20L, 10L, 2L),
    values = list(
      tibble::tibble(code = paste0("E", 1:20), text = paste0("E", 1:20)),
      tibble::tibble(code = paste0("Y", 1:10), text = paste0("Y", 1:10)),
      tibble::tibble(code = c("a", "b"), text = c("a", "b"))
    )
  )
  ci <- pixieweb:::check_query_size(
    list(Tid = "*", Small = c("a", "b")),
    api = fake_api_v2(), table_id = "X",
    max_cells = 4, verbose = FALSE, vars = vars
  )
  expect_true(ci$needs_chunking)
  expect_identical(ci$split_var, "Tid")
  expect_identical(ci$split_values, paste0("Y", 1:10))
})

test_that("px_selection top over v1 list-column metadata gives character codes", {
  ci <- pixieweb:::check_query_size(
    list(Region = "*", Tid = px_top(6)),
    api = fake_api_v2(), table_id = "X",
    max_cells = 12, verbose = FALSE, vars = make_vars_v1()
  )
  expect_true(ci$needs_chunking)
  expect_type(ci$split_values, "character")
  expect_length(ci$split_values, 6)
})

test_that("leading wildcard that the API rejects raises an informative error", {
  api <- fake_api_v2()
  local_mocked_bindings(
    px_get = function(url, verbose = FALSE) NULL
  )
  expect_error(
    pixieweb:::get_tables_v2(api, query = "*arbets*", id = NULL,
                             updated_since = NULL, max_results = 10,
                             verbose = FALSE),
    "wildcard at the start"
  )
  # A failed request WITHOUT a leading wildcard keeps the old contract:
  # NULL result, no error.
  expect_null(
    pixieweb:::get_tables_v2(api, query = "arbets*", id = NULL,
                             updated_since = NULL, max_results = 10,
                             verbose = FALSE)
  )
})

# dev-backlog 2026-09-11 (2): from/to/range were counted as ALL values, so a
# ranged query was split more often than needed and, when split along the
# ranged variable, fetched values outside the range.
test_that("selection_codes resolves helpers to the codes the server returns", {
  codes <- paste0("Y", 1:10)
  expect_equal(selection_codes(px_from("Y8"), codes), c("Y8", "Y9", "Y10"))
  expect_equal(selection_codes(px_range("Y8"), codes), c("Y8", "Y9", "Y10"))
  expect_equal(selection_codes(px_to("Y2"), codes), c("Y1", "Y2"))
  expect_equal(selection_codes(px_range("Y3", "Y5"), codes), c("Y3", "Y4", "Y5"))
  # Unknown bound: the safe overestimate
  expect_equal(selection_codes(px_from("nope"), codes), codes)
  # top/bottom count from the latest period for a time variable
  expect_equal(selection_codes(px_top(2), codes, is_time = TRUE), c("Y9", "Y10"))
  expect_equal(selection_codes(px_bottom(2), codes, is_time = TRUE), c("Y1", "Y2"))
  expect_equal(selection_codes(px_top(2), codes), c("Y1", "Y2"))
  expect_equal(selection_codes(px_bottom(2), codes), c("Y9", "Y10"))
  expect_equal(selection_codes(px_all(), codes), codes)
})

test_that("a ranged selection is estimated by its own size, not all periods", {
  vars <- make_vars_v2()
  sel <- list(Region = "*", Tid = px_range("Y8"))
  fits <- check_query_size(sel, fake_api_v2(), "T1", max_cells = 12,
                           verbose = FALSE, vars = vars)
  expect_false(fits$needs_chunking)
  expect_equal(fits$estimated_cells, 12)
})

test_that("a split along a ranged variable stays inside the range", {
  vars <- make_vars_v2()
  sel <- list(Region = "R1", Tid = px_range("Y4", "Y9"))
  plan <- check_query_size(sel, fake_api_v2(), "T1", max_cells = 2,
                           verbose = FALSE, vars = vars)
  expect_true(plan$needs_chunking)
  expect_equal(plan$split_var, "Tid")
  expect_equal(plan$split_values, paste0("Y", 4:9))
  expect_equal(plan$n_chunks, 3)
})

# dev-backlog 2026-09-11 (1): v1 paced by the package default (30 calls per
# 10 s) because px_api() never read the instance's own limits.
test_that("v1 ?config is mapped to the fields the pacing code reads", {
  cfg <- parse_api_config_v1(list(maxValues = 1000L, maxCells = 100000L,
                                  maxCalls = 10L, timeWindow = 10L, CORS = TRUE))
  expect_equal(cfg, list(max_cells = 100000L, max_calls = 10L, time_window = 10L))
  expect_null(parse_api_config_v1(NULL))
  expect_null(parse_api_config_v1(list(error = "nope")))
  expect_null(parse_api_config_v1("<html>"))
  # A partial answer keeps the defaults for what is missing
  expect_equal(parse_api_config_v1(list(maxCalls = 5))$time_window, 10)
})

test_that("live: a v1 instance's own rate limit reaches the api object", {
  skip_on_cran()
  konj <- px_api("konj")
  skip_if_not(px_available(konj), "Konj API not reachable")
  skip_if(is.null(konj$config), "Konj did not answer ?config")
  expect_true(konj$config$max_cells > 0)
  expect_true(konj$config$max_calls > 0)
  expect_true(konj$config$time_window > 0)
})

test_that("live: chunking along a top() time selection returns the same periods", {
  skip_on_cran()
  scb <- px_api("scb", lang = "en")
  skip_if_not(px_available(scb), "SCB API not reachable")
  whole <- get_data(scb, "TAB638", Region = "0180", ContentsCode = "*",
                    Tid = px_top(4))
  skip_if(is.null(whole), "No data returned")
  n_contents <- length(unique(whole$ContentsCode))
  parts <- suppressMessages(get_data(scb, "TAB638", Region = "0180",
                                     ContentsCode = "*", Tid = px_top(4),
                                     max_results = 2 * n_contents))
  expect_equal(sort(unique(parts$Tid)), sort(unique(whole$Tid)))
  expect_equal(nrow(parts), nrow(whole))
})
