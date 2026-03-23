# Mocked API tests — always run, no network required

test_that("get_tables_v2 parses mocked response correctly", {
  mock_response <- list(
    tables = list(
      list(
        id = "TAB1",
        label = "Test table",
        description = "A test",
        category = "public",
        updated = "2024-01-01T00:00:00Z",
        firstPeriod = "2000",
        lastPeriod = "2024",
        timeUnit = "Annual",
        variableNames = list("Region", "Tid"),
        source = "TestSource",
        subjectCode = "BE",
        discontinued = FALSE,
        paths = list(list(
          list(id = "BE", label = "Population")
        ))
      )
    ),
    page = list(pageNumber = 1, pageSize = 100, totalElements = 1, totalPages = 1)
  )

  api <- structure(
    list(base_url = "https://example.com/api/v2",
         alias = "test", lang = "en", version = "v2",
         config = list(max_cells = 100000)),
    class = "px_api"
  )

  local_mocked_bindings(
    px_get = function(url, verbose = FALSE) mock_response
  )

  result <- pixieweb:::get_tables_v2(api, query = "test", id = NULL,
                                 updated_since = NULL, max_results = 100,
                                 verbose = FALSE)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 1)
  expect_equal(result$id, "TAB1")
  expect_equal(result$first_period, "2000")
  expect_equal(result$subject_path, "Population")
  expect_equal(result$source, "TestSource")
})

test_that("get_tables returns NULL on API failure", {
  api <- structure(
    list(base_url = "https://example.com/api/v2",
         alias = "test", lang = "en", version = "v2",
         config = list(max_cells = 100000)),
    class = "px_api"
  )

  local_mocked_bindings(
    px_get = function(url, verbose = FALSE) NULL
  )

  result <- get_tables(api, query = "test")
  expect_null(result)
})

test_that("get_variables_v2 parses json-stat metadata", {
  mock_metadata <- list(
    dimension = list(
      Region = list(
        label = "region",
        category = list(
          index = list(`0180` = 0, `1480` = 1),
          label = list(`0180` = "Stockholm", `1480` = "Goteborg")
        ),
        extension = list(elimination = TRUE, codelists = list())
      ),
      Tid = list(
        label = "year",
        category = list(
          index = list(`2023` = 0, `2024` = 1),
          label = list(`2023` = "2023", `2024` = "2024")
        ),
        extension = list(elimination = FALSE, codelists = list())
      )
    ),
    id = c("Region", "Tid"),
    role = list(time = "Tid")
  )

  api <- structure(
    list(base_url = "https://example.com/api/v2",
         alias = "test", lang = "en", version = "v2",
         config = list(max_cells = 100000)),
    class = "px_api"
  )

  local_mocked_bindings(
    px_get = function(url, verbose = FALSE) mock_metadata
  )

  result <- pixieweb:::get_variables_v2(api, "TAB1", verbose = FALSE)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_equal(result$code, c("Region", "Tid"))
  expect_true(result$elimination[1])
  expect_false(result$elimination[2])
  expect_true(result$time[2])
  expect_equal(result$n_values, c(2L, 2L))
})

test_that("get_data handles multi-table ID with informative error", {
  api <- structure(
    list(base_url = "https://example.com/api/v2",
         alias = "test", lang = "en", version = "v2",
         config = list(max_cells = 100000)),
    class = "px_api"
  )

  expect_error(
    get_data(api, c("TAB1", "TAB2")),
    "single table ID"
  )
})

test_that("get_data accepts px_query object", {
  api <- structure(
    list(base_url = "https://example.com/api/v2",
         alias = "test", description = "Test",
         lang = "en", version = "v2",
         config = list(max_cells = 100000)),
    class = "px_api"
  )

  mock_json_stat <- list(
    dimension = list(
      Region = list(
        label = "region",
        category = list(
          index = list(`0180` = 0),
          label = list(`0180` = "Stockholm")
        )
      ),
      Tid = list(
        label = "year",
        category = list(
          index = list(`2024` = 0),
          label = list(`2024` = "2024")
        )
      )
    ),
    id = c("Region", "Tid"),
    value = list(500000)
  )

  local_mocked_bindings(
    px_post = function(url, body, verbose = FALSE) mock_json_stat
  )

  q <- structure(
    list(
      api = api,
      table_id = "TAB1",
      selections = list(Region = c("0180"), Tid = px_top(1)),
      reasons = list(Region = "test", Tid = "test"),
      variables = tibble::tibble(
        code = c("Region", "Tid"),
        text = c("region", "year"),
        n_values = c(1L, 1L),
        elimination = c(FALSE, FALSE),
        time = c(FALSE, TRUE),
        values = list(
          tibble::tibble(code = "0180", text = "Stockholm"),
          tibble::tibble(code = "2024", text = "2024")
        ),
        codelists = list(NULL, NULL),
        table_id = "TAB1"
      ),
      .codelist = NULL,
      max_cells = 100000
    ),
    class = "px_query"
  )

  result <- get_data(api, query = q)
  expect_s3_class(result, "tbl_df")
  expect_equal(result$Region, "0180")
})
