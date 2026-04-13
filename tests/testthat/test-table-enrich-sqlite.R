# Tests for the per-table SQLite caching path in table_enrich().
# Uses a mocked fetch_table_metadata to avoid any API calls.

skip_if_not_installed("nordstatExtras")

make_fake_tables <- function() {
  df <- tibble::tibble(
    id = c("TAB1", "TAB2", "TAB3"),
    title = c("Table 1", "Table 2", "Table 3"),
    description = c("desc 1", "desc 2", "desc 3")
  )
  attr(df, "px_api") <- structure(
    list(alias = "fake", lang = "sv", version = "v2",
         config = list(max_calls = 30, time_window = 1)),
    class = "px_api"
  )
  df
}

mock_fetch_raw <- function(api, table_id, verbose = FALSE) {
  list(
    note = c(paste0("Note for ", table_id)),
    extension = list(
      px = list(
        contents = paste0("contents-", table_id),
        `subject-area` = "Befolkning",
        `official-statistics` = TRUE
      ),
      contact = list(list(name = "Jane Doe", organization = "SCB"))
    )
  )
}

test_that("SQLite-backed table_enrich caches per-table and resumes on second call", {
  path <- tempfile(fileext = ".sqlite")
  handle <- nordstatExtras::nxt_open(path)
  on.exit({
    nordstatExtras::nxt_close(handle)
    unlink(c(path, paste0(path, c("-wal","-shm"))), force = TRUE)
  })

  tables <- make_fake_tables()

  fetch_calls <- 0L
  local_mocked_bindings(
    fetch_table_metadata = function(api, table_id, verbose = FALSE) {
      fetch_calls <<- fetch_calls + 1L
      mock_fetch_raw(api, table_id, verbose)
    }
  )

  # First enrich — all 3 tables fetched
  r1 <- table_enrich(tables, cache = TRUE, cache_location = handle)
  expect_equal(fetch_calls, 3L)
  expect_equal(nrow(r1), 3L)
  expect_true(all(!is.na(r1$contents)))
  expect_true(all(grepl("contents-", r1$contents)))

  # Second enrich with the same tables — zero network calls, full cache hit
  fetch_calls <- 0L
  r2 <- table_enrich(tables, cache = TRUE, cache_location = handle)
  expect_equal(fetch_calls, 0L)
  expect_equal(r2$contents, r1$contents)
})

test_that("SQLite-backed table_enrich preserves px_api attribute", {
  path <- tempfile(fileext = ".sqlite")
  handle <- nordstatExtras::nxt_open(path)
  on.exit({
    nordstatExtras::nxt_close(handle)
    unlink(c(path, paste0(path, c("-wal","-shm"))), force = TRUE)
  })

  tables <- make_fake_tables()
  fake_api <- attr(tables, "px_api")

  local_mocked_bindings(
    fetch_table_metadata = function(api, table_id, verbose = FALSE) {
      mock_fetch_raw(api, table_id, verbose)
    }
  )

  enriched <- table_enrich(tables, cache = TRUE, cache_location = handle)
  expect_identical(attr(enriched, "px_api"), fake_api)
  expect_s3_class(attr(enriched, "px_api"), "px_api")
})

test_that("SQLite-backed table_enrich reuses cells across different queries", {
  # Overlapping get_tables results should share enriched rows in cache —
  # that's the whole point of per-table granularity.
  path <- tempfile(fileext = ".sqlite")
  handle <- nordstatExtras::nxt_open(path)
  on.exit({
    nordstatExtras::nxt_close(handle)
    unlink(c(path, paste0(path, c("-wal","-shm"))), force = TRUE)
  })

  tables_a <- make_fake_tables()                 # TAB1, TAB2, TAB3
  tables_b <- tables_a[c(2, 3), ]                # TAB2, TAB3
  attr(tables_b, "px_api") <- attr(tables_a, "px_api")

  fetch_calls <- 0L
  local_mocked_bindings(
    fetch_table_metadata = function(api, table_id, verbose = FALSE) {
      fetch_calls <<- fetch_calls + 1L
      mock_fetch_raw(api, table_id, verbose)
    }
  )

  # First enrich: 3 calls
  table_enrich(tables_a, cache = TRUE, cache_location = handle)
  expect_equal(fetch_calls, 3L)

  # Second enrich with overlapping subset: 0 calls (TAB2 and TAB3 cached)
  fetch_calls <- 0L
  r <- table_enrich(tables_b, cache = TRUE, cache_location = handle)
  expect_equal(fetch_calls, 0L)
  expect_equal(nrow(r), 2L)
  expect_equal(r$id, c("TAB2", "TAB3"))
})

