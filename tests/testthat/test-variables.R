# Unit tests for variable helper functions

test_that("variable_search filters by code and text", {
  df <- tibble::tibble(
    code = c("Region", "Tid", "Kon"),
    text = c("region", "year", "sex"),
    n_values = c(290, 50, 3),
    elimination = c(TRUE, FALSE, TRUE),
    time = c(FALSE, TRUE, FALSE),
    values = list(
      tibble::tibble(code = "0180", text = "Stockholm"),
      tibble::tibble(code = "2024", text = "2024"),
      tibble::tibble(code = "1", text = "Male")
    ),
    codelists = list(NULL, NULL, NULL),
    table_id = "TAB1"
  )

  expect_equal(nrow(variable_search(df, "region")), 1)
  expect_equal(nrow(variable_search(df, "year")), 1)
  expect_equal(nrow(variable_search(df, "tid")), 1)
})

test_that("variable_describe returns input invisibly", {
  df <- tibble::tibble(
    code = "Tid", text = "Year", n_values = 5L,
    elimination = FALSE, time = TRUE,
    values = list(tibble::tibble(code = c("2020", "2021"), text = c("2020", "2021"))),
    codelists = list(NULL),
    table_id = "TAB1"
  )

  result <- expect_output(variable_describe(df))
  expect_identical(result, df)
})

test_that("variable_describe warns on empty input", {
  expect_warning(variable_describe(NULL), "No variables")
})

test_that("variable_extract_ids returns code vector", {
  df <- tibble::tibble(code = c("Region", "Tid"), text = c("a", "b"))
  expect_equal(variable_extract_ids(df), c("Region", "Tid"))
})

test_that("variable_minimize removes nested columns", {
  df <- tibble::tibble(
    code = "A", text = "B", n_values = 1L,
    values = list(tibble::tibble(code = "x", text = "y")),
    codelists = list(NULL)
  )
  result <- variable_minimize(df)
  expect_false("values" %in% names(result))
  expect_false("codelists" %in% names(result))
  expect_true("code" %in% names(result))
})

test_that("variable_name_to_code converts names", {
  df <- tibble::tibble(
    code = c("Region", "Tid"),
    text = c("region", "year")
  )
  result <- variable_name_to_code(df, "region")
  expect_equal(unname(result), "Region")
})

test_that("variable_values extracts correct values tibble", {
  vals <- tibble::tibble(code = c("1", "2"), text = c("Male", "Female"))
  df <- tibble::tibble(
    code = c("Kon", "Tid"),
    text = c("sex", "year"),
    values = list(vals, tibble::tibble(code = "2024", text = "2024"))
  )
  result <- variable_values(df, "Kon")
  expect_equal(nrow(result), 2)
  expect_equal(result$code, c("1", "2"))
})

test_that("variable_values warns on missing variable", {
  df <- tibble::tibble(code = "Tid", text = "year",
                       values = list(tibble::tibble(code = "x", text = "y")))
  expect_warning(variable_values(df, "Nope"), "not found")
})
