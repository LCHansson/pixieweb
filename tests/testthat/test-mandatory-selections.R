# Unit tests for the mandatory-variable pre-flight check (0.1.1.9006)
#
# PX-Web v2 rejects a data query that omits any variable whose metadata has
# `elimination = FALSE`, and its HTTP 400 body does not name the variable.
# check_mandatory_selections() catches that client-side. No network here:
# the variable metadata is supplied directly.

fake_api <- function(version = "v2") {
  structure(
    list(base_url = "https://api.scb.se/ov0104/v2beta/api/v2",
         alias = "scb", lang = "sv", version = version, config = NULL),
    class = "px_api"
  )
}

# Shaped like get_variables() output for SCB TAB5166.
tab5166_vars <- function() {
  tibble::tibble(
    code = c("SNI2007", "Storleksklass", "ContentsCode", "Tid"),
    text = c("naringsgren SNI 2007", "storleksklass",
             "tabellinnehall", "ar"),
    n_values = c(1823L, 9L, 1L, 18L),
    elimination = c(FALSE, TRUE, FALSE, FALSE),
    time = c(FALSE, FALSE, FALSE, TRUE),
    values = list(NULL, NULL, NULL, NULL),
    codelists = list(NULL, NULL, NULL, NULL),
    table_id = "TAB5166"
  )
}

test_that("all mandatory variables selected passes silently", {
  expect_silent(
    pixieweb:::check_mandatory_selections(
      list(SNI2007 = "01", ContentsCode = "*", Tid = px_top(1)),
      tab5166_vars(), "TAB5166", fake_api()
    )
  )
})

test_that("an eliminable variable may still be omitted", {
  # Storleksklass has elimination = TRUE, so leaving it out is legal.
  expect_silent(
    pixieweb:::check_mandatory_selections(
      list(SNI2007 = "01", ContentsCode = "*", Tid = px_top(1)),
      tab5166_vars(), "TAB5166", fake_api()
    )
  )
})

test_that("omitting mandatory variables errors and names each of them", {
  err <- expect_error(
    pixieweb:::check_mandatory_selections(
      list(Tid = px_top(1)), tab5166_vars(), "TAB5166", fake_api()
    ),
    "Missing selection for mandatory variable"
  )
  msg <- conditionMessage(err)
  expect_match(msg, "SNI2007", fixed = TRUE)
  expect_match(msg, "ContentsCode", fixed = TRUE)
  expect_match(msg, "TAB5166", fixed = TRUE)
})

test_that("the error names the remedy, not just the problem", {
  err <- expect_error(
    pixieweb:::check_mandatory_selections(
      list(), tab5166_vars(), "TAB5166", fake_api()
    )
  )
  msg <- conditionMessage(err)
  # A copy-pasteable selection for each missing variable ...
  expect_match(msg, 'SNI2007 = "*"', fixed = TRUE)
  expect_match(msg, "Tid = px_top(5)", fixed = TRUE)
  # ... which variable may be left out ...
  expect_match(msg, "Storleksklass", fixed = TRUE)
  expect_match(msg, "elimination = TRUE", fixed = TRUE)
  # ... and where to look it up.
  expect_match(msg, "get_variables", fixed = TRUE)
  expect_match(msg, "prepare_query", fixed = TRUE)
})

test_that("an explicit NULL selection counts as omitted", {
  expect_error(
    pixieweb:::check_mandatory_selections(
      list(SNI2007 = NULL, ContentsCode = "*", Tid = px_top(1)),
      tab5166_vars(), "TAB5166", fake_api()
    ),
    "SNI2007"
  )
})

test_that("v1 APIs are exempt", {
  # PX-Web v1 expands omitted non-eliminable variables instead of rejecting
  # the request (verified against konj Indikatorm.px), so the check must not
  # fire there.
  expect_silent(
    pixieweb:::check_mandatory_selections(
      list(Tid = px_top(1)), tab5166_vars(), "TAB5166", fake_api("v1")
    )
  )
})

test_that("missing or unusable metadata does not block the request", {
  expect_silent(
    pixieweb:::check_mandatory_selections(
      list(), NULL, "TAB5166", fake_api()
    )
  )
  expect_silent(
    pixieweb:::check_mandatory_selections(
      list(), tab5166_vars()[0, ], "TAB5166", fake_api()
    )
  )
  no_flag <- tab5166_vars()
  no_flag$elimination <- NULL
  expect_silent(
    pixieweb:::check_mandatory_selections(list(), no_flag, "TAB5166", fake_api())
  )
})

test_that("a table with only eliminable variables never errors", {
  vars <- tibble::tibble(
    code = c("Region", "Kon"),
    text = c("region", "kon"),
    n_values = c(312L, 2L),
    elimination = c(TRUE, TRUE),
    time = c(FALSE, FALSE),
    values = list(NULL, NULL),
    codelists = list(NULL, NULL),
    table_id = "TABX"
  )
  expect_silent(
    pixieweb:::check_mandatory_selections(list(), vars, "TABX", fake_api())
  )
})
