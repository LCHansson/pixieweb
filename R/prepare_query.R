#' Prepare a data query with smart defaults
#'
#' Bridges the gap between table/variable exploration and data fetching.
#' Fetches variable metadata, applies sensible defaults for variable
#' selections, and returns a query object that can be passed to [get_data()].
#'
#' Default selection strategy:
#' - **ContentsCode**: all values (`"*"`)
#' - **Time variable**: most recent 10 periods (`px_top(10)`)
#' - **Eliminable variables**: omitted (API aggregates automatically)
#' - **Small mandatory variables** (<= `max_default_values` values): all (`"*"`)
#' - **Large mandatory variables**: first value only (`px_top(1)`)
#'
#' When `maximize_selection = TRUE`, the function expands selections to use
#' as much of the API's cell limit as possible. Expansion order: smallest
#' eliminable variables first, then smallest mandatory, then time last.
#'
#' @param api A `<px_api>` object.
#' @param table_id A single table ID (character).
#' @param ... Optional variable selections to override defaults. Each named
#'   argument is a variable code with a selection value (same syntax as
#'   [get_data()]).
#' @param .codelist Named list of codelist overrides.
#' @param max_default_values Maximum number of values for a variable to receive
#'   a wildcard default. Defaults to `22` (covers e.g. Swedish län).
#' @param maximize_selection If `TRUE`, expand unspecified variables to include
#'   as many values as possible while staying under the API cell limit.
#' @param verbose Print request details.
#' @return A `<px_query>` object. Pass to [get_data()] via the `query`
#'   parameter.
#'
#' @details
#' The returned query object prints a human-readable summary showing what
#' was selected for each variable and why. Modify selections before passing
#' to `get_data()` by assigning to the `$selections` list.
#'
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'
#'   # Prepare with defaults
#'   q <- prepare_query(scb, "TAB638")
#'   q
#'
#'   # Override specific variables, let defaults handle the rest
#'   q <- prepare_query(scb, "TAB638", Region = c("0180", "1480"))
#'
#'   # Maximize data within API limits
#'   q <- prepare_query(scb, "TAB638", maximize_selection = TRUE)
#'
#'   # Fetch data from a prepared query
#'   get_data(scb, query = q)
#' }}
prepare_query <- function(api,
                          table_id,
                          ...,
                          .codelist = NULL,
                          max_default_values = 22,
                          maximize_selection = FALSE,
                          verbose = FALSE) {
  check_px_api(api)
  stopifnot(is.character(table_id), length(table_id) == 1)

  # Fetch variable metadata
  vars <- get_variables(api, table_id, verbose = verbose)
  if (is.null(vars) || nrow(vars) == 0) {
    abort(paste0("Could not retrieve variables for table '", table_id, "'."))
  }

  user_selections <- list(...)
  max_cells <- api$config$max_cells %||% 100000

  # Classify each variable and assign defaults
  selections <- list()
  reasons <- list()

  for (i in seq_len(nrow(vars))) {
    v <- vars[i, ]
    code <- v$code
    n <- v$n_values
    is_time <- isTRUE(v$time)
    is_contents <- grepl("^Contents?Code$", code, ignore.case = TRUE)
    can_eliminate <- isTRUE(v$elimination)

    if (code %in% names(user_selections)) {
      # User override — use as-is
      selections[[code]] <- user_selections[[code]]
      reasons[[code]] <- "user override"
    } else if (is_contents) {
      selections[[code]] <- "*"
      reasons[[code]] <- paste0("all ", n, " content variable(s)")
    } else if (is_time) {
      selections[[code]] <- px_top(10)
      reasons[[code]] <- paste0("latest 10 of ", n, " periods")
    } else if (can_eliminate) {
      # Eliminable: omit by default (NULL means eliminated)
      selections[[code]] <- NULL
      reasons[[code]] <- paste0("eliminated (", n, " values available)")
    } else if (n <= max_default_values) {
      selections[[code]] <- "*"
      reasons[[code]] <- paste0("all ", n, " values (small mandatory)")
    } else {
      selections[[code]] <- px_top(1)
      reasons[[code]] <- paste0("first of ", n, " values (large mandatory)")
    }
  }

  if (maximize_selection) {
    expanded <- maximize_query_selections(
      selections, reasons, vars, max_cells
    )
    selections <- expanded$selections
    reasons <- expanded$reasons
  }

  query <- structure(
    list(
      api = api,
      table_id = table_id,
      selections = selections,
      reasons = reasons,
      variables = vars,
      .codelist = .codelist,
      max_cells = max_cells
    ),
    class = "px_query"
  )

  # Print the summary so the user sees what was chosen
  print(query)

  invisible(query)
}

