# Unit tests for selection helpers and resolve_selection()

test_that("px_top creates a px_selection object", {
  sel <- px_top(5)
  expect_s3_class(sel, "px_selection")
  expect_equal(sel$type, "top")
  expect_equal(sel$values, "5")
})

test_that("px_bottom creates a px_selection object", {
  sel <- px_bottom(3)
  expect_s3_class(sel, "px_selection")
  expect_equal(sel$type, "bottom")
  expect_equal(sel$values, "3")
})

test_that("px_all creates a px_selection with default pattern", {
  sel <- px_all()
  expect_s3_class(sel, "px_selection")
  expect_equal(sel$type, "all")
  expect_equal(sel$values, "*")
})

test_that("px_all accepts custom pattern", {
  sel <- px_all("01*")
  expect_equal(sel$values, "01*")
})

test_that("px_from and px_to create correct selections", {
  from_sel <- px_from("2020")
  expect_equal(from_sel$type, "from")
  expect_equal(from_sel$values, "2020")

  to_sel <- px_to("2023")
  expect_equal(to_sel$type, "to")
  expect_equal(to_sel$values, "2023")
})

test_that("px_range creates a two-value selection", {
  sel <- px_range("2020", "2023")
  expect_equal(sel$type, "range")
  expect_equal(sel$values, c("2020", "2023"))
})

test_that("px_top rejects non-positive input", {
  expect_error(px_top(-1))
  expect_error(px_top(0))
  expect_error(px_top("a"))
})

test_that("print.px_selection produces output", {
  expect_output(print(px_top(5)), "px_selection")
})

# resolve_selection tests (internal)
test_that("resolve_selection_v2 handles character vectors", {
  result <- pixieweb:::resolve_selection_v2(c("0180", "1480"))
  expect_equal(result, list("0180", "1480"))
})

test_that("resolve_selection_v2 handles wildcard", {
  result <- pixieweb:::resolve_selection_v2("*")
  expect_equal(result, list("*"))
})

test_that("resolve_selection_v2 handles px_top", {
  result <- pixieweb:::resolve_selection_v2(px_top(3))
  expect_equal(result, list("top(3)"))
})

test_that("resolve_selection_v2 handles px_range", {
  result <- pixieweb:::resolve_selection_v2(px_range("2020", "2023"))
  expect_equal(result, list("range(2020,2023)"))
})

test_that("resolve_selection_v1 rejects v2-only types", {
  expect_error(pixieweb:::resolve_selection_v1(px_bottom(3)), "v2")
  expect_error(pixieweb:::resolve_selection_v1(px_from("2020")), "v2")
  expect_error(pixieweb:::resolve_selection_v1(px_range("2020", "2023")), "v2")
})

test_that("resolve_selection_v1 handles item selection", {
  result <- pixieweb:::resolve_selection_v1(c("0180", "1480"))
  expect_equal(result$filter, "item")
  expect_equal(result$values, list("0180", "1480"))
})

test_that("resolve_selection_v1 handles wildcard", {
  result <- pixieweb:::resolve_selection_v1("*")
  expect_equal(result$filter, "all")
})
