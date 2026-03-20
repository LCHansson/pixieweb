# Selection helpers for get_data() variable filters

#' Create a PX-Web selection object
#'
#' These helpers create `<px_selection>` objects that `get_data()` translates
#' into the appropriate API filter. Each represents a different way to select
#' variable values in PX-Web queries.
#'
#' @param pattern Glob pattern (default `"*"` for all).
#' @param n Number of values.
#' @param value Value code (inclusive bound).
#' @param from,to Value codes for range bounds (inclusive).
#' @return A `<px_selection>` object.
#'
#' @name px_selections
NULL

#' @rdname px_selections
#' @export
px_all <- function(pattern = "*") {
  new_px_selection("all", values = pattern)
}

#' @rdname px_selections
#' @export
px_top <- function(n) {
  stopifnot(is.numeric(n), length(n) == 1, n > 0)
  new_px_selection("top", values = as.character(as.integer(n)))
}

#' @rdname px_selections
#' @export
px_bottom <- function(n) {
  stopifnot(is.numeric(n), length(n) == 1, n > 0)
  new_px_selection("bottom", values = as.character(as.integer(n)))
}

#' @rdname px_selections
#' @export
px_from <- function(value) {
  stopifnot(is.character(value), length(value) == 1)
  new_px_selection("from", values = value)
}

#' @rdname px_selections
#' @export
px_to <- function(value) {
  stopifnot(is.character(value), length(value) == 1)
  new_px_selection("to", values = value)
}

#' @rdname px_selections
#' @export
px_range <- function(from, to) {
  stopifnot(is.character(from), length(from) == 1)
  stopifnot(is.character(to), length(to) == 1)
  new_px_selection("range", values = c(from, to))
}

# Constructor
new_px_selection <- function(type, values) {
  structure(
    list(type = type, values = values),
    class = "px_selection"
  )
}

#' @rdname px_selections
#' @param x A `<px_selection>` object.
#' @param ... Ignored.
#' @export
print.px_selection <- function(x, ...) {
  label <- switch(x$type,
    all    = paste0("all(", x$values, ")"),
    top    = paste0("top(", x$values, ")"),
    bottom = paste0("bottom(", x$values, ")"),
    from   = paste0("from(", x$values, ")"),
    to     = paste0("to(", x$values, ")"),
    range  = paste0("range(", x$values[1], ", ", x$values[2], ")"),
    paste0(x$type, "(", paste(x$values, collapse = ", "), ")")
  )
  cat("<px_selection>", label, "\n")
  invisible(x)
}

#' Translate a user-supplied variable value into valueCodes for the API
#'
#' Converts the `...` arguments of `get_data()` to the `valueCodes` list
#' used in the POST body. For v2, selection expressions like top(N) are
#' encoded as `["top(3)"]`. For v1, they use the filter/values structure.
#'
#' @param value A character vector, `"*"`, or a `<px_selection>` object.
#' @param api_version `"v1"` or `"v2"`.
#' @return For v2: a list of strings suitable for `valueCodes`.
#'   For v1: a list with `$filter` and `$values`.
#' @noRd
resolve_selection <- function(value, api_version = "v2") {
  if (api_version == "v2") {
    return(resolve_selection_v2(value))
  }
  resolve_selection_v1(value)
}

#' @noRd
resolve_selection_v2 <- function(value) {
  if (inherits(value, "px_selection")) {
    # v2 encodes expressions as "top(3)", "from(2020)", "range(x,y)" etc.
    expr <- switch(value$type,
      all    = value$values,  # "*" or a glob pattern
      top    = paste0("top(", value$values, ")"),
      bottom = paste0("bottom(", value$values, ")"),
      from   = paste0("from(", value$values, ")"),
      to     = paste0("to(", value$values, ")"),
      range  = paste0("range(", value$values[1], ",", value$values[2], ")"),
      abort(paste0("Unknown selection type: ", value$type))
    )
    return(as.list(expr))
  }

  # Plain character vector = item selection
  if (is.character(value)) {
    if (length(value) == 1 && value == "*") {
      return(list("*"))
    }
    return(as.list(value))
  }

  abort("Variable selection must be a character vector or a px_*() helper.")
}

#' @noRd
resolve_selection_v1 <- function(value) {
  if (inherits(value, "px_selection")) {
    v2_only <- c("bottom", "from", "to", "range")
    if (value$type %in% v2_only) {
      abort(paste0(
        "Selection type '", value$type, "' requires PX-Web API v2. ",
        "This API is running v1."
      ))
    }

    return(switch(value$type,
      all = list(filter = "all", values = as.list(value$values)),
      top = list(filter = "top", values = as.list(value$values))
    ))
  }

  if (is.character(value)) {
    if (length(value) == 1 && value == "*") {
      return(list(filter = "all", values = list("*")))
    }
    return(list(filter = "item", values = as.list(value)))
  }

  abort("Variable selection must be a character vector or a px_*() helper.")
}
