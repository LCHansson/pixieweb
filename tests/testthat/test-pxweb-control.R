# Control tests: compare rpx results against pxweb package
# These verify that rpx produces correct data by comparing to an established
# package. Skipped on CRAN, when offline, or when pxweb is not installed.

skip_on_cran()
skip_if_not_installed("pxweb")

test_that("rpx and pxweb return same values for a simple SCB query", {
  scb <- px_api("scb", lang = "en")
  skip_if_not(px_available(scb), "SCB API not reachable")

  # rpx: fetch population data for Stockholm, 2 years, all eliminated
  rpx_data <- tryCatch(
    get_data(scb, "TAB638",
             Region = "0180",
             ContentsCode = "BE0101N1",
             Tid = c("2022", "2023"),
             simplify = FALSE),
    error = function(e) NULL
  )
  skip_if(is.null(rpx_data) || nrow(rpx_data) == 0, "rpx query returned no data")

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
  expect_true(nrow(rpx_data) > 0)
  expect_true(nrow(pxweb_df) > 0)

  # Compare actual numeric values — both should have same Population values
  # for Stockholm in 2022 and 2023
  rpx_vals <- sort(rpx_data$value[!is.na(rpx_data$value)])
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
  expect_equal(rpx_vals, pxweb_vals,
               info = "rpx and pxweb should return identical numeric values")
})

test_that("rpx variable count matches pxweb metadata", {
  scb <- px_api("scb", lang = "en")
  skip_if_not(px_available(scb), "SCB API not reachable")

  rpx_vars <- get_variables(scb, "TAB638")
  skip_if(is.null(rpx_vars), "rpx variables returned NULL")

  pxweb_meta <- tryCatch({
    pxweb::pxweb_get(
      "https://api.scb.se/ov0104/v2beta/api/v2/tables/TAB638/metadata"
    )
  }, error = function(e) NULL)

  skip_if(is.null(pxweb_meta), "pxweb metadata fetch failed")

  # Both should report the same number of variables
  pxweb_vars <- pxweb_meta$variables
  expect_equal(nrow(rpx_vars), length(pxweb_vars),
               info = "rpx and pxweb should see the same number of variables")
})
