#' Get the unit and measurement properties of a table's contents
#'
#' Returns one row per value of the table's contents variable (the measures),
#' with the unit the source states for it. The unit is the fact a number
#' cannot be read without (`tkr` or `mnkr`?), and it is not part of what
#' [get_variables()] returns.
#'
#' For a v2 API the table metadata carries the unit, together with the
#' measuring type (stock or flow), price type (current or fixed), seasonal
#' adjustment and reference period where the source states them. One request.
#'
#' A v1 API states no unit in its table metadata, but answers a data request
#' in json-stat2 form with the same block. `get_contents()` therefore asks
#' for a single cell in that form, and once more for every value of the
#' contents variable when there are several: at most two small data requests
#' on top of the metadata. A v1 table without a contents variable, or an
#' instance that does not serve json-stat2, gives zero rows or `NULL`; a
#' field the source does not state is `NA`.
#'
#' @param api A `<px_api>` object.
#' @param table_id A single table ID (character).
#' @param verbose Print request details.
#' @return A tibble with columns `table_id`, `variable` (the code of the
#'   contents variable), `code`, `text`, `unit`, `decimals`,
#'   `measuring_type`, `price_type`, `adjustment`, `refperiod` and
#'   `base_period`; or `NULL` when the API could not be reached.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   get_contents(scb, "TAB638")
#' }}
get_contents <- function(api, table_id, verbose = FALSE) {
  check_px_api(api)
  stopifnot(is.character(table_id), length(table_id) == 1)

  raw <- if (api$version == "v2") {
    px_get(api_url(api, "tables", table_id, "metadata"), verbose = verbose)
  } else {
    contents_probe_v1(api, table_id, verbose = verbose)
  }
  if (is.null(raw)) return(NULL)

  parse_contents(raw, table_id)
}

#' The dimensions of a json-stat2 object that hold the contents (measures)
#' @param raw Parsed json-stat2 (metadata or data response).
#' @return Character vector of dimension names.
#' @noRd
contents_dims <- function(raw) {
  dims <- raw$dimension %||% list()
  metric <- intersect(as.character(unlist(raw$role$metric)), names(dims))
  if (length(metric) > 0) return(metric)
  has_unit <- vapply(dims, function(d) length(d$category$unit) > 0, logical(1))
  names(dims)[has_unit]
}

#' Build the contents tibble from a json-stat2 object
#' @noRd
parse_contents <- function(raw, table_id) {
  empty <- tibble::tibble(
    table_id = character(), variable = character(), code = character(),
    text = character(), unit = character(), decimals = integer(),
    measuring_type = character(), price_type = character(),
    adjustment = character(), refperiod = character(),
    base_period = character()
  )

  dims <- raw$dimension %||% list()
  metric <- contents_dims(raw)
  if (length(metric) == 0) return(empty)

  rows <- lapply(metric, function(dname) {
    d <- dims[[dname]]
    labels <- d$category$label %||% list()
    codes <- names(labels)
    if (length(codes) == 0) return(NULL)
    ext <- d$extension %||% list()

    # One value per code out of a `{code: value}` or `{code: {field: value}}`
    # block; NA where the source says nothing for that code.
    per_code <- function(block, field = NULL) {
      vapply(codes, function(k) {
        e <- if (is.list(block)) block[[k]] else NULL
        if (!is.null(field)) e <- if (is.list(e)) e[[field]] else NULL
        if (is.null(e) || length(e) == 0) NA_character_ else as.character(e)[1]
      }, character(1), USE.NAMES = FALSE)
    }

    tibble::tibble(
      table_id = table_id,
      variable = dname,
      code = codes,
      text = px_chr(labels),
      unit = per_code(d$category$unit, "base"),
      decimals = suppressWarnings(as.integer(per_code(d$category$unit, "decimals"))),
      measuring_type = per_code(ext$measuringType),
      price_type = per_code(ext$priceType),
      adjustment = per_code(ext$adjustment),
      refperiod = per_code(ext$refperiod),
      base_period = per_code(ext$basePeriod)
    )
  })

  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0) return(empty)
  dplyr::bind_rows(rows)
}

#' Ask a v1 instance for its contents block via a minimal json-stat2 request
#' @noRd
contents_probe_v1 <- function(api, table_id, verbose = FALSE) {
  vars <- get_variables(api, table_id, verbose = verbose)
  if (is.null(vars) || nrow(vars) == 0) return(NULL)

  first <- lapply(seq_len(nrow(vars)), function(i) px_chr(vars$values[[i]]$code)[1])
  names(first) <- vars$code
  if (anyNA(unlist(first))) return(NULL)

  pause <- (api$config$time_window %||% 10) / (api$config$max_calls %||% 30)
  ask <- function(selection) {
    Sys.sleep(pause)
    q <- do.call(
      compose_data_query,
      c(list(api = api, table_id = table_id), selection)
    )
    q$body$response$format <- "json-stat2"
    execute_query(api, q$url, q$body, verbose = verbose)
  }

  raw <- ask(first)
  if (is.null(raw)) return(NULL)

  # The single cell names the contents variable but only one of its values;
  # widen that one variable to get the unit of every measure.
  wide <- intersect(contents_dims(raw), vars$code[vars$n_values > 1])
  if (length(wide) > 0) {
    selection <- first
    selection[wide] <- "*"
    all_measures <- ask(selection)
    if (!is.null(all_measures)) raw <- all_measures
  }

  raw
}
