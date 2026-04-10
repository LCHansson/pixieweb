# Internal HTTP and utility functions

#' Perform an HTTP GET request
#' @param url URL to request.
#' @param verbose Print request details.
#' @return Parsed JSON as list, or NULL on failure.
#' @noRd
px_get <- function(url, verbose = FALSE, .retry = 0L, .max_retries = 3L) {
  if (verbose) inform(paste("GET", url))

  res <- tryCatch(
    httr2::request(url) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform(),
    error = function(e) {
      warn(paste("Could not connect to PX-Web API:", conditionMessage(e)))
      return(NULL)
    }
  )

  if (is.null(res)) return(NULL)

  status <- httr2::resp_status(res)
  if (status == 429) {
    if (.retry >= .max_retries) {
      warn(paste0("Rate limited by PX-Web API after ", .max_retries, " retries: ", url))
      return(NULL)
    }
    delay <- 2^.retry
    if (verbose) inform(paste0("Rate limited (429). Retrying in ", delay, "s..."))
    Sys.sleep(delay)
    return(px_get(url, verbose = verbose, .retry = .retry + 1L, .max_retries = .max_retries))
  }
  if (status >= 400) {
    warn(paste0("PX-Web API returned HTTP ", status, " for: ", url))
    return(NULL)
  }

  parse_json_response(res)
}

#' Perform an HTTP POST request
#' @param url URL to request.
#' @param body List to serialize as JSON body.
#' @param verbose Print request details.
#' @return Parsed JSON as list, or NULL on failure.
#' @noRd
px_post <- function(url, body, verbose = FALSE, .retry = 0L, .max_retries = 3L) {
  if (verbose) {
    inform(paste("POST", url))
    inform(paste("Body:", jsonlite::toJSON(body, auto_unbox = TRUE)))
  }

  res <- tryCatch(
    httr2::request(url) |>
      httr2::req_body_json(body) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform(),
    error = function(e) {
      warn(paste("Could not connect to PX-Web API:", conditionMessage(e)))
      return(NULL)
    }
  )

  if (is.null(res)) return(NULL)

  status <- httr2::resp_status(res)
  if (status == 429) {
    if (.retry >= .max_retries) {
      warn(paste0("Rate limited by PX-Web API after ", .max_retries, " retries: ", url))
      return(NULL)
    }
    delay <- 2^.retry
    if (verbose) inform(paste0("Rate limited (429). Retrying in ", delay, "s..."))
    Sys.sleep(delay)
    return(px_post(url, body, verbose = verbose, .retry = .retry + 1L, .max_retries = .max_retries))
  }
  if (status >= 400) {
    body_text <- tryCatch(httr2::resp_body_string(res), error = function(e) "")
    warn(paste0("PX-Web API returned HTTP ", status, ": ", body_text))
    return(NULL)
  }

  parse_json_response(res)
}

#' Parse a JSON response, handling servers that return wrong content-type
#'
#' Some PX-Web instances (e.g. SCB v2beta) return `application/octet-stream`
#' instead of `application/json`. This helper tries `resp_body_json()` first,
#' then falls back to parsing the raw body string.
#'
#' @param res An httr2 response object.
#' @return Parsed JSON as list, or NULL on failure.
#' @noRd
parse_json_response <- function(res) {
  # Try the normal path first
  result <- tryCatch(
    httr2::resp_body_json(res),
    error = function(e) NULL
  )

  if (!is.null(result)) return(result)

  # Fallback: parse body string as JSON (handles wrong content-type)
  tryCatch({
    raw_text <- httr2::resp_body_string(res)
    jsonlite::fromJSON(raw_text, simplifyVector = FALSE)
  }, error = function(e) {
    warn(paste("Failed to parse API response:", conditionMessage(e)))
    NULL
  })
}

#' Build a URL by appending path segments
#' @param ... Path segments to join.
#' @return Character URL.
#' @noRd
px_url <- function(...) {
  parts <- c(...)
  # Remove trailing/leading slashes and join
  parts <- gsub("^/+|/+$", "", parts)
  paste(parts, collapse = "/")
}