test_that("SQLite-backed table_enrich resumes a partial run after interruption", {
  path <- tempfile(fileext = ".sqlite")
  handle <- nordstatExtras::nxt_open(path)
  on.exit({
    nordstatExtras::nxt_close(handle)
    unlink(c(path, paste0(path, c("-wal","-shm"))), force = TRUE)
  })

  tables <- make_fake_tables()

  # Simulate a crash after the second fetch
  fetch_calls <- 0L
  local_mocked_bindings(
    fetch_table_metadata = function(api, table_id, verbose = FALSE) {
      fetch_calls <<- fetch_calls + 1L
      if (fetch_calls > 2L) stop("simulated network failure")
      mock_fetch_raw(api, table_id, verbose)
    }
  )

  try(
    table_enrich(tables, cache = TRUE, cache_location = handle),
    silent = TRUE
  )

  # TAB1 and TAB2 should be cached, TAB3 missing
  ch1 <- nordstatExtras::nxt_cache_handler(
    source = "pixieweb", entity = "enriched_row", cache = TRUE,
    cache_location = handle, kind = "metadata",
    key_params = list(alias = "fake", lang = "sv", table_id = "TAB1")
  )
  ch3 <- nordstatExtras::nxt_cache_handler(
    source = "pixieweb", entity = "enriched_row", cache = TRUE,
    cache_location = handle, kind = "metadata",
    key_params = list(alias = "fake", lang = "sv", table_id = "TAB3")
  )
  expect_true(ch1("discover"))
  expect_false(ch3("discover"))

  # Resume: replace mock with a working one and re-call
  fetch_calls <- 0L
  local_mocked_bindings(
    fetch_table_metadata = function(api, table_id, verbose = FALSE) {
      fetch_calls <<- fetch_calls + 1L
      mock_fetch_raw(api, table_id, verbose)
    }
  )
  r <- table_enrich(tables, cache = TRUE, cache_location = handle)
  expect_equal(fetch_calls, 1L)  # only TAB3 re-fetched
  expect_equal(nrow(r), 3L)
  expect_true(all(!is.na(r$contents)))
})

test_that("async = TRUE returns partial result with nxt_promise attribute", {
  skip_if_not_installed("mirai")
  path <- tempfile(fileext = ".sqlite")
  handle <- nordstatExtras::nxt_open(path)
  on.exit({
    nordstatExtras::nxt_close(handle)
    unlink(c(path, paste0(path, c("-wal","-shm"))), force = TRUE)
  })

  tables <- make_fake_tables()

  # Skip if mirai can't be used in the test environment — on some CI the
  # worker subprocess doesn't have the dev packages installed.
  skip_if_not(tryCatch({
    m <- mirai::mirai(1 + 1)
    mirai::call_mirai(m)
    identical(m$data, 2)
  }, error = function(e) FALSE), "mirai worker not functional")

  # mocked_bindings doesn't propagate to the background process, so instead
  # verify the immediate partial-return behavior — we don't need the worker
  # to actually succeed, just to launch and return a mirai task object.
  result <- table_enrich(tables, cache = TRUE, cache_location = handle,
                         async = TRUE)

  # All rows pending since cache is cold
  expect_equal(length(attr(result, "nxt_pending_ids")), 3L)
  expect_false(is.null(attr(result, "nxt_promise")))
  expect_s3_class(attr(result, "nxt_promise"), "mirai")

  # Don't wait for the background job (it will likely fail with no real
  # API to hit). Just verify the immediate contract.
})
