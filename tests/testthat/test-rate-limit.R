# A rate limit (HTTP 429) is waited out, then stops with an error; it is
# never returned as an empty answer.

resp_429 <- function(headers = list()) {
  httr2::response(status_code = 429, headers = headers, body = charToRaw(""))
}

test_that("px_get stops with pixieweb_rate_limited after five longer waits", {
  waits <- numeric(0)
  local_mocked_bindings(px_sleep = function(seconds) waits <<- c(waits, seconds))
  httr2::local_mocked_responses(function(req) resp_429())
  err <- expect_error(px_get("https://example.org/api"), class = "pixieweb_rate_limited")
  expect_equal(waits, c(2, 4, 8, 16, 32))
  expect_match(conditionMessage(err), "429")
  expect_equal(err$url, "https://example.org/api")
})

test_that("px_post stops with an error too, and no warning returns NULL", {
  local_mocked_bindings(px_sleep = function(seconds) NULL)
  httr2::local_mocked_responses(function(req) resp_429())
  expect_no_warning(
    expect_error(px_post("https://example.org/api", list(a = 1)), class = "pixieweb_rate_limited")
  )
})

test_that("a Retry-After header sets the wait, capped at 60 seconds", {
  waits <- numeric(0)
  local_mocked_bindings(px_sleep = function(seconds) waits <<- c(waits, seconds))
  httr2::local_mocked_responses(function(req) resp_429(list(`Retry-After` = "120")))
  expect_error(px_get("https://example.org/api"), class = "pixieweb_rate_limited")
  expect_equal(waits, rep(60, 5))
})

test_that("a request that gets through after a 429 returns its answer", {
  n <- 0
  local_mocked_bindings(px_sleep = function(seconds) NULL)
  httr2::local_mocked_responses(function(req) {
    n <<- n + 1
    if (n == 1) resp_429() else httr2::response_json(body = list(ok = TRUE))
  })
  expect_equal(px_get("https://example.org/api"), list(ok = TRUE))
})
