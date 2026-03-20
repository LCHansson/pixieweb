#' Get codelists for a variable in a table
#'
#' Codelists provide alternative groupings of variable values
#' (e.g. municipalities grouped into counties).
#'
#' @param api A `<px_api>` object.
#' @param table_id Table ID (character).
#' @param variable_code Variable code (character).
#' @param verbose Print request details.
#' @return A tibble with columns: `id`, `text`, `type`, `values`.
#' @export
#' @examples
#' \dontrun{
#' scb <- px_api("scb", lang = "en")
#' get_codelists(scb, "TAB638", "Region")
#' }
get_codelists <- function(api, table_id, variable_code, verbose = FALSE) {
  check_px_api(api)
  stopifnot(is.character(table_id), length(table_id) == 1)
  stopifnot(is.character(variable_code), length(variable_code) == 1)

  if (api$version == "v2") {
    get_codelists_v2(api, table_id, variable_code, verbose)
  } else {
    # v1: codelists are embedded in metadata, extract from get_variables
    get_codelists_v1(api, table_id, variable_code, verbose)
  }
}

#' @noRd
get_codelists_v2 <- function(api, table_id, variable_code, verbose) {
  # First get variable metadata which includes codelist references
  vars <- get_variables(api, table_id, verbose = verbose)
  if (is.null(vars)) return(NULL)

  var_row <- vars[vars$code == variable_code, ]
  if (nrow(var_row) == 0) {
    warn(paste0("Variable '", variable_code, "' not found in table '", table_id, "'."))
    return(NULL)
  }

  cls <- var_row$codelists[[1]]
  if (is.null(cls) || nrow(cls) == 0) {
    inform(paste0("No codelists available for variable '", variable_code, "'."))
    return(tibble::tibble(
      id = character(), text = character(), type = character(), values = list()
    ))
  }

  # Fetch values for each codelist
  rows <- lapply(seq_len(nrow(cls)), function(i) {
    cl_id <- cls$id[i]
    cl_url <- api_url(api, "codelists", cl_id)
    raw <- px_get(cl_url, verbose = verbose)

    vals <- if (!is.null(raw) && !is.null(raw$values)) {
      tibble::tibble(
        code = vapply(raw$values, function(x) x$code %||% "", character(1)),
        text = vapply(raw$values, function(x) x$label %||% x$text %||% "", character(1))
      )
    } else {
      tibble::tibble(code = character(), text = character())
    }

    tibble::tibble(
      id = cl_id,
      text = cls$text[i],
      type = cls$type[i] %||% NA_character_,
      values = list(vals)
    )
  })

  dplyr::bind_rows(rows)
}

#' @noRd
get_codelists_v1 <- function(api, table_id, variable_code, verbose) {
  # v1 doesn't have a separate codelists endpoint
  # Codelists are part of the variable metadata
  vars <- get_variables(api, table_id, verbose = verbose)
  if (is.null(vars)) return(NULL)

  var_row <- vars[vars$code == variable_code, ]
  if (nrow(var_row) == 0) {
    warn(paste0("Variable '", variable_code, "' not found in table '", table_id, "'."))
    return(NULL)
  }

  cls <- var_row$codelists[[1]]
  if (is.null(cls) || nrow(cls) == 0) {
    inform(paste0("No codelists available for variable '", variable_code, "' (v1 API)."))
    return(tibble::tibble(
      id = character(), text = character(), type = character(), values = list()
    ))
  }

  cls |>
    dplyr::mutate(values = list(tibble::tibble(code = character(), text = character())))
}

#' Print human-readable codelist summaries
#'
#' @param cl_df A tibble returned by [get_codelists()].
#' @param max_n Maximum codelists to describe.
#' @param format Output format: `"inline"` or `"md"`.
#' @param heading_level Heading level.
#' @return `cl_df` invisibly (for piping).
#' @export
#' @examples
#' \dontrun{
#' scb <- px_api("scb", lang = "en")
#' get_codelists(scb, "TAB638", "Region") |> codelist_describe()
#' }
codelist_describe <- function(cl_df, max_n = 5, format = "inline",
                              heading_level = 2) {
  if (is.null(cl_df) || nrow(cl_df) == 0) {
    warn("No codelists to describe.")
    return(invisible(cl_df))
  }

  n <- min(max_n, nrow(cl_df))

  for (i in seq_len(n)) {
    row <- cl_df[i, ]
    cat(format_heading(
      paste0(row$id, ": ", row$text),
      level = heading_level,
      format = format
    ), "\n")

    cat(format_field("Type", row$type), "\n")

    vals <- row$values[[1]]
    if (nrow(vals) > 0) {
      cat(format_field("Values", paste0(nrow(vals), " items")), "\n")
      val_display <- paste(vals$code, vals$text, sep = " ")
      cat("  First:", truncate_list(val_display, 5), "\n")
    }
    cat("\n")
  }

  invisible(cl_df)
}

#' Extract codelist IDs
#'
#' @param cl_df A tibble returned by [get_codelists()].
#' @return A character vector of codelist IDs.
#' @export
#' @examples
#' \dontrun{
#' scb <- px_api("scb", lang = "en")
#' get_codelists(scb, "TAB638", "Region") |> codelist_extract_ids()
#' }
codelist_extract_ids <- function(cl_df) {
  if (is.null(cl_df) || nrow(cl_df) == 0) return(character())
  cl_df$id
}

#' Extract values for a specific codelist
#'
#' @param cl_df A tibble returned by [get_codelists()].
#' @param codelist_id Codelist ID (character).
#' @return A tibble with columns `code` and `text`.
#' @export
#' @examples
#' \dontrun{
#' scb <- px_api("scb", lang = "en")
#' cls <- get_codelists(scb, "TAB638", "Region")
#' codelist_values(cls, cls$id[1])
#' }
codelist_values <- function(cl_df, codelist_id) {
  row <- cl_df[cl_df$id == codelist_id, ]
  if (nrow(row) == 0) {
    warn(paste0("Codelist '", codelist_id, "' not found."))
    return(tibble::tibble(code = character(), text = character()))
  }
  row$values[[1]]
}
