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
  expect_equal(names(out), c("table_id", "Year", "Year_text", "Measure",
                               "Measure_text", "ContentsCode",
                               "ContentsCode_text", "value"))
  # An eliminated (unselected) variable is not mistaken for the folded one
  out2 <- label_v1_result(res, vars_fixture(), c("Measure", "Year"))
  expect_equal(attr(out2, "px_contents_variable"), "Measure")
  out3 <- label_v1_result(res, vars_fixture(), "Year")
  expect_null(attr(out3, "px_contents_variable"))
  expect_equal(names(out3), names(res))
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

# AE order 20261020081923-803r0p: a catalogue fetch of EN_IND5-4E_CONT.px
# selected `Drivmedelskategori`, the response folded it into ContentsCode,
# and the adapter, reading the column by the metadata's name, wrote no
# dimension column (DuckDB: Referenced column "dim_drivmedelskategori" not
# found).
test_that("the folded contents variable also comes under its own name", {
  res <- tibble::tibble(table_id = "T", Year = "2024", Year_text = "2024",
                        ContentsCode = c("0", "1"),
                        ContentsCode_text = c("Petrol", "Diesel"),
                        value = c(1, 2))
  vars <- vars_fixture()[c(1, 3), ]
  vars$elimination <- c(FALSE, FALSE)
  # Nothing selected: the variable cannot be eliminated, so it was fetched
  out <- label_v1_result(res, vars, character())
  expect_equal(attr(out, "px_contents_variable"), "Fuel")
  expect_equal(out$Fuel, out$ContentsCode)
  expect_equal(out$Fuel_text, c("Petrol", "Diesel"))
  expect_equal(out$ContentsCode, res$ContentsCode)
  # No _text columns asked for: only the code column is added
  bare <- res[, c("table_id", "Year", "ContentsCode", "value")]
  out2 <- label_v1_result(bare, vars, "Fuel", simplify = FALSE)
  expect_equal(names(out2), c("table_id", "Year", "Fuel", "ContentsCode", "value"))
  # Wide output pivots on ContentsCode and does not keep the alias as an id
  wide <- pivot_data_wide(out)
  expect_equal(nrow(wide), 1L)
  expect_false(any(c("Fuel", "Fuel_text") %in% names(wide)))
})

test_that("live v1: EN_IND5-4E_CONT.px has a column per variable (energi)", {
  skip_on_cran()
  en <- px_api("energi")
  skip_if_not(px_available(en), "Energimyndigheten API not reachable")
  tid <- paste0("Energimyndighetens_statistikdatabas/Energiindikatorer/",
                "5/5.4/EN_IND5-4E_CONT.px")
  vars <- get_variables(en, tid)
  skip_if(is.null(vars), "No metadata returned")
  Sys.sleep(1)
  sel <- stats::setNames(list("*", px_top(2)), c("Drivmedelskategori", "År"))
  d <- suppressWarnings(do.call(get_data, c(list(en, tid), sel)))
  skip_if(is.null(d), "No data returned")
  expect_true(all(vars$code %in% names(d)))
  expect_equal(attr(d, "px_contents_variable"), "Drivmedelskategori")
  expect_false(all(d$Drivmedelskategori_text == d$Drivmedelskategori))
})
