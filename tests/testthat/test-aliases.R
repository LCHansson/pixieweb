# dev-backlog 2026-09-12: pixieweb and rTrafa both export get_data().

test_that("px_get_data() is get_data() under an unmaskable name", {
  expect_error(px_get_data("not an api", "T"), "px_api")
  seen <- NULL
  testthat::local_mocked_bindings(get_data = function(...) {
    seen <<- list(...)
    "forwarded"
  })
  expect_equal(px_get_data("api", "TAB1", Tid = "2024", .status = TRUE), "forwarded")
  expect_equal(seen, list("api", "TAB1", Tid = "2024", .status = TRUE))
})

test_that("the masking note appears only beside rTrafa", {
  expect_null(masking_note(c(".GlobalEnv", "package:pixieweb", "package:stats")))
  note <- masking_note(c(".GlobalEnv", "package:pixieweb", "package:rTrafa"))
  expect_match(note, "px_get_data()", fixed = TRUE)
  expect_match(note, "trafa_get_data()", fixed = TRUE)
})
