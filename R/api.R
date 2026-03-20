#' Connect to a PX-Web API
#'
#' Creates a `<px_api>` connection object used by all other rpx functions.
#' You can pass a known alias (e.g. `"scb"`, `"ssb"`) or a full base URL.
#'
#' @param x An API alias from `px_api_catalogue()` or a full base URL.
#' @param lang Language code (e.g. `"sv"`, `"en"`). `NULL` uses the API default.
#' @param version API version: `"v2"` (default) or `"v1"`.
#' @param verbose Print connection details.
#' @return A `<px_api>` object.
#' @export
#' @examples
#' \dontrun{
#' scb <- px_api("scb", lang = "en")
#' ssb <- px_api("ssb", lang = "no")
#' custom <- px_api("https://my.statbank.example/api/v2/", lang = "en")
#' }
px_api <- function(x, lang = NULL, version = "v2", verbose = FALSE) {
  stopifnot(is.character(x), length(x) == 1)
  stopifnot(version %in% c("v1", "v2"))

  catalogue <- px_api_catalogue()
  match_row <- catalogue[catalogue$alias == tolower(x), ]

  if (nrow(match_row) == 1) {
    # Known alias
    alias <- match_row$alias
    description <- match_row$description

    if (version == "v2" && "v2" %in% match_row$versions[[1]]) {
      base_url <- match_row$url
    } else if ("v1" %in% match_row$versions[[1]]) {
      base_url <- match_row$url_v1
      version <- "v1"
    } else {
      base_url <- match_row$url
    }

    lang <- lang %||% match_row$default_lang
  } else if (grepl("^https?://", x)) {
    # Custom URL
    alias <- NULL
    description <- x
    base_url <- sub("/+$", "", x)
    lang <- lang %||% "en"
  } else {
    abort(paste0(
      "Unknown API alias '", x, "'. ",
      "Use px_api_catalogue() to see available APIs, ",
      "or provide a full URL."
    ))
  }

  # Build the API object
  api <- structure(
    list(
      base_url = base_url,
      alias = alias,
      description = description,
      lang = lang,
      version = version,
      config = NULL
    ),
    class = "px_api"
  )

  # Try to fetch config (v2 only)
  if (version == "v2") {
    api$config <- fetch_api_config(api, verbose = verbose)
  }

  if (verbose) inform(format(api))

  api
}

#' Fetch API configuration
#' @param api A `<px_api>` object.
#' @param verbose Print details.
#' @return A list with config values, or a default list on failure.
#' @noRd
fetch_api_config <- function(api, verbose = FALSE) {
  config_url <- px_url(api$base_url, "config")
  raw <- px_get(config_url, verbose = verbose)

  if (is.null(raw)) {
    # Sensible defaults if config endpoint unavailable
    return(list(
      max_cells = 100000,
      max_calls = 30,
      time_window = 10,
      langs = list()
    ))
  }

  list(
    max_cells = raw$maxDataCells %||% raw$maxValues %||% 100000,
    max_calls = raw$maxCallsPerTimeWindow %||% raw$maxCalls %||% 30,
    time_window = raw$timeWindow %||% 10,
    langs = raw$languages %||% list(),
    default_format = raw$defaultDataFormat %||% "json-stat2",
    cors = raw$CORS %||% FALSE,
    api_version = raw$apiVersion %||% NULL
  )
}

#' @rdname px_api
#' @param x A `<px_api>` object.
#' @param ... Ignored.
#' @export
print.px_api <- function(x, ...) {
  cat(format(x), "\n")
  invisible(x)
}

#' @rdname px_api
#' @export
format.px_api <- function(x, ...) {
  label <- if (!is.null(x$alias)) {
    paste0("PX-Web API: ", x$description, " (", x$version, ", ", x$lang, ")")
  } else {
    paste0("PX-Web API: ", x$base_url, " (", x$version, ", ", x$lang, ")")
  }

  if (!is.null(x$config)) {
    label <- paste0(
      label,
      "\n  Max cells: ", x$config$max_cells,
      " | Rate limit: ", x$config$max_calls, "/", x$config$time_window, "s"
    )
  }

  label
}

#' List known PX-Web API instances
#'
#' Returns a tibble of known PX-Web APIs with their aliases, URLs,
#' supported versions, and available languages.
#'
#' @return A tibble with columns: `alias`, `description`, `url`, `url_v1`,
#'   `versions`, `langs`, `default_lang`.
#' @export
#' @examples
#' px_api_catalogue()
px_api_catalogue <- function() {
  path <- system.file("extdata", "api_catalogue.json", package = "rpx")

  if (path == "") {
    # Fallback: try relative path (dev mode)
    path <- file.path("inst", "extdata", "api_catalogue.json")
  }

  raw <- jsonlite::fromJSON(path, simplifyDataFrame = TRUE)
  tibble::as_tibble(raw)
}

#' Check if a PX-Web API is reachable
#'
#' @param api A `<px_api>` object.
#' @return Logical: `TRUE` if the API responds, `FALSE` otherwise.
#' @export
#' @examples
#' \dontrun{
#' scb <- px_api("scb")
#' px_available(scb)
#' }
px_available <- function(api) {
  check_px_api(api)

  url <- if (api$version == "v2") {
    px_url(api_base_url(api), "config")
  } else {
    api_base_url(api)
  }

  res <- tryCatch(
    httr2::request(url) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_timeout(5) |>
      httr2::req_perform(),
    error = function(e) NULL
  )

  !is.null(res) && httr2::resp_status(res) < 400
}

#' Get the base URL for API requests
#'
#' For v2, the base URL is used as-is (language is passed as a query parameter).
#' For v1, the language is part of the URL path.
#'
#' @param api A `<px_api>` object.
#' @return Character URL.
#' @noRd
api_base_url <- function(api) {
  if (api$version == "v2") {
    api$base_url
  } else {
    px_url(api$base_url, api$lang)
  }
}
