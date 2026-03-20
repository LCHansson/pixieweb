#' Compose a table query URL
#'
#' Build the URL for querying the tables endpoint (advanced use).
#'
#' @param api A `<px_api>` object.
#' @param query Free-text search string.
#' @param id Table ID(s).
#' @param updated_since Days since last update.
#' @param page Page number.
#' @param per_page Results per page.
#' @return A character URL string.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   compose_table_query(scb, query = "population")
#' }}
compose_table_query <- function(api, query = NULL, id = NULL,
                                updated_since = NULL,
                                page = NA, per_page = NA) {
  check_px_api(api)

  if (api$version != "v2") {
    abort("compose_table_query() requires PX-Web API v2.")
  }

  if (!is.null(id) && length(id) == 1) {
    return(api_url(api, "tables", id))
  }

  url <- api_url(api, "tables")

  params <- list()
  if (!is.null(query)) params$query <- query
  if (!is.null(updated_since)) params$pastDays <- updated_since
  if (!is.na(page)) params$pageNumber <- page
  if (!is.na(per_page)) params$pageSize <- per_page

  if (length(params) == 0) return(url)

  query_str <- paste(names(params), params, sep = "=", collapse = "&")
  paste0(url, "&", query_str)
}

#' Compose a data query
#'
#' Build the URL and JSON body for a data request without executing it.
#' Useful for inspecting or modifying queries before sending them.
#'
#' @param api A `<px_api>` object.
#' @param table_id Single table ID.
#' @param ... Variable selections (same as [get_data()]).
#' @param .codelist Named list of codelist overrides.
#' @return A list with `$url` (character) and `$body` (list, JSON-serializable).
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   q <- compose_data_query(scb, "TAB638", Region = c("0180"), Tid = px_top(5))
#'   str(q$url)
#'   str(q$body)
#' }}
compose_data_query <- function(api, table_id, ..., .codelist = NULL) {
  check_px_api(api)
  stopifnot(is.character(table_id), length(table_id) == 1)

  selections <- list(...)

  if (api$version == "v2") {
    url <- paste0(api_url(api, "tables", table_id, "data"), "&outputFormat=json-stat2")
    body <- build_query_body_v2(selections, .codelist, api)
  } else {
    url <- px_url(api_base_url(api), table_id)
    body <- build_query_body_v1(selections, .codelist)
  }

  list(url = url, body = body)
}

#' Build v2 query body
#' @noRd
build_query_body_v2 <- function(selections, codelist, api) {
  sel_list <- lapply(names(selections), function(var_code) {
    value <- selections[[var_code]]
    value_codes <- resolve_selection(value, api_version = "v2")

    entry <- list(
      variableCode = var_code,
      valueCodes = value_codes
    )

    # Add codelist if specified
    if (!is.null(codelist) && var_code %in% names(codelist)) {
      entry$codeList <- codelist[[var_code]]
    }

    entry
  })

  list(
    selection = sel_list
  )
}

#' Build v1 query body
#' @noRd
build_query_body_v1 <- function(selections, codelist) {
  query_list <- lapply(names(selections), function(var_code) {
    value <- selections[[var_code]]
    resolved <- resolve_selection(value, api_version = "v1")

    list(
      code = var_code,
      selection = list(
        filter = resolved$filter,
        values = resolved$values
      )
    )
  })

  list(
    query = query_list,
    response = list(format = "json")
  )
}

#' Execute a composed query
#'
#' Low-level function to execute a query built with [compose_data_query()].
#' Handles rate limiting, retries, and error handling.
#'
#' @param api A `<px_api>` object.
#' @param url API endpoint URL.
#' @param body JSON body as a list, or `NULL` for GET requests.
#' @param verbose Print request details.
#' @return Parsed JSON as a list, or `NULL` on failure.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   q <- compose_data_query(scb, "TAB638", Region = "0180", Tid = px_top(3))
#'   raw <- execute_query(scb, q$url, q$body)
#' }}
execute_query <- function(api, url, body = NULL, verbose = FALSE) {
  check_px_api(api)

  if (is.null(body)) {
    px_get(url, verbose = verbose)
  } else {
    px_post(url, body, verbose = verbose)
  }
}
