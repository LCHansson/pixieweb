# Opt-in status symbols: get_data(.status = TRUE) keeps the source's own
# symbol ("..", ".") for a cell without a value, so a caller can tell
# "the source withholds this" from "no value".

js2 <- function(status) {
  list(
    id = list("Region", "Tid"),
    dimension = list(
      Region = list(label = "region", category = list(
        index = list(`01` = 0, `02` = 1),
        label = list(`01` = "A", `02` = "B"))),
      Tid = list(label = "year", category = list(
        index = list(`2023` = 0, `2024` = 1),
        label = list(`2023` = "2023", `2024` = "2024")))
    ),
    value = list(1, NULL, NULL, 4),
    status = status
  )
}

test_that("v2: default output has no status column", {
  d <- parse_data_v2(js2(list(`1` = "..", `2` = ".")), "T", TRUE)
  expect_false("status" %in% names(d))
  expect_equal(d$value, c(1, NA, NA, 4))
})

test_that("v2: sparse status object is placed by zero-based cell position", {
  d <- parse_data_v2(js2(list(`1` = "..", `2` = ".")), "T", TRUE, status = TRUE)
  expect_equal(names(d)[ncol(d) - 1:0], c("value", "status"))
  expect_equal(d$status, c(NA, "..", ".", NA))
  expect_equal(d$value, c(1, NA, NA, 4))
})

test_that("v2: array, single-string and absent status forms", {
  d <- parse_data_v2(js2(list(NULL, "..", "..", NULL)), "T", FALSE, status = TRUE)
  expect_equal(d$status, c(NA, "..", "..", NA))
  expect_equal(status_symbols_v2(list("e"), 3), rep("e", 3))
  expect_equal(status_symbols_v2(NULL, 2), c(NA_character_, NA_character_))
  # A position outside the cube is ignored rather than recycled
  expect_equal(status_symbols_v2(list(`9` = ".."), 2), c(NA_character_, NA_character_))
})

v1_raw <- function() {
  list(
    columns = list(
      list(code = "Period", text = "Period", type = "t"),
      list(code = "a", text = "Series A", type = "c"),
      list(code = "b", text = "Series B", type = "c")
    ),
    data = list(
      list(key = list("2023"), values = list("..", "1.5")),
      list(key = list("2024"), values = list("2.5", "."))
    )
  )
}

test_that("v1: symbols of several content columns follow their cells", {
  d <- suppressWarnings(parse_data_v1(v1_raw(), "T", TRUE, status = TRUE))
  expect_equal(d$ContentsCode, c("a", "b", "a", "b"))
  expect_equal(d$value, c(NA, 1.5, 2.5, NA))
  expect_equal(d$status, c("..", NA, NA, "."))
  plain <- suppressWarnings(parse_data_v1(v1_raw(), "T", TRUE))
  expect_false("status" %in% names(plain))
  expect_equal(plain$value, d$value)
})

test_that("v1: single content column", {
  raw <- v1_raw()
  raw$columns <- raw$columns[1:2]
  raw$data <- lapply(raw$data, function(r) { r$values <- r$values[1]; r })
  d <- suppressWarnings(parse_data_v1(raw, "T", FALSE, status = TRUE))
  expect_equal(d$status, c("..", NA))
})

test_that(".status needs long output and a logical flag", {
  api <- structure(list(base_url = "https://x", version = "v2", lang = "en"),
                   class = "px_api")
  expect_error(get_data(api, "T", .output = "wide", .status = TRUE), "long")
  expect_error(get_data(api, "T", .status = NA))
})

test_that("live v1: withheld cells carry the source's symbol", {
  skip_on_cran()
  konj <- px_api("konj")
  skip_if_not(px_available(konj), "Konj API not reachable")
  id <- "KonjBar/indikatorer/Indikatorm.px"
  vars <- get_variables(konj, id)
  skip_if(is.null(vars), "No metadata returned")
  first <- as.character(unlist(vars$values[[which(vars$time)]]$code))[1]
  sel <- stats::setNames(list("*", first), c(vars$code[!vars$time][1], vars$code[vars$time]))
  d <- suppressWarnings(do.call(get_data, c(list(konj, id), sel, list(.status = TRUE))))
  skip_if(is.null(d), "No data returned")
  expect_true("status" %in% names(d))
  expect_true(all(is.na(d$status) | is.na(d$value)))
  # The first period predates most indicators: the source marks them
  expect_true(any(!is.na(d$status)))
  expect_true(all(is.na(d$status[!is.na(d$value)])))
})
