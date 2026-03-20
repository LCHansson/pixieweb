#' Get variables (dimensions) for a table
#'
#' Retrieves the variable structure of a PX-Web table, including available
#' values and codelists. This is the key discovery step before fetching data.
#'
#' @param api A `<px_api>` object.
#' @param table_id A single table ID (character).
#' @param verbose Print request details.
#' @return A tibble with columns: `code`, `text`, `n_values`, `elimination`,
#'   `time`, `values`, `codelists`, `table_id`.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   get_variables(scb, "TAB638")
#' }}
get_variables <- function(api, table_id, verbose = FALSE) {
  check_px_api(api)
  stopifnot(is.character(table_id), length(table_id) == 1)

  if (api$version == "v2") {
    get_variables_v2(api, table_id, verbose)
  } else {
    get_variables_v1(api, table_id, verbose)
  }
}

#' @noRd
get_variables_v2 <- function(api, table_id, verbose) {
  url <- api_url(api, "tables", table_id, "metadata")
  raw <- px_get(url, verbose = verbose)
  if (is.null(raw)) return(NULL)

  # json-stat2 metadata: dimensions are in raw$dimension (named list),
  # dimension order in raw$id, variable info in dimension$extension
  dims <- raw$dimension %||% list()
  dim_order <- raw$id %||% names(dims)

  if (length(dims) == 0) return(empty_variables_tibble(table_id))

  # Determine which dimension is the time variable (from raw$role$time)
  time_dims <- raw$role$time %||% character()

  rows <- lapply(dim_order, function(dname) {
    d <- dims[[dname]]
    cats <- d$category

    # Extract value codes and labels from category
    code_vec <- names(cats$label)
    text_vec <- as.character(cats$label)

    vals <- tibble::tibble(code = code_vec, text = text_vec)

    # Extension holds elimination and codelists info
    ext <- d$extension %||% list()
    elimination <- ext$elimination %||% FALSE
    is_time <- dname %in% time_dims

    # Codelists from extension
    cls <- if (!is.null(ext$codelists) && length(ext$codelists) > 0) {
      tibble::tibble(
        id = vapply(ext$codelists, function(x) x$id %||% "", character(1)),
        text = vapply(ext$codelists, function(x) x$label %||% x$text %||% "", character(1)),
        type = vapply(ext$codelists, function(x) x$type %||% "", character(1))
      )
    } else {
      NULL
    }

    tibble::tibble(
      code = dname,
      text = d$label %||% dname,
      n_values = nrow(vals),
      elimination = elimination,
      time = is_time,
      values = list(vals),
      codelists = list(cls),
      table_id = table_id
    )
  })

  dplyr::bind_rows(rows)
}

#' @noRd
get_variables_v1 <- function(api, table_id, verbose) {
  url <- px_url(api_base_url(api), table_id)
  raw <- px_get(url, verbose = verbose)
  if (is.null(raw)) return(NULL)

  variables <- raw$variables %||% list()
  if (length(variables) == 0) return(empty_variables_tibble(table_id))

  rows <- lapply(variables, function(v) {
    val_codes <- v$values %||% character()
    val_texts <- v$valueTexts %||% val_codes

    vals <- tibble::tibble(
      code = val_codes,
      text = val_texts
    )

    tibble::tibble(
      code = v$code %||% NA_character_,
      text = v$text %||% NA_character_,
      n_values = nrow(vals),
      elimination = v$elimination %||% FALSE,
      time = v$time %||% FALSE,
      values = list(vals),
      codelists = list(NULL),
      table_id = table_id
    )
  })

  dplyr::bind_rows(rows)
}

#' @noRd
empty_variables_tibble <- function(table_id) {
  tibble::tibble(
    code = character(), text = character(), n_values = integer(),
    elimination = logical(), time = logical(),
    values = list(), codelists = list(),
    table_id = character()
  )
}