#' Expand selections to maximize data within API cell limit
#' @noRd
maximize_query_selections <- function(selections, reasons, vars, max_cells) {
  # Calculate current cell count
  current_sizes <- compute_selection_sizes(selections, vars)
  current_cells <- prod(unlist(current_sizes))

  # Build expansion candidates: variables we could upgrade
  # Priority: eliminated vars (smallest first), then capped mandatory (smallest

  # first), then time (last)
  eliminated <- list()
  capped <- list()
  time_var <- NULL

  for (i in seq_len(nrow(vars))) {
    v <- vars[i, ]
    code <- v$code
    is_time <- isTRUE(v$time)
    is_contents <- grepl("^Contents?Code$", code, ignore.case = TRUE)

    if (is_contents) next
    if (reasons[[code]] == "user override") next

    if (is_time) {
      time_var <- list(code = code, n_values = v$n_values)
    } else if (is.null(selections[[code]])) {
      # Currently eliminated
      eliminated <- c(eliminated, list(list(code = code, n_values = v$n_values)))
    } else if (inherits(selections[[code]], "px_selection") &&
               selections[[code]]$type == "top" &&
               as.integer(selections[[code]]$values) < v$n_values) {
      # Currently capped with px_top()
      capped <- c(capped, list(list(code = code, n_values = v$n_values)))
    }
  }

  # Sort by number of values (smallest first)
  eliminated <- eliminated[order(vapply(eliminated, function(x) x$n_values, numeric(1)))]
  capped <- capped[order(vapply(capped, function(x) x$n_values, numeric(1)))]

  # Expansion order: eliminated -> capped -> time
  candidates <- c(eliminated, capped)
  if (!is.null(time_var)) candidates <- c(candidates, list(time_var))

  for (cand in candidates) {
    code <- cand$code
    n <- cand$n_values

    # What's the current effective size for this variable?
    current_size <- current_sizes[[code]]
    # What would it be if we wildcard it?
    new_size <- n

    if (new_size <= current_size) next

    # Would it fit?
    new_cells <- as.numeric(current_cells / current_size) * new_size
    if (new_cells <= max_cells) {
      selections[[code]] <- "*"
      reasons[[code]] <- paste0(
        "all ", n, " values (expanded by maximize_selection)"
      )
      current_sizes[[code]] <- new_size
      current_cells <- new_cells
    }
  }

  list(selections = selections, reasons = reasons)
}

#' Compute effective size of each variable selection
#' @noRd
compute_selection_sizes <- function(selections, vars) {
  sizes <- list()
  for (i in seq_len(nrow(vars))) {
    v <- vars[i, ]
    code <- v$code
    sel <- selections[[code]]

    if (is.null(sel)) {
      # Eliminated — contributes 1 to the product
      sizes[[code]] <- 1
    } else if (is.character(sel) && length(sel) == 1 && sel == "*") {
      sizes[[code]] <- v$n_values
    } else if (is.character(sel)) {
      sizes[[code]] <- length(sel)
    } else if (inherits(sel, "px_selection")) {
      sizes[[code]] <- switch(sel$type,
        top = min(as.integer(sel$values), v$n_values),
        bottom = min(as.integer(sel$values), v$n_values),
        all = v$n_values,
        # For from/to/range, estimate conservatively as all values
        v$n_values
      )
    } else {
      sizes[[code]] <- v$n_values
    }
  }
  sizes
}

#' @rdname prepare_query
#' @param x A `<px_query>` object.
#' @param ... Ignored.
#' @export
print.px_query <- function(x, ...) {
  cat(format_heading(
    paste0("Query: ", x$table_id),
    level = 2, format = "inline"
  ), "\n")

  estimated_cells <- prod(unlist(compute_selection_sizes(x$selections, x$variables)))
  pct <- round(100 * estimated_cells / x$max_cells, 1)
  cat("  Estimated cells: ", estimated_cells, " / ", x$max_cells,
      " (", pct, "% of limit)\n", sep = "")

  if (estimated_cells > x$max_cells) {
    cat("  NOTE: This query exceeds the API limit. get_data() will automatically\n")
    cat("  split it into multiple requests. Set auto_chunk = FALSE to disable.\n")
  }
  cat("\n")

  for (i in seq_len(nrow(x$variables))) {
    v <- x$variables[i, ]
    code <- v$code
    sel <- x$selections[[code]]
    reason <- x$reasons[[code]]

    # Format the selection value
    sel_display <- if (is.null(sel)) {
      "<eliminated>"
    } else if (is.character(sel) && length(sel) == 1 && sel == "*") {
      '"*"'
    } else if (is.character(sel)) {
      if (length(sel) <= 5) {
        paste0('c("', paste(sel, collapse = '", "'), '")')
      } else {
        paste0('c("', paste(utils::head(sel, 3), collapse = '", "'),
               '", ... +', length(sel) - 3, " more)")
      }
    } else if (inherits(sel, "px_selection")) {
      paste0("px_", sel$type, "(", paste(sel$values, collapse = ", "), ")")
    } else {
      as.character(sel)
    }

    cat("  ", code, " = ", sel_display, "\n", sep = "")
    cat("    ", reason, "\n", sep = "")
  }

  invisible(x)
}
