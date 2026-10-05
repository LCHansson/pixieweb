.onLoad <- function(libname, pkgname) {
  # Package startup configuration can go here
}

.onAttach <- function(libname, pkgname) {
  msg <- masking_note(search())
  if (!is.null(msg)) packageStartupMessage(msg)
}

#' The note shown when a sister package with its own get_data() is attached
#' @param attached Character vector as returned by `search()`.
#' @return A string, or NULL when there is nothing to say.
#' @noRd
masking_note <- function(attached) {
  if (!"package:rTrafa" %in% attached) return(NULL)
  paste0(
    "pixieweb and rTrafa both export get_data(); the one attached last wins.\n",
    "In a script that uses both, call px_get_data() and trafa_get_data() ",
    "(or pixieweb::get_data() and rTrafa::get_data())."
  )
}
