# Unit tests for table functions (mocked)

test_that("parse_table_v2 captures all metadata fields", {
  raw <- list(
    id = "TAB638",
    label = "Population by region",
    description = "Detailed population statistics",
    category = "public",
    updated = "2024-01-01T00:00:00Z",
    firstPeriod = "1968",
    lastPeriod = "2024",
    timeUnit = "Annual",
    variableNames = list("Region", "Tid"),
    source = "SCB",
    subjectCode = "BE",
    discontinued = FALSE,
    paths = list(list(
      list(id = "BE", label = "Population", sortCode = "01"),
      list(id = "BE0101", label = "Demographics", sortCode = "01")
    ))
  )

  api <- structure(list(alias = "scb", base_url = "https://api.scb.se"),
                   class = "px_api")
  result <- pixieweb:::parse_table_v2(raw, api)

  expect_equal(nrow(result), 1)
  expect_equal(result$id, "TAB638")
  expect_equal(result$title, "Population by region")
  expect_equal(result$description, "Detailed population statistics")
  expect_equal(result$first_period, "1968")
  expect_equal(result$last_period, "2024")
  expect_equal(result$time_unit, "Annual")
  expect_equal(result$source, "SCB")
  expect_equal(result$subject_code, "BE")
  expect_equal(result$subject_path, "Population > Demographics")
  expect_equal(as.character(result$variables[[1]]), c("Region", "Tid"))
})

test_that("parse_table_v2 handles missing fields gracefully", {
  raw <- list(id = "TAB1", label = "Minimal table")
  api <- structure(list(alias = "test", base_url = "https://example.com"),
                   class = "px_api")
  result <- pixieweb:::parse_table_v2(raw, api)

  expect_equal(result$id, "TAB1")
  expect_true(is.na(result$description))
  expect_true(is.na(result$first_period))
  expect_true(is.na(result$subject_path))
  expect_equal(result$discontinued, FALSE)
})

test_that("table_search finds matches in title", {
  df <- tibble::tibble(
    id = c("T1", "T2"),
    title = c("Population by region", "Income by sector"),
    description = c(NA, NA),
    category = c("public", "public"),
    updated = c("2024-01-01", "2024-01-01"),
    first_period = c("2000", "2000"),
    last_period = c("2024", "2024"),
    time_unit = c("Annual", "Annual"),
    variables = list(c("Region", "Tid"), c("Sector", "Tid")),
    subject_code = c("BE", "NR"),
    subject_path = c("Befolkning > Demografi", "Nationalräkenskaper"),
    source = c("scb", "scb"),
    discontinued = c(FALSE, FALSE)
  )

  expect_equal(nrow(table_search(df, "population")), 1)
  expect_equal(nrow(table_search(df, "region")), 1)  # title + variables both on T1
  expect_equal(nrow(table_search(df, "tid")), 2)     # in variables list of both rows
})

test_that("table_describe returns input invisibly", {
  df <- tibble::tibble(
    id = "T1", title = "Test", description = NA_character_,
    category = "public", updated = "2024-01-01",
    first_period = "2000", last_period = "2024", time_unit = "Annual",
    variables = list(c("Var1")),
    subject_code = "BE", subject_path = "Pop > Demo",
    source = "scb", discontinued = FALSE
  )

  result <- expect_output(table_describe(df))
  expect_identical(result, df)
})

test_that("table_describe warns on empty input", {
  df <- pixieweb:::empty_tables_tibble()
  expect_warning(table_describe(df), "No tables")
})

test_that("table_minimize removes constant columns", {
  df <- tibble::tibble(
    id = c("T1", "T2"),
    title = c("A", "B"),
    source = c("scb", "scb")
  )
  result <- table_minimize(df)
  expect_false("source" %in% names(result))
})

test_that("table_extract_ids returns id vector", {
  df <- tibble::tibble(id = c("T1", "T2"), title = c("A", "B"))
  expect_equal(table_extract_ids(df), c("T1", "T2"))
})

test_that("table_extract_ids returns empty vector for empty input", {
  expect_equal(table_extract_ids(NULL), character())
  expect_equal(table_extract_ids(tibble::tibble(id = character())), character())
})

# --- max_results validation (0.1.1.9006) ----------------------------------
# These never reach the network: the check runs before any request is built.

test_that("get_tables rejects a max_results that cannot become a pageSize", {
  api <- structure(
    list(base_url = "https://api.scb.se/ov0104/v2beta/api/v2",
         alias = "scb", lang = "sv", version = "v2", config = NULL),
    class = "px_api"
  )

  expect_error(get_tables(api, query = "x", max_results = NA), "max_results")
  expect_error(get_tables(api, query = "x", max_results = -3), "max_results")
  expect_error(get_tables(api, query = "x", max_results = 0), "max_results")
  expect_error(get_tables(api, query = "x", max_results = "10"), "max_results")
  expect_error(get_tables(api, query = "x", max_results = c(1, 2)), "max_results")
})

test_that("get_tables_v2 builds an encoded, paginated URL", {
  api <- structure(
    list(base_url = "https://api.scb.se/ov0104/v2beta/api/v2",
         alias = "scb", lang = "sv", version = "v2", config = NULL),
    class = "px_api"
  )

  base <- pixieweb:::api_url(api, "tables")
  url <- pixieweb:::px_url_append(
    base,
    list(query = "personbilar i trafik", pageSize = 1000L, pageNumber = 1L)
  )

  expect_equal(
    url,
    paste0("https://api.scb.se/ov0104/v2beta/api/v2/tables?lang=sv",
           "&query=personbilar%20i%20trafik&pageSize=1000&pageNumber=1")
  )
  # pageSize must never be a non-finite number (HTTP 400 from SCB).
  expect_no_match(url, "pageSize=Inf", fixed = TRUE)
})
