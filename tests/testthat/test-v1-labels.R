# v1 results: labels from metadata, plain character value tables, and the
# name of a contents variable the response folded into ContentsCode.

test_that("px_chr keeps one element per entry", {
  expect_equal(px_chr(list("a", NULL, "c")), c("a", NA, "c"))
  expect_equal(px_chr(NULL), character())
  expect_equal(px_chr(c("x", "y")), c("x", "y"))
  expect_equal(px_chr(list(1L, 2L)), c("1", "2"))
})

# dev-backlog 2026-09-12: `values` had list-columns for v1, so
# setNames(vals$text, vals$code) gave an unusable lookup.
test_that("get_variables() v1 returns character code/text columns", {
  raw <- list(variables = list(
    list(code = "Fuel", text = "Fuel", values = list("0", "1"),
         valueTexts = list("Petrol", "Diesel")),
    list(code = "Year", text = "Year", values = list("2023", "2024"),
         valueTexts = list("2023", "2024"), time = TRUE)
  ))
  testthat::local_mocked_bindings(px_get = function(...) raw)
  api <- structure(list(base_url = "https://x/api/v1", alias = "t", lang = "sv",
                        version = "v1", config = NULL), class = "px_api")
  v <- get_variables(api, "A/B.px")
  vals <- v$values[[1]]
  expect_type(vals$code, "character")
  expect_type(vals$text, "character")
  expect_equal(stats::setNames(vals$text, vals$code), c(`0` = "Petrol", `1` = "Diesel"))
  expect_equal(v$n_values, c(2L, 2L))
  expect_equal(v$time, c(FALSE, TRUE))
})

vars_fixture <- function() {
  tibble::tibble(
    code = c("Fuel", "Measure", "Year"),
    values = list(
      tibble::tibble(code = c("0", "1"), text = c("Petrol", "Diesel")),
      # the list-column shape older caches may still hold
      tibble::tibble(code = list("0", "1"), text = list("Price", "Tax")),
      tibble::tibble(code = c("2023", "2024"), text = c("2023", "2024"))
    )
  )
}

# dev-backlog 2026-09-15: <var>_text repeated the code for v1 tables.
test_that("label_v1_result fills _text from metadata where it repeats the code", {
  res <- tibble::tibble(
    table_id = "T", Fuel = c("0", "1"), Fuel_text = c("0", "1"),
    Measure = c("1", "9"), Measure_text = c("1", "9"),
    Year = "2024", Year_text = "2024", value = c(1, 2)
  )
  out <- label_v1_result(res, vars_fixture(), c("Fuel", "Measure", "Year"))
  expect_equal(out$Fuel_text, c("Petrol", "Diesel"))
  # An unknown code keeps what the response gave
  expect_equal(out$Measure_text, c("Tax", "9"))
  expect_equal(out$value, c(1, 2))
  expect_null(attr(out, "px_contents_variable"))
})

test_that("label_v1_result leaves real labels and code-only results alone", {
  res <- tibble::tibble(table_id = "T", Fuel = "0", Fuel_text = "Already a label",
                        value = 1)
  expect_equal(label_v1_result(res, vars_fixture(), "Fuel")$Fuel_text,
               "Already a label")
  bare <- tibble::tibble(table_id = "T", Fuel = "0", value = 1)
  expect_identical(label_v1_result(bare, vars_fixture(), "Fuel", simplify = FALSE), bare)
  expect_identical(label_v1_result(bare, NULL, "Fuel"), bare)
})

# dev-backlog 2026-09-15: the contents variable goes in under its own name
# and comes out as `ContentsCode`.
test_that("the folded contents variable is named in an attribute", {
  res <- tibble::tibble(table_id = "T", Year = "2024", Year_text = "2024",
                        ContentsCode = c("0", "1"),
                        ContentsCode_text = c("Price", "Tax"), value = c(1, 2))
  out <- label_v1_result(res, vars_fixture()[2:3, ], c("Measure", "Year"))
  expect_equal(attr(out, "px_contents_variable"), "Measure")
  expect_equal(names(out), names(res))
  # An eliminated (unselected) variable is not mistaken for the folded one
  out2 <- label_v1_result(res, vars_fixture(), c("Measure", "Year"))
  expect_equal(attr(out2, "px_contents_variable"), "Measure")
  out3 <- label_v1_result(res, vars_fixture(), "Year")
  expect_null(attr(out3, "px_contents_variable"))
})

test_that("live v1: labels and the folded variable name (energi)", {
  skip_on_cran()
  en <- px_api("energi")
  skip_if_not(px_available(en), "Energimyndigheten API not reachable")
  pre <- "Energimyndighetens_statistikdatabas/Energiindikatorer/12/12.7/"
  vars <- get_variables(en, paste0(pre, "EN_IND12-7B.px"))
  skip_if(is.null(vars), "No metadata returned")
  sel <- stats::setNames(
    lapply(seq_len(nrow(vars)), function(i) if (isTRUE(vars$time[i])) px_top(1) else "*"),
    vars$code)
  Sys.sleep(1)
  d <- do.call(get_data, c(list(en, paste0(pre, "EN_IND12-7B.px")), sel))
  skip_if(is.null(d), "No data returned")
  dim_var <- vars$code[!vars$time][1]
  expect_false(all(d[[paste0(dim_var, "_text")]] == d[[dim_var]]))

  Sys.sleep(1)
  cont <- paste0(pre, "EN_IND12-7A_Cont.px")
  cv <- get_variables(en, cont)
  skip_if(is.null(cv), "No metadata returned")
  csel <- stats::setNames(
    lapply(seq_len(nrow(cv)), function(i) if (isTRUE(cv$time[i])) px_top(1) else "*"),
    cv$code)
  Sys.sleep(1)
  dc <- do.call(get_data, c(list(en, cont), csel))
  skip_if(is.null(dc), "No data returned")
  expect_true("ContentsCode" %in% names(dc))
  expect_equal(attr(dc, "px_contents_variable"), cv$code[!cv$time][1])
})
