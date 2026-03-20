# Live API integration tests — skipped on CRAN and when offline

skip_on_cran()

test_that("px_api connects to SCB v2", {
  scb <- px_api("scb", lang = "en")
  skip_if_not(px_available(scb), "SCB API not reachable")

  expect_s3_class(scb, "px_api")
  expect_equal(scb$alias, "scb")
  expect_equal(scb$version, "v2")
  expect_true(!is.null(scb$config))
  expect_true(scb$config$max_cells > 0)
})

test_that("get_tables returns enriched tibble from SCB", {
  scb <- px_api("scb", lang = "en")
  skip_if_not(px_available(scb), "SCB API not reachable")

  tables <- get_tables(scb, query = "population", max_results = 5)
  expect_s3_class(tables, "tbl_df")
  expect_true(nrow(tables) > 0)

  # Verify enriched columns are present
  expected_cols <- c("id", "title", "description", "first_period",
                     "last_period", "time_unit", "subject_path", "source")
  for (col in expected_cols) {
    expect_true(col %in% names(tables), info = paste("Missing column:", col))
  }
})

test_that("get_variables returns variable metadata from SCB", {
  scb <- px_api("scb", lang = "en")
  skip_if_not(px_available(scb), "SCB API not reachable")

  vars <- get_variables(scb, "TAB638")
  expect_s3_class(vars, "tbl_df")
  expect_true(nrow(vars) > 0)

  expected_cols <- c("code", "text", "n_values", "elimination",
                     "time", "values", "codelists", "table_id")
  for (col in expected_cols) {
    expect_true(col %in% names(vars), info = paste("Missing column:", col))
  }

  # TAB638 should have a time variable

  expect_true(any(vars$time))
})

test_that("prepare_query produces valid query for SCB", {
  scb <- px_api("scb", lang = "en")
  skip_if_not(px_available(scb), "SCB API not reachable")

  q <- prepare_query(scb, "TAB638")
  expect_s3_class(q, "px_query")
  expect_equal(q$table_id, "TAB638")
  expect_true("ContentsCode" %in% names(q$selections))
})

test_that("get_data fetches real data from SCB", {
  scb <- px_api("scb", lang = "en")
  skip_if_not(px_available(scb), "SCB API not reachable")

  d <- get_data(scb, "TAB638",
                Region = "0180",
                ContentsCode = "*",
                Tid = px_top(3))

  expect_s3_class(d, "tbl_df")
  expect_true(nrow(d) > 0)
  expect_true("value" %in% names(d))
  expect_true("table_id" %in% names(d))
  expect_equal(unique(d$table_id), "TAB638")
})

test_that("get_data works with px_query object", {
  scb <- px_api("scb", lang = "en")
  skip_if_not(px_available(scb), "SCB API not reachable")

  q <- prepare_query(scb, "TAB638", Region = c("0180"))
  d <- get_data(scb, query = q)

  expect_s3_class(d, "tbl_df")
  expect_true(nrow(d) > 0)
})

test_that("table_search finds matches in enriched columns", {
  scb <- px_api("scb", lang = "sv")
  skip_if_not(px_available(scb), "SCB API not reachable")

  tables <- get_tables(scb, query = "fordon", max_results = 20)
  skip_if(is.null(tables) || nrow(tables) == 0, "No tables returned")

  # Search by variable name (searches list column)
  by_var <- table_search(tables, "fordonsslag")
  expect_true(nrow(by_var) > 0)
})

test_that("px_api_catalogue returns known APIs", {
  cat <- px_api_catalogue()
  expect_s3_class(cat, "tbl_df")
  expect_true("scb" %in% cat$alias)
  expect_true("ssb" %in% cat$alias)
})
