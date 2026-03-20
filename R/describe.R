# Shared *_describe() formatting utilities

#' Format a heading for describe output
#' @param text Heading text.
#' @param level Heading level (number of `#` characters).
#' @param format "inline" for console-width rules, "md" for markdown headings.
#' @return Formatted heading string.
#' @noRd
format_heading <- function(text, level = 2, format = "inline") {
  if (format == "md") {
    paste0(strrep("#", level), " ", text)
  } else {
    # Console-friendly: use cli-style rule
    width <- min(getOption("width", 80), 80)
    rule <- strrep("\u2500", max(0, width - nchar(text) - 3))
    paste0("\u2500\u2500 ", text, " ", rule)
  }
}

#' Print a field label-value pair
#' @param label Field label.
#' @param value Field value.
#' @return Formatted string.
#' @noRd
format_field <- function(label, value) {
  if (is.null(value) || (is.character(value) && value == "")) {
    return(NULL)
  }
  paste0("  ", label, ": ", value)
}

#' Truncate a character vector for display
#' @param x Character vector.
#' @param max_n Maximum items to show.
#' @return Single string with items and "... and N more" suffix.
#' @noRd
truncate_list <- function(x, max_n = 5) {
  if (length(x) <= max_n) {
    return(paste(x, collapse = ", "))
  }
  remaining <- length(x) - max_n
  paste0(
    paste(x[seq_len(max_n)], collapse = ", "),
    " ... and ", remaining, " more"
  )
}
