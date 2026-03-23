test_that("pixieweb_cache_dir() returns a valid path", {
  dir <- pixieweb_cache_dir()
  expect_type(dir, "character")
  expect_true(dir.exists(dir))
})

test_that("different key_params produce different filenames", {
  f1 <- cache_filename("tables", list(alias = "scb", query = "population"))
  f2 <- cache_filename("tables", list(alias = "scb", query = "income"))
  expect_false(f1 == f2)
})

test_that("same key_params produce the same filename", {
  params <- list(alias = "scb", lang = "en", query = "population")
  f1 <- cache_filename("tables", params)
  f2 <- cache_filename("tables", params)
  expect_equal(f1, f2)
})

test_that("key_params order does not affect filename", {
  f1 <- cache_filename("tables", list(alias = "scb", lang = "en"))
  f2 <- cache_filename("tables", list(lang = "en", alias = "scb"))
  expect_equal(f1, f2)
})

test_that("discover/load/store round-trip works with saveRDS/readRDS", {
  tmp <- withr::local_tempdir()
  df <- tibble::tibble(id = "TAB1", title = "Test")

  ch <- cache_handler("tables", TRUE, tmp, key_params = list(alias = "test"))

  expect_false(ch("discover"))
  result <- ch("store", df)
  expect_equal(result, df)

  expect_true(ch("discover"))
  loaded <- ch("load")
  expect_equal(loaded, df)
})

test_that("no-op handler when cache = FALSE", {
  ch <- cache_handler("tables", FALSE, tempdir(), key_params = list(alias = "x"))

  expect_false(ch("discover"))
  expect_false(ch("load"))

  df <- tibble::tibble(id = "TAB1", title = "Test")
  result <- ch("store", df)
  expect_equal(result, df)
})

test_that("pixieweb_clear_cache() selective clearing by entity", {
  tmp <- withr::local_tempdir()

  # Create two cache files with different entities
  ch_tables <- cache_handler("tables", TRUE, tmp,
    key_params = list(alias = "scb", query = "pop"))
  ch_enriched <- cache_handler("enriched", TRUE, tmp,
    key_params = list(alias = "scb", ids = "TAB1"))

  ch_tables("store", tibble::tibble(x = 1))
  ch_enriched("store", tibble::tibble(x = 2))

  expect_length(list.files(tmp, pattern = "\\.rds$"), 2)

  # Clear only tables
  pixieweb_clear_cache(entity = "tables", cache_location = tmp)
  remaining <- list.files(tmp, pattern = "\\.rds$")
  expect_length(remaining, 1)
  expect_true(grepl("enriched", remaining))
})

test_that("pixieweb_clear_cache() selective clearing by API alias", {
  tmp <- withr::local_tempdir()

  ch_scb <- cache_handler("tables", TRUE, tmp,
    key_params = list(alias = "scb", query = "pop"))
  ch_ssb <- cache_handler("tables", TRUE, tmp,
    key_params = list(alias = "ssb", query = "pop"))

  ch_scb("store", tibble::tibble(x = 1))
  ch_ssb("store", tibble::tibble(x = 2))

  expect_length(list.files(tmp, pattern = "\\.rds$"), 2)

  # Clear only scb — pass a mock api object with $alias
  mock_api <- list(alias = "scb")
  pixieweb_clear_cache(api = mock_api, cache_location = tmp)
  remaining <- list.files(tmp, pattern = "\\.rds$")
  expect_length(remaining, 1)
  expect_true(grepl("ssb", remaining))
})

test_that("pixieweb_clear_cache() clears all when no filters", {
  tmp <- withr::local_tempdir()

  ch1 <- cache_handler("tables", TRUE, tmp,
    key_params = list(alias = "scb"))
  ch2 <- cache_handler("enriched", TRUE, tmp,
    key_params = list(alias = "ssb"))

  ch1("store", tibble::tibble(x = 1))
  ch2("store", tibble::tibble(x = 2))

  pixieweb_clear_cache(cache_location = tmp)
  expect_length(list.files(tmp, pattern = "\\.rds$"), 0)
})
