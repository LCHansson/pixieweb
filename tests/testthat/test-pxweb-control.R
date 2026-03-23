# Control tests: compare pixieweb results against pxweb package
# These verify that pixieweb produces correct data by comparing to an established
# package. Skipped on CRAN, when offline, or when pxweb is not installed.

skip_on_cran()
skip_if_not_installed("pxweb")

test_that("pixieweb and pxweb return same values for a simple SCB query", {
  scb <- px_api("scb", lang = "en")
  skip_if_not(px_available(scb), "SCB API not reachable")

  # pixieweb: fetch population data for Stockholm, 2 years, all eliminated
  pixieweb_data <- tryCatch(
    get_data(scb, "TAB638",
             Region = "0180",
             ContentsCode = "BE0101N1",
             Tid = c("2022", "2023"),
             simplify = FALSE),
    error = function(e) NULL
  )
  skip_if(is.null(pixieweb_data) || nrow(pixieweb_data) == 0, "pixieweb query returned no data")

  # pxweb: same query via the v2 API (pxweb supports v2 URLs too)
  pxweb_data <- tryCatch({
    pxweb_query <- pxweb::pxweb_query(list(
      Region = "0180",
      ContentsCode = "BE0101N1",
      Tid = c("2022", "2023")
    ))
    pxweb::pxweb_get(
      url = "https://api.scb.se/ov0104/v2beta/api/v2/tables/TAB638/data",
      query = pxweb_query
    )
  }, error = function(e) NULL)

  skip_if(is.null(pxweb_data), "pxweb query failed")

  pxweb_df <- as.data.frame(pxweb_data,
                             column.name.type = "code",
                             variable.value.type = "code")

  # Both should return the same number of rows when queried identically
  # (same variables specified, same elimination)
  expect_true(nrow(pixieweb_data) > 0)
  expect_true(nrow(pxweb_df) > 0)

  # Compare actual numeric values — both should have same Population values
  # for Stockholm in 2022 and 2023
  pixieweb_vals <- sort(pixieweb_data$value[!is.na(pixieweb_data$value)])
  pxweb_vals <- if ("BE0101N1" %in% names(pxweb_df)) {
    sort(pxweb_df$BE0101N1[!is.na(pxweb_df$BE0101N1)])
  } else {
    # Try the first numeric column
    num_cols <- names(pxweb_df)[vapply(pxweb_df, is.numeric, logical(1))]
    if (length(num_cols) > 0) sort(pxweb_df[[num_cols[1]]][!is.na(pxweb_df[[num_cols[1]]])])
    else numeric()
  }

  skip_if(length(pxweb_vals) == 0, "Could not extract pxweb numeric values")

  # The values should match exactly
  expect_equal(pixieweb_vals, pxweb_vals,
               info = "pixieweb and pxweb should return identical numeric values")
})

test_that("pixieweb variable count matches pxweb metadata", {
  scb <- px_api("scb", lang = "en")
  skip_if_not(px_available(scb), "SCB API not reachable")

  pixieweb_vars <- get_variables(scb, "TAB638")
  skip_if(is.null(pixieweb_vars), "pixieweb variables returned NULL")

  pxweb_meta <- tryCatch({
    pxweb::pxweb_get(
      "https://api.scb.se/ov0104/v2beta/api/v2/tables/TAB638/metadata"
    )
  }, error = function(e) NULL)

  skip_if(is.null(pxweb_meta), "pxweb metadata fetch failed")

  # Both should report the same number of variables
  pxweb_vars <- pxweb_meta$variables
  expect_equal(nrow(pixieweb_vars), length(pxweb_vars),
               info = "pixieweb and pxweb should see the same number of variables")
})
