# get_contents(): the unit per measure (dev-backlog 2026-09-12, two entries:
# v2 metadata dropped `category$unit`; v1 only states the unit in json-stat2).

meta_fixture <- function() {
  list(
    id = list("Region", "ContentsCode", "Tid"),
    role = list(time = list("Tid"), metric = list("ContentsCode")),
    dimension = list(
      Region = list(label = "region", category = list(label = list(`00` = "Riket"))),
      ContentsCode = list(
        label = "contents",
        category = list(
          label = list(A1 = "Income", A2 = "Cost"),
          unit = list(A1 = list(base = "tkr", decimals = 0L),
                      A2 = list(base = "mnkr", decimals = 1L))
        ),
        extension = list(
          measuringType = list(A1 = "Flow", A2 = "Stock"),
          priceType = list(A1 = "Current"),
          refperiod = list(A1 = "During the year", A2 = "31 December")
        )
      ),
      Tid = list(label = "year", category = list(label = list(`2024` = "2024")))
    )
  )
}

test_that("parse_contents reads unit and measurement fields per code", {
  out <- parse_contents(meta_fixture(), "TAB1")
  expect_equal(out$table_id, c("TAB1", "TAB1"))
  expect_equal(out$variable, c("ContentsCode", "ContentsCode"))
  expect_equal(out$code, c("A1", "A2"))
  expect_equal(out$text, c("Income", "Cost"))
  expect_equal(out$unit, c("tkr", "mnkr"))
  expect_equal(out$decimals, c(0L, 1L))
  expect_equal(out$measuring_type, c("Flow", "Stock"))
  # A field the source states for one code only is NA for the other
  expect_equal(out$price_type, c("Current", NA))
  expect_equal(out$adjustment, c(NA_character_, NA_character_))
})

test_that("parse_contents finds the contents dimension without a role", {
  raw <- meta_fixture()
  raw$role$metric <- NULL
  expect_equal(parse_contents(raw, "T")$unit, c("tkr", "mnkr"))
  # v1 shape: the variable keeps its own name, the unit may lack a base
  raw$dimension$Measure <- raw$dimension$ContentsCode
  raw$dimension$ContentsCode <- NULL
  raw$dimension$Measure$category$unit <- list(A1 = list(decimals = 1L),
                                              A2 = list(decimals = 1L))
  out <- parse_contents(raw, "T")
  expect_equal(out$variable, c("Measure", "Measure"))
  expect_equal(out$unit, c(NA_character_, NA_character_))
  expect_equal(out$decimals, c(1L, 1L))
})

test_that("a table without a contents dimension gives zero rows, same columns", {
  raw <- meta_fixture()
  raw$role$metric <- NULL
  raw$dimension$ContentsCode <- NULL
  out <- parse_contents(raw, "T")
  expect_equal(nrow(out), 0)
  expect_equal(names(out), names(parse_contents(meta_fixture(), "T")))
})

test_that("get_contents() v2 makes one metadata request", {
  calls <- character()
  testthat::local_mocked_bindings(px_get = function(url, ...) {
    calls <<- c(calls, url)
    meta_fixture()
  })
  api <- structure(list(base_url = "https://x/api/v2", alias = "t", lang = "sv",
                        version = "v2", config = NULL), class = "px_api")
  out <- get_contents(api, "TAB1")
  expect_equal(out$unit, c("tkr", "mnkr"))
  expect_length(calls, 1)
  expect_match(calls, "tables/TAB1/metadata", fixed = TRUE)
})

test_that("get_contents() v1 probes one cell, then widens the contents variable", {
  bodies <- list()
  vars <- tibble::tibble(
    code = c("Measure", "Year"), n_values = c(2L, 3L),
    values = list(tibble::tibble(code = c("A1", "A2"), text = c("Income", "Cost")),
                  tibble::tibble(code = c("2022", "2023", "2024"),
                                 text = c("2022", "2023", "2024")))
  )
  testthat::local_mocked_bindings(
    get_variables = function(...) vars,
    execute_query = function(api, url, body, ...) {
      bodies[[length(bodies) + 1]] <<- body
      raw <- meta_fixture()
      raw$role$metric <- NULL
      raw$dimension$Measure <- raw$dimension$ContentsCode
      raw$dimension$ContentsCode <- NULL
      raw
    }
  )
  api <- structure(list(base_url = "https://x/api/v1", alias = "t", lang = "sv",
                        version = "v1",
                        config = list(max_calls = 1000, time_window = 1)),
                   class = "px_api")
  out <- get_contents(api, "A/B.px")
  expect_equal(out$variable, c("Measure", "Measure"))
  expect_equal(out$unit, c("tkr", "mnkr"))
  expect_length(bodies, 2)
  expect_equal(bodies[[1]]$response$format, "json-stat2")
  # First request: one value per variable. Second: every measure, one year.
  expect_equal(bodies[[1]]$query[[1]]$selection$values, list("A1"))
  expect_equal(bodies[[2]]$query[[1]]$selection$filter, "all")
  expect_equal(bodies[[2]]$query[[2]]$selection$values, list("2022"))
})

test_that("live: SCB v2 states a unit for every measure of TAB638", {
  skip_on_cran()
  scb <- px_api("scb", lang = "en")
  skip_if_not(px_available(scb), "SCB API not reachable")
  out <- get_contents(scb, "TAB638")
  skip_if(is.null(out), "No metadata returned")
  expect_gt(nrow(out), 0)
  expect_true(all(out$variable == "ContentsCode"))
  expect_true(all(!is.na(out$unit) & nzchar(out$unit)))
})
