# Unit tests for prepare_query (mocked — no API calls)

# Helper: create a mock api + variables setup
mock_api <- function() {
  structure(
    list(
      base_url = "https://api.scb.se/ov0104/v2beta/api/v2",
      alias = "scb",
      description = "Statistics Sweden (SCB)",
      lang = "en",
      version = "v2",
      config = list(max_cells = 100000, max_calls = 30, time_window = 10)
    ),
    class = "px_api"
  )
}

mock_variables <- function() {
  tibble::tibble(
    code = c("Region", "Kon", "ContentsCode", "Tid"),
    text = c("region", "sex", "contents", "year"),
    n_values = c(290L, 3L, 2L, 50L),
    elimination = c(TRUE, TRUE, FALSE, FALSE),
    time = c(FALSE, FALSE, FALSE, TRUE),
    values = list(
      tibble::tibble(code = c("00", "0180"), text = c("Riket", "Stockholm")),
      tibble::tibble(code = c("1", "2", "1+2"), text = c("Male", "Female", "Total")),
      tibble::tibble(code = c("BE01", "BE02"), text = c("Population", "Change")),
      tibble::tibble(code = c("2020", "2021"), text = c("2020", "2021"))
    ),
    codelists = list(NULL, NULL, NULL, NULL),
    table_id = "TAB1"
  )
}

test_that("prepare_query assigns correct default categories", {
  api <- mock_api()
  vars <- mock_variables()

  local_mocked_bindings(
    get_variables = function(api, table_id, verbose = FALSE) vars
  )

  q <- prepare_query(api, "TAB1")

  # ContentsCode should be wildcarded
  expect_equal(q$selections$ContentsCode, "*")

  # Tid should be px_top(10)
  expect_s3_class(q$selections$Tid, "px_selection")
  expect_equal(q$selections$Tid$type, "top")

  # Region should be eliminated (NULL)
  expect_null(q$selections$Region)

  # Kon should be eliminated (NULL) — eliminable, even though small
  expect_null(q$selections$Kon)
})

test_that("prepare_query respects user overrides", {
  api <- mock_api()
  vars <- mock_variables()

  local_mocked_bindings(
    get_variables = function(api, table_id, verbose = FALSE) vars
  )

  q <- prepare_query(api, "TAB1", Region = c("0180", "1480"))

  expect_equal(q$selections$Region, c("0180", "1480"))
  expect_equal(q$reasons$Region, "user override")
  # Others should still have defaults
  expect_null(q$selections$Kon)
})

test_that("prepare_query handles all-mandatory variables", {
  api <- mock_api()
  vars <- tibble::tibble(
    code = c("Region", "Fordonsslag", "ContentsCode", "Tid"),
    text = c("region", "vehicle type", "contents", "year"),
    n_values = c(315L, 12L, 1L, 24L),
    elimination = c(FALSE, FALSE, FALSE, FALSE),
    time = c(FALSE, FALSE, FALSE, TRUE),
    values = list(
      tibble::tibble(code = "00", text = "Riket"),
      tibble::tibble(code = "10", text = "Cars"),
      tibble::tibble(code = "TK1", text = "Count"),
      tibble::tibble(code = "2024", text = "2024")
    ),
    codelists = list(NULL, NULL, NULL, NULL),
    table_id = "TAB2"
  )

  local_mocked_bindings(
    get_variables = function(api, table_id, verbose = FALSE) vars
  )

  q <- prepare_query(api, "TAB2")

  # Region (315) should get px_top(1) — too large for wildcard
  expect_s3_class(q$selections$Region, "px_selection")
  expect_equal(q$selections$Region$type, "top")
  expect_equal(q$selections$Region$values, "1")

  # Fordonsslag (12) should get wildcard — small mandatory
  expect_equal(q$selections$Fordonsslag, "*")

  # ContentsCode should always be wildcarded
  expect_equal(q$selections$ContentsCode, "*")
})

test_that("maximize_selection expands eliminated variables", {
  api <- mock_api()
  vars <- mock_variables()

  local_mocked_bindings(
    get_variables = function(api, table_id, verbose = FALSE) vars
  )

  q <- prepare_query(api, "TAB1", maximize_selection = TRUE)

  # Kon (3 values, was eliminated) should now be "*"
  expect_equal(q$selections$Kon, "*")
  expect_match(q$reasons$Kon, "maximize")
})

test_that("maximize_selection respects user overrides", {
  api <- mock_api()
  vars <- mock_variables()

  local_mocked_bindings(
    get_variables = function(api, table_id, verbose = FALSE) vars
  )

  q <- prepare_query(api, "TAB1",
                     Region = c("0180"),
                     maximize_selection = TRUE)

  # User override should be preserved

  expect_equal(q$selections$Region, c("0180"))
  expect_equal(q$reasons$Region, "user override")
})

test_that("compute_selection_sizes handles all selection types", {
  vars <- tibble::tibble(
    code = c("A", "B", "C", "D"),
    n_values = c(10L, 20L, 30L, 5L)
  )

  selections <- list(
    A = NULL,               # eliminated
    B = "*",                # wildcard
    C = c("x", "y", "z"),  # explicit items
    D = px_top(3)           # top N
  )

  sizes <- rpx:::compute_selection_sizes(selections, vars)
  expect_equal(sizes$A, 1)   # eliminated = 1
  expect_equal(sizes$B, 20)  # wildcard = n_values
  expect_equal(sizes$C, 3)   # 3 items
  expect_equal(sizes$D, 3)   # top(3)
})

test_that("print.px_query produces output", {
  api <- mock_api()
  vars <- mock_variables()

  local_mocked_bindings(
    get_variables = function(api, table_id, verbose = FALSE) vars
  )

  q <- prepare_query(api, "TAB1")
  expect_output(print(q), "Query: TAB1")
  expect_output(print(q), "Estimated cells")
})
