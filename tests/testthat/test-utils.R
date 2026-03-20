# Unit tests for internal utility functions

test_that("px_url joins path segments", {
  expect_equal(rpx:::px_url("https://api.scb.se", "v2", "tables"),
               "https://api.scb.se/v2/tables")
})

test_that("px_url strips trailing slashes", {
  expect_equal(rpx:::px_url("https://api.scb.se/", "v2/"),
               "https://api.scb.se/v2")
})

test_that("px_url_query appends parameters", {
  url <- rpx:::px_url_query("https://example.com/api", lang = "en", page = "1")
  expect_match(url, "lang=en")
  expect_match(url, "page=1")
  expect_match(url, "^https://example.com/api\\?")
})

test_that("px_url_query drops NULL params", {
  url <- rpx:::px_url_query("https://example.com", a = "1", b = NULL)
  expect_match(url, "a=1")
  expect_no_match(url, "b=")
})

test_that("check_px_api rejects non-px_api objects", {
  expect_error(rpx:::check_px_api("not an api"), "px_api")
  expect_error(rpx:::check_px_api(list(a = 1)), "px_api")
})

test_that("remove_monotonous removes constant columns", {
  df <- tibble::tibble(a = c(1, 1, 1), b = c(1, 2, 3))
  result <- rpx:::remove_monotonous(df)
  expect_equal(names(result), "b")
})

test_that("remove_monotonous keeps all columns when nothing is monotonous", {
  df <- tibble::tibble(a = c(1, 2), b = c(3, 4))
  result <- rpx:::remove_monotonous(df)
  expect_equal(names(result), c("a", "b"))
})

test_that("remove_monotonous is a no-op for single-row tibbles", {
  df <- tibble::tibble(a = 1, b = 2)
  result <- rpx:::remove_monotonous(df)
  expect_equal(ncol(result), 2)
})

test_that("entity_search filters by character columns", {
  df <- tibble::tibble(
    id = c("T1", "T2", "T3"),
    title = c("Population by age", "Income by region", "Population by sex")
  )
  result <- rpx:::entity_search(df, "population")
  expect_equal(nrow(result), 2)
  expect_equal(result$id, c("T1", "T3"))
})

test_that("entity_search supports multiple search terms (OR)", {
  df <- tibble::tibble(
    id = c("T1", "T2", "T3"),
    title = c("Population", "Income", "Exports")
  )
  result <- rpx:::entity_search(df, c("population", "exports"))
  expect_equal(nrow(result), 2)
})

test_that("entity_search respects column parameter", {
  df <- tibble::tibble(
    id = c("POP1", "INC1"),
    title = c("Something", "Population data")
  )
  result <- rpx:::entity_search(df, "pop", column = "id")
  expect_equal(nrow(result), 1)
  expect_equal(result$id, "POP1")
})

test_that("entity_search searches list columns", {
  df <- tibble::tibble(
    id = c("T1", "T2"),
    title = c("Table one", "Table two"),
    variables = list(c("Region", "Tid"), c("Alder", "Kon"))
  )
  result <- rpx:::entity_search(df, "region")
  expect_equal(nrow(result), 1)
  expect_equal(result$id, "T1")
})

test_that("entity_search warns on empty input", {
  df <- tibble::tibble(id = character(), title = character())
  expect_warning(rpx:::entity_search(df, "test"), "empty")
})
