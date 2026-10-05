# dev-backlog 2026-09-12: get_codelists() dropped `valueMap`, the mapping
# from an aggregate to the values it is made of.

codelist_api <- function() {
  structure(list(base_url = "https://x/api/v2", alias = "t", lang = "sv",
                 version = "v2", config = NULL), class = "px_api")
}

codelist_vars <- function() {
  tibble::tibble(
    code = "Region",
    values = list(tibble::tibble(code = c("0114", "0115"), text = c("A", "B"))),
    codelists = list(tibble::tibble(id = "agg_Lan", text = "Counties",
                                    type = "Aggregation"))
  )
}

test_that("get_codelists() keeps the value map and the elimination fields", {
  raw <- list(
    id = "agg_Lan", label = "Counties", type = "Aggregation",
    elimination = TRUE, eliminationValueCode = "00",
    values = list(
      list(code = "01", label = "Stockholm county", valueMap = list("0114", "0115")),
      list(code = "03", label = "Uppsala county", valueMap = list("0305"))
    )
  )
  testthat::local_mocked_bindings(
    get_variables = function(...) codelist_vars(),
    px_get = function(...) raw
  )
  cl <- get_codelists(codelist_api(), "TAB1", "Region")
  expect_equal(names(cl)[1:4], c("id", "text", "type", "values"))
  expect_true(cl$elimination)
  expect_equal(cl$elimination_value_code, "00")
  vals <- cl$values[[1]]
  expect_equal(names(vals), c("code", "text", "value_map"))
  expect_equal(vals$value_map, list(c("0114", "0115"), "0305"))
  # The older accessors still work on the wider tibble
  expect_equal(codelist_values(cl, "agg_Lan")$code, c("01", "03"))
  expect_equal(codelist_extract_ids(cl), "agg_Lan")
})

test_that("a codelist without a value map or elimination gives empty and NA", {
  raw <- list(id = "vs_X", eliminationValueCode = "",
              values = list(list(code = "a", label = "A")))
  testthat::local_mocked_bindings(
    get_variables = function(...) codelist_vars(),
    px_get = function(...) raw
  )
  cl <- get_codelists(codelist_api(), "TAB1", "Region")
  expect_true(is.na(cl$elimination))
  expect_true(is.na(cl$elimination_value_code))
  expect_equal(cl$values[[1]]$value_map, list(character()))

  testthat::local_mocked_bindings(px_get = function(...) NULL)
  none <- get_codelists(codelist_api(), "TAB1", "Region")
  expect_equal(names(none$values[[1]]), c("code", "text", "value_map"))
  expect_equal(nrow(none$values[[1]]), 0)
})