#' Add query parameters to a URL
#' @param url Base URL.
#' @param ... Named parameters. NULL values are dropped.
#' @return Character URL with query string.
#' @noRd
px_url_query <- function(url, ...) {
  params <- list(...)
  params <- params[!vapply(params, is.null, logical(1))]
  if (length(params) == 0) return(url)

  query_str <- paste(
    names(params),
    vapply(params, as.character, character(1)),
    sep = "="
  )
  paste0(url, "?", paste(query_str, collapse = "&"))
}

#' Build a v2 API URL with language as query parameter
#'
#' v2 APIs use `?lang=xx` instead of embedding the language in the URL path.
#'
#' @param api A `<px_api>` object.
#' @param ... Path segments to append after the base URL.
#' @return Character URL with `?lang=` appended.
#' @noRd
api_url <- function(api, ...) {
  url <- px_url(api_base_url(api), ...)
  if (api$version == "v2") {
    px_url_query(url, lang = api$lang)
  } else {
    url
  }
}

#' Shared search helper (like rKolada's entity_search)
#' @param df Tibble to filter.
#' @param query Character vector of search terms (combined with OR).
#' @param column Column names to search. NULL = all character columns.
#' @param caller Name of calling function for warnings.
#' @return Filtered tibble.
#' @noRd
entity_search <- function(df, query, column = NULL, caller = "search") {
  if (is.null(df) || nrow(df) == 0) {
    warn(paste0("An empty object was used as input to ", caller, "()."))
    return(df)
  }

  if (is.null(column)) {
    # Search all character columns + list columns (e.g. variables)
    chr_cols <- names(df)[vapply(df, is.character, logical(1))]
    list_cols <- names(df)[vapply(df, is.list, logical(1))]
    column <- c(chr_cols, list_cols)
  }

  pattern <- tolower(paste(query, collapse = "|"))

  # Separate character and list columns for different search strategies
  chr_cols <- intersect(column, names(df)[vapply(df, is.character, logical(1))])
  list_cols <- intersect(column, names(df)[vapply(df, is.list, logical(1))])

  # Match in character columns
  chr_match <- if (length(chr_cols) > 0) {
    apply(
      vapply(chr_cols, function(col) {
        grepl(pattern, tolower(df[[col]]), perl = TRUE)
      }, logical(nrow(df))),
      1, any
    )
  } else {
    rep(FALSE, nrow(df))
  }

  # Match in list columns (e.g. variables = list of character vectors)
  list_match <- if (length(list_cols) > 0) {
    matches <- vapply(list_cols, function(col) {
      vapply(df[[col]], function(x) {
        any(grepl(pattern, tolower(as.character(x)), perl = TRUE))
      }, logical(1))
    }, logical(nrow(df)))
    if (is.matrix(matches)) apply(matches, 1, any) else matches
  } else {
    rep(FALSE, nrow(df))
  }

  df[chr_match | list_match, , drop = FALSE]
}

#' Remove monotonous columns from a tibble
#' @param df Tibble.
#' @param remove_monotonous_data Logical.
#' @return Tibble with monotonous columns removed.
#' @noRd
remove_monotonous <- function(df, remove_monotonous_data = TRUE) {
  if (is.null(df) || !remove_monotonous_data || nrow(df) <= 1) return(df)

  keep <- vapply(df, function(col) {
    length(unique(col)) > 1
  }, logical(1))

  df[, keep, drop = FALSE]
}

#' Check that an object is a px_api
#' @param api Object to check.
#' @noRd
check_px_api <- function(api) {
  if (!inherits(api, "px_api")) {
    abort("Expected a <px_api> object. Create one with px_api().")
  }
}

#' Resolve a lang parameter, falling back to option
#' @param lang User-supplied lang or NULL.
#' @return Character: "SV" or "EN".
#' @noRd
resolve_lang <- function(lang = NULL) {
  lang <- lang %||% getOption("pixieweb.lang", "EN")
  lang <- toupper(lang)
  if (!lang %in% c("SV", "EN")) {
    abort("`lang` must be \"SV\" or \"EN\".")
  }
  lang
}