#' Client-side search on a variable tibble
#'
#' Searches across variable codes, texts, and optionally nested value texts.
#'
#' @param var_df A tibble returned by [get_variables()].
#' @param query Character vector of search terms (combined with OR).
#' @param column Column names to search. `NULL` searches `code` and `text`.
#' @return A filtered tibble.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   vars <- get_variables(scb, "TAB638")
#'   vars |> variable_search("region")
#' }}
variable_search <- function(var_df, query, column = NULL) {
  column <- column %||% c("code", "text")
  entity_search(var_df, query, column, caller = "variable_search")
}

#' Print human-readable variable summaries
#'
#' @param var_df A tibble returned by [get_variables()].
#' @param max_n Maximum number of variables to describe.
#' @param format Output format: `"inline"` or `"md"`.
#' @param heading_level Heading level.
#' @return `var_df` invisibly (for piping).
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   get_variables(scb, "TAB638") |> variable_describe()
#' }}
variable_describe <- function(var_df, max_n = 10, format = "inline",
                              heading_level = 2) {
  if (is.null(var_df) || nrow(var_df) == 0) {
    warn("No variables to describe.")
    return(invisible(var_df))
  }

  n <- min(max_n, nrow(var_df))

  for (i in seq_len(n)) {
    row <- var_df[i, ]
    cat(format_heading(
      paste0(row$code, " (", row$text, ")"),
      level = heading_level,
      format = format
    ), "\n")

    status <- if (isTRUE(row$elimination)) "optional (elimination)" else "mandatory"
    cat(format_field("Values", paste0(row$n_values, ", ", status)), "\n")

    if (isTRUE(row$time)) cat("  Time variable: Yes\n")

    # Show first few values
    vals <- row$values[[1]]
    if (nrow(vals) > 0) {
      val_display <- paste(vals$code, vals$text, sep = " ")
      cat("  First values:", truncate_list(val_display, 5), "\n")
    }

    # Show codelists if available
    cls <- row$codelists[[1]]
    if (!is.null(cls) && nrow(cls) > 0) {
      cat("  Codelists:", truncate_list(paste(cls$id, cls$text, sep = " "), 3), "\n")
    }

    cat("\n")
  }

  invisible(var_df)
}

#' Extract variable codes from a variable tibble
#'
#' @param var_df A tibble returned by [get_variables()].
#' @return A character vector of variable codes.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   get_variables(scb, "TAB638") |> variable_extract_ids()
#' }}
variable_extract_ids <- function(var_df) {
  if (is.null(var_df) || nrow(var_df) == 0) return(character())
  var_df$code
}

#' Remove nested columns for a compact variable overview
#'
#' @param var_df A tibble returned by [get_variables()].
#' @return A tibble without `values` and `codelists` columns.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   get_variables(scb, "TAB638") |> variable_minimize()
#' }}
variable_minimize <- function(var_df) {
  var_df |>
    dplyr::select(-dplyr::any_of(c("values", "codelists")))
}

#' Convert variable names to codes
#'
#' @param var_df A tibble returned by [get_variables()].
#' @param name Character vector of human-readable variable names.
#' @return A named character vector: names are the input names, values are codes.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   vars <- get_variables(scb, "TAB638")
#'   variable_name_to_code(vars, "Region")
#' }}
variable_name_to_code <- function(var_df, name) {
  matches <- var_df$code[match(tolower(name), tolower(var_df$text))]
  stats::setNames(matches, name)
}

#' Extract values for a specific variable
#'
#' @param var_df A tibble returned by [get_variables()].
#' @param variable_code Variable code (character).
#' @return A tibble with columns `code` and `text`.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   vars <- get_variables(scb, "TAB638")
#'   vars |> variable_values("Kon")
#' }}
variable_values <- function(var_df, variable_code) {
  row <- var_df[var_df$code == variable_code, ]
  if (nrow(row) == 0) {
    warn(paste0("Variable '", variable_code, "' not found."))
    return(tibble::tibble(code = character(), text = character()))
  }
  row$values[[1]]
}
