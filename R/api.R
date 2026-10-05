#' Connect to a PX-Web API
#'
#' Creates a `<px_api>` connection object used by all other pixieweb functions.
#' You can pass a known alias (e.g. `"scb"`, `"ssb"`) or a full base URL.
#'
#' @param x An API alias from `px_api_catalogue()` or a full base URL.
#' @param lang Language code (e.g. `"sv"`, `"en"`). `NULL` uses the API default.
#' @param version API version: `"v2"` (default) or `"v1"`.
#' @param verbose Print connection details.
#' @return A `<px_api>` object.
#' @export
#' @examples
#' \donttest{
#' if (px_available(px_api("scb"))) {
#'   scb <- px_api("scb", lang = "en")
#'   ssb <- px_api("ssb", lang = "no")
#'   custom <- px_api("https://my.statbank.example/api/v2/", lang = "en")
#' }}
px_api <- function(x, lang = NULL, version = "v2", verbose = FALSE) {
  # Input validation
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

  # Fetch the instance's own limits. v2 has a /config endpoint; v1 answers
  # `?config` on the language root. A v1 instance that does not answer
  # leaves `config` NULL, and callers fall back to their defaults.
  if (version == "v2") {
    api$config <- fetch_api_config(api, verbose = verbose)
  } else {
    api$config <- fetch_api_config_v1(api, verbose = verbose)
  }

  if (verbose) inform(format(api))

  api
}

# Package-private config cache: one /config round-trip per base_url per
# session-day instead of per px_api() call (~80–100 ms saved per call;
# config is static in practice: max_cells, rate limits).
.px_config_cache <- new.env(parent = emptyenv())

#' Fetch API configuration (memoized per base_url, TTL 24 h)
#' @param api A `<px_api>` object.
#' @param verbose Print details.
#' @return A list with config values, or a default list on failure.
#' @noRd
fetch_api_config <- function(api, verbose = FALSE) {
  cache_key <- api$base_url
  hit <- .px_config_cache[[cache_key]]
  if (!is.null(hit) && difftime(Sys.time(), hit$at, units = "hours") < 24) {
    return(hit$config)
  }
  config <- fetch_api_config_live(api, verbose = verbose)
  assign(cache_key, list(config = config, at = Sys.time()), envir = .px_config_cache)
  config
}

#' @noRd
fetch_api_config_live <- function(api, verbose = FALSE) {
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

#' Fetch a v1 instance's limits (memoized per base_url + language, TTL 24 h)
#'
#' PX-Web v1 reports `maxCells`, `maxCalls` and `timeWindow` on
#' `<base>/<lang>/?config`. They differ between instances (Konjunkturinstitutet
#' allows 10 calls per 10 s, a third of the package default), so chunked
#' fetches must pace by the instance's own numbers. Quiet by design: an
#' instance that does not answer gives NULL, never a warning, and is asked
#' again on the next `px_api()` call.
#' @param api A `<px_api>` object (v1).
#' @param verbose Print details.
#' @return A list with `max_cells`, `max_calls`, `time_window`, or NULL.
#' @noRd
fetch_api_config_v1 <- function(api, verbose = FALSE) {
  cache_key <- paste0(api$base_url, "|v1|", api$lang)
  hit <- .px_config_cache[[cache_key]]
  if (!is.null(hit) && difftime(Sys.time(), hit$at, units = "hours") < 24) {
    return(hit$config)
  }
  config <- parse_api_config_v1(fetch_api_config_v1_live(api, verbose = verbose))
  if (!is.null(config)) {
    assign(cache_key, list(config = config, at = Sys.time()), envir = .px_config_cache)
  }
  config
}

#' @noRd
fetch_api_config_v1_live <- function(api, verbose = FALSE) {
  url <- paste0(api_base_url(api), "/?config")
  if (verbose) inform(paste("GET", url))
  res <- tryCatch(
    httr2::request(url) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_timeout(5) |>
      httr2::req_perform(),
    error = function(e) NULL
  )
  if (is.null(res) || httr2::resp_status(res) >= 400) return(NULL)
  tryCatch(suppressWarnings(parse_json_response(res)), error = function(e) NULL)
}

#' @noRd
parse_api_config_v1 <- function(raw) {
  num <- function(x) if (is.numeric(x) && length(x) == 1 && !is.na(x) && x > 0) x else NULL
  if (!is.list(raw)) return(NULL)
  cells <- num(raw$maxCells)
  calls <- num(raw$maxCalls)
  window <- num(raw$timeWindow)
  if (is.null(cells) && is.null(calls)) return(NULL)
  list(
    max_cells = cells %||% 100000,
    max_calls = calls %||% 30,
    time_window = window %||% 10
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
  path <- system.file("extdata", "api_catalogue.json", package = "pixieweb")

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
#' \donttest{
#' scb <- px_api("scb")
#' if (px_available(scb)) {
#'   px_available(scb)
#' }}
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
