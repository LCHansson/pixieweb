#' Generate a citation for downloaded data
#'
#' Produces a citation string from metadata attached to data by [get_data()].
#'
#' @param data_df A tibble returned by [get_data()].
#' @return A character string (formatted citation).
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   d <- get_data(scb, "TAB638", Region = "0180", Tid = px_top(3))
#'   px_cite(d)
#' }}
px_cite <- function(data_df) {
  source <- attr(data_df, "px_source")

  if (is.null(source)) {
    warn("No source metadata found. Was this data fetched with get_data()?")
    return(NA_character_)
  }

  paste0(
    source$api, ". ",
    "Table: ", source$table_id, ". ",
    "Retrieved via rpx on ", format(source$fetched, "%Y-%m-%d"), "."
  )
}
