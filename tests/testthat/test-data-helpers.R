# Unit tests for data helper functions

test_that("data_minimize removes constant columns", {
  df <- tibble::tibble(
    table_id = c("T1", "T1"),
    Region = c("0180", "1480"),
    value = c(100, 200)
  )
  result <- data_minimize(df)
  expect_false("table_id" %in% names(result))
  expect_true("Region" %in% names(result))
  expect_true("value" %in% names(result))
})

test_that("data_comments extracts comment attribute", {
  df <- tibble::tibble(value = 1)
  comments <- tibble::tibble(
    variable = "Tid", value = "2024", comment = "Preliminary"
  )
  attr(df, "comments") <- comments

  result <- data_comments(df)
  expect_equal(nrow(result), 1)
  expect_equal(result$comment, "Preliminary")
})

test_that("data_comments returns NULL when no comments", {
  df <- tibble::tibble(value = 1)
  expect_null(data_comments(df))
})

test_that("data_legend produces caption string", {
  df <- tibble::tibble(value = 1)
  attr(df, "px_source") <- list(
    api = "SCB",
    table_id = "TAB638",
    fetched = as.POSIXct("2024-01-01")
  )
  var_df <- tibble::tibble(
    code = c("Region", "Tid"),
    text = c("region", "year")
  )

  result <- data_legend(df, var_df)
  expect_type(result, "character")
  expect_match(result, "region")
  expect_match(result, "SCB")
})

test_that("data_legend returns empty string for empty var_df", {
  expect_equal(data_legend(tibble::tibble(), NULL), "")
})

test_that("px_cite generates citation from metadata", {
  df <- tibble::tibble(value = 1)
  attr(df, "px_source") <- list(
    api = "Statistics Sweden (SCB)",
    table_id = "TAB638",
    fetched = as.POSIXct("2024-06-15")
  )

  result <- px_cite(df)
  expect_match(result, "Statistics Sweden")
  expect_match(result, "TAB638")
  expect_match(result, "2024-06-15")
  expect_match(result, "pixieweb")
})

test_that("px_cite warns when no source metadata", {
  df <- tibble::tibble(value = 1)
  expect_warning(px_cite(df), "source metadata")
})

test_that("pivot_data_wide pivots ContentsCode", {
  df <- tibble::tibble(
    table_id = c("T1", "T1", "T1", "T1"),
    Region = c("0180", "0180", "1480", "1480"),
    ContentsCode = c("Pop", "Deaths", "Pop", "Deaths"),
    ContentsCode_text = c("Population", "Deaths", "Population", "Deaths"),
    value = c(100, 5, 200, 10)
  )

  result <- pixieweb:::pivot_data_wide(df)
  expect_true("Pop" %in% names(result) || "Deaths" %in% names(result))
  expect_equal(nrow(result), 2)
})
