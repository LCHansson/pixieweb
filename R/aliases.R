#' @rdname get_data
#' @section A name that cannot be masked:
#' `px_get_data()` is `get_data()` under a name no sister package exports.
#' rTrafa also exports a `get_data()`, so in a script that attaches both, the
#' package attached last masks the other and its calls fail on the wrong
#' argument check. Use `px_get_data()` here and `rTrafa::trafa_get_data()`
#' there, or prefix every call with its package.
#' @export
px_get_data <- function(...) {
  get_data(...)
}
