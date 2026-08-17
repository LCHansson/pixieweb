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
