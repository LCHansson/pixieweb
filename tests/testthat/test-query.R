# Unit tests for query composition

test_that("compose_table_query builds v2 URL with lang", {
  api <- structure(
    list(base_url = "https://api.scb.se/ov0104/v2beta/api/v2",
         alias = "scb", lang = "en", version = "v2", config = NULL),
    class = "px_api"
  )

  url <- compose_table_query(api, query = "population")
  expect_match(url, "lang=en")
  expect_match(url, "query=population")
  expect_match(url, "/tables")
})

test_that("compose_table_query with id returns single-table URL", {
  api <- structure(
    list(base_url = "https://api.scb.se/ov0104/v2beta/api/v2",
         alias = "scb", lang = "en", version = "v2", config = NULL),
    class = "px_api"
  )

  url <- compose_table_query(api, id = "TAB638")
  expect_match(url, "tables/TAB638")
})

test_that("compose_data_query builds v2 body with selections", {
  api <- structure(
    list(base_url = "https://api.scb.se/ov0104/v2beta/api/v2",
         alias = "scb", lang = "en", version = "v2", config = NULL),
    class = "px_api"
  )

  q <- compose_data_query(api, "TAB638",
                          Region = c("0180"),
                          Tid = px_top(5))

  expect_match(q$url, "TAB638/data")
  expect_match(q$url, "json-stat2")
  expect_true(is.list(q$body))
  expect_true("selection" %in% names(q$body))

  # Check that selections are properly structured
  sel_codes <- vapply(q$body$selection, function(s) s$variableCode, character(1))
  expect_true("Region" %in% sel_codes)
  expect_true("Tid" %in% sel_codes)
})

test_that("compose_table_query errors on v1", {
  api <- structure(
    list(base_url = "https://data.ssb.no/api/v0",
         alias = "ssb", lang = "no", version = "v1", config = NULL),
    class = "px_api"
  )

  expect_error(compose_table_query(api, query = "population"), "v2")
})

test_that("compose_data_query builds v1 body", {
  api <- structure(
    list(base_url = "https://data.ssb.no/api/v0",
         alias = "ssb", lang = "no", version = "v1", config = NULL),
    class = "px_api"
  )

  q <- compose_data_query(api, "01222", Region = c("0301"))

  expect_true("query" %in% names(q$body))
  expect_true("response" %in% names(q$body))
  expect_equal(q$body$response$format, "json")
})

test_that("compose_data_query includes codelist", {
  api <- structure(
    list(base_url = "https://api.scb.se/ov0104/v2beta/api/v2",
         alias = "scb", lang = "en", version = "v2", config = NULL),
    class = "px_api"
  )

  q <- compose_data_query(api, "TAB638",
                          Region = "*",
                          .codelist = list(Region = "agg_RegionLan"))

  region_sel <- Filter(
    function(s) s$variableCode == "Region",
    q$body$selection
  )[[1]]
  expect_equal(region_sel$codeList, "agg_RegionLan")
})
