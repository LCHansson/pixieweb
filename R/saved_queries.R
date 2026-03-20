#' Execute a saved query
#'
#' PX-Web v2 saved queries are server-side stored query definitions
#' (table + variable selections) that can be shared via ID/URL.
#'
#' @param api A `<px_api>` object.
#' @param query_id Saved query ID (character).
#' @param .output `"long"` (default) or `"wide"`.
#' @param simplify Add text label columns.
#' @param verbose Print request details.
#' @return A tibble in the same format as [get_data()].
#' @export
#' @examples
#' \dontrun{
#' scb <- px_api("scb", lang = "en")
#' get_saved_query(scb, "some-query-id")
#' }
get_saved_query <- function(api,
                            query_id,
                            .output = "long",
                            simplify = TRUE,
                            verbose = FALSE) {
  check_px_api(api)
  stopifnot(is.character(query_id), length(query_id) == 1)

  if (api$version != "v2") {
    abort("Saved queries require PX-Web API v2.")
  }

  url <- paste0(
    api_url(api, "savedqueries", query_id, "data"),
    "&outputFormat=json-stat2"
  )
  raw <- px_get(url, verbose = verbose)

  if (is.null(raw)) return(NULL)

  # Saved query responses are in the same format as data responses
  result <- parse_data_v2(raw, table_id = query_id, simplify = simplify)

  if (!is.null(result) && .output == "wide") {
    result <- pivot_data_wide(result)
  }

  result
}

#' Save a query on the server
#'
#' Persists a set of variable selections server-side so the query can be
#' shared or re-used later.
#'
#' @param api A `<px_api>` object.
#' @param table_id Table ID (character).
#' @param ... Variable selections (same as [get_data()]).
#' @param .codelist Named list of codelist overrides.
#' @param verbose Print request details.
#' @return A character string: the saved query ID.
#' @export
#' @examples
#' \dontrun{
#' scb <- px_api("scb", lang = "en")
#' query_id <- save_query(scb, "TAB638", Region = "0180", Tid = px_top(5))
#' }
save_query <- function(api,
                       table_id,
                       ...,
                       .codelist = NULL,
                       verbose = FALSE) {
  check_px_api(api)
  stopifnot(is.character(table_id), length(table_id) == 1)

  if (api$version != "v2") {
    abort("Saving queries requires PX-Web API v2.")
  }

  q <- compose_data_query(api, table_id, ..., .codelist = .codelist)

  url <- api_url(api, "savedqueries")
  # The API expects selection as a VariablesSelection object wrapping
  # the selection array, plus language and output format metadata
  body <- list(
    tableId = table_id,
    selection = q$body,
    language = api$lang,
    outputFormat = api$config$default_format %||% "json-stat2",
    outputFormatParams = list("UseCodes")
  )

  raw <- px_post(url, body, verbose = verbose)

  if (is.null(raw)) return(NULL)

  raw$id %||% raw$queryId %||% NA_character_
}
