# Unit tests for internal utility functions

test_that("px_url joins path segments", {
  expect_equal(pixieweb:::px_url("https://api.scb.se", "v2", "tables"),
               "https://api.scb.se/v2/tables")
})

test_that("px_url strips trailing slashes", {
  expect_equal(pixieweb:::px_url("https://api.scb.se/", "v2/"),
               "https://api.scb.se/v2")
})

test_that("px_url_query appends parameters", {
  url <- pixieweb:::px_url_query("https://example.com/api", lang = "en", page = "1")
  expect_match(url, "lang=en")
  expect_match(url, "page=1")
  expect_match(url, "^https://example.com/api\\?")
})

test_that("px_url_query drops NULL params", {
  url <- pixieweb:::px_url_query("https://example.com", a = "1", b = NULL)
  expect_match(url, "a=1")
  expect_no_match(url, "b=")
})

test_that("check_px_api rejects non-px_api objects", {
  expect_error(pixieweb:::check_px_api("not an api"), "px_api")
  expect_error(pixieweb:::check_px_api(list(a = 1)), "px_api")
})

test_that("remove_monotonous removes constant columns", {
  df <- tibble::tibble(a = c(1, 1, 1), b = c(1, 2, 3))
  result <- pixieweb:::remove_monotonous(df)
  expect_equal(names(result), "b")
})

test_that("remove_monotonous keeps all columns when nothing is monotonous", {
  df <- tibble::tibble(a = c(1, 2), b = c(3, 4))
  result <- pixieweb:::remove_monotonous(df)
  expect_equal(names(result), c("a", "b"))
})

test_that("remove_monotonous is a no-op for single-row tibbles", {
  df <- tibble::tibble(a = 1, b = 2)
  result <- pixieweb:::remove_monotonous(df)
  expect_equal(ncol(result), 2)
})

test_that("entity_search filters by character columns", {
  df <- tibble::tibble(
    id = c("T1", "T2", "T3"),
    title = c("Population by age", "Income by region", "Population by sex")
  )
  result <- pixieweb:::entity_search(df, "population")
  expect_equal(nrow(result), 2)
  expect_equal(result$id, c("T1", "T3"))
})

test_that("entity_search supports multiple search terms (OR)", {
  df <- tibble::tibble(
    id = c("T1", "T2", "T3"),
    title = c("Population", "Income", "Exports")
  )
  result <- pixieweb:::entity_search(df, c("population", "exports"))
  expect_equal(nrow(result), 2)
})

test_that("entity_search respects column parameter", {
  df <- tibble::tibble(
    id = c("POP1", "INC1"),
    title = c("Something", "Population data")
  )
  result <- pixieweb:::entity_search(df, "pop", column = "id")
  expect_equal(nrow(result), 1)
  expect_equal(result$id, "POP1")
})

test_that("entity_search searches list columns", {
  df <- tibble::tibble(
    id = c("T1", "T2"),
    title = c("Table one", "Table two"),
    variables = list(c("Region", "Tid"), c("Alder", "Kon"))
  )
  result <- pixieweb:::entity_search(df, "region")
  expect_equal(nrow(result), 1)
  expect_equal(result$id, "T1")
})

test_that("entity_search warns on empty input", {
  df <- tibble::tibble(id = character(), title = character())
  expect_warning(pixieweb:::entity_search(df, "test"), "empty")
})

# --- Query-string construction (0.1.1.9006) --------------------------------

test_that("px_query_value percent-encodes spaces and non-ASCII", {
  expect_equal(pixieweb:::px_query_value("two words"), "two%20words")
  expect_equal(pixieweb:::px_query_value("arbetsl\u00f6shet"),
               "arbetsl%C3%B6shet")
  expect_equal(pixieweb:::px_query_value("a&b"), "a%26b")
  expect_equal(pixieweb:::px_query_value(1000L), "1000")
})

test_that("px_query_string encodes every value and drops NULLs", {
  qs <- pixieweb:::px_query_string(
    list(query = "nyregistrerade personbilar", pageSize = 1000L, x = NULL)
  )
  expect_equal(qs, "query=nyregistrerade%20personbilar&pageSize=1000")
})

test_that("px_query_string returns empty string for nothing to add", {
  expect_equal(pixieweb:::px_query_string(list()), "")
  expect_equal(pixieweb:::px_query_string(list(a = NULL)), "")
})

test_that("px_url_query encodes values, unlike plain pasting", {
  url <- pixieweb:::px_url_query("https://example.com/api",
                                 query = "two words")
  expect_equal(url, "https://example.com/api?query=two%20words")
  expect_no_match(url, " ", fixed = TRUE)
})

test_that("px_url_query picks & when the URL already has a query string", {
  url <- pixieweb:::px_url_query("https://example.com/api?lang=sv",
                                 query = "befolkning")
  expect_equal(url, "https://example.com/api?lang=sv&query=befolkning")
})

test_that("px_url_append takes a list and behaves like px_url_query", {
  expect_equal(
    pixieweb:::px_url_append("https://example.com?lang=sv",
                             list(query = "a b", pageSize = 10L)),
    "https://example.com?lang=sv&query=a%20b&pageSize=10"
  )
})

# --- check_count_arg (0.1.1.9006) -----------------------------------------

test_that("check_count_arg accepts positive whole numbers and NULL", {
  expect_silent(pixieweb:::check_count_arg(1L, "n"))
  expect_silent(pixieweb:::check_count_arg(1000, "n"))
  expect_silent(pixieweb:::check_count_arg(NULL, "n"))
})

test_that("check_count_arg rejects Inf unless allow_inf", {
  expect_error(pixieweb:::check_count_arg(Inf, "per_page"), "per_page")
  expect_silent(pixieweb:::check_count_arg(Inf, "max_results", allow_inf = TRUE))
})

test_that("check_count_arg rejects NA, zero, negatives and non-numerics", {
  expect_error(pixieweb:::check_count_arg(NA, "n", allow_inf = TRUE), "NA")
  expect_error(pixieweb:::check_count_arg(0, "n"), "positive whole number")
  expect_error(pixieweb:::check_count_arg(-3, "n"), "positive whole number")
  expect_error(pixieweb:::check_count_arg(2.5, "n"), "positive whole number")
  expect_error(pixieweb:::check_count_arg("10", "n"), "positive whole number")
  expect_error(pixieweb:::check_count_arg(c(1, 2), "n"), "positive whole number")
})

test_that("check_count_arg accepts NA only when allow_na", {
  expect_silent(pixieweb:::check_count_arg(NA, "page", allow_na = TRUE))
  expect_error(pixieweb:::check_count_arg(NA, "page"), "page")
})

test_that("check_count_arg surfaces the extra hint", {
  expect_error(
    pixieweb:::check_count_arg(Inf, "per_page", extra_hint = "Use get_tables()."),
    "get_tables"
  )
})
