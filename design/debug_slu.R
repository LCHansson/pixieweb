devtools::load_all()
api <- px_api("slu", lang = "sv", version = "v1")

url <- rpx:::px_url(rpx:::api_base_url(api), "OffStat/AM_Areal_agoslag_SVL_tab.px")
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
  }
}

# Try get_variables
vars <- tryCatch(
  get_variables(api, "OffStat/AM_Areal_agoslag_SVL_tab.px"),
  error = function(e) { cat("\nERROR:", conditionMessage(e), "\n"); e },
  warning = function(w) { cat("\nWARN:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") }
)
if (inherits(vars, "data.frame")) {
  cat("\nVariables result:\n")
  print(vars)

  # Try prepare_query
  q <- tryCatch(
    prepare_query(api, "OffStat/AM_Areal_agoslag_SVL_tab.px"),
    error = function(e) { cat("\nprepare_query ERROR:", conditionMessage(e), "\n"); e },
    warning = function(w) { cat("\nprepare_query WARN:", conditionMessage(w), "\n"); invokeRestart("muffleWarning") }
  )
  if (inherits(q, "px_query")) {
    cat("\nQuery selections:\n")
    print(q$selections)
  }
}
