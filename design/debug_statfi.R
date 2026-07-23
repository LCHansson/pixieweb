devtools::load_all()
api <- px_api("statfi", lang = "en", version = "v1")

# Check what the metadata endpoint returns
url <- rpx:::px_url(rpx:::api_base_url(api), "StatFin/matk/statfin_matk_pxt_117s.px")
cat("URL:", url, "\n")
raw <- rpx:::px_get(url)
cat("Names:", paste(names(raw), collapse = ", "), "\n")

if (!is.null(raw$variables)) {
  cat("\nVariables:\n")
  for (v in raw$variables) {
    cat("  code:", v$code, "text:", v$text, "\n")
    cat("    type:", v$type %||% "NULL", "\n")
    cat("    elimination:", v$elimination %||% "NULL", "\n")
    cat("    time:", v$time %||% "NULL", "\n")
    cat("    n values:", length(v$values), "\n")
    cat("    has valueTexts:", !is.null(v$valueTexts), "\n")
  }
}

# Now try get_variables and capture the actual error
vars <- tryCatch(
  get_variables(api, "StatFin/matk/statfin_matk_pxt_117s.px"),
  error = function(e) { cat("\nERROR:", conditionMessage(e), "\n"); e },
  warning = function(w) { cat("\nWARN:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") }
)
if (inherits(vars, "data.frame")) {
  cat("\nResult:\n")
  print(vars)
}
