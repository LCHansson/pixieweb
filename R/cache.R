# Cache handler (closure pattern from rKolada)

#' Get the persistent rpx cache directory
#'
#' Returns the path to the user-level cache directory for rpx, creating it
#' if it does not exist. Uses [tools::R_user_dir()] so the cache survives
#' across R sessions.
#'
#' @return A single character string (directory path).
#' @export
#' @examples
#' rpx_cache_dir()
rpx_cache_dir <- function() {
  dir <- tools::R_user_dir("rpx", "cache")
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  dir
}

#' Build a cache filename from entity + key_params
#' @noRd
cache_filename <- function(entity, key_params) {
  alias <- key_params$alias %||% "default"
  # Build a hash from sorted key_params
  sorted_keys <- key_params[order(names(key_params))]
  hash_input <- paste(
    names(sorted_keys),
    vapply(sorted_keys, function(x) paste(x, collapse = ","), character(1)),
    sep = "=", collapse = ";"
  )
  hash_full <- rlang::hash(hash_input)
  hash_short <- substr(hash_full, 1, 12)

  paste0("rpx_", entity, "_", alias, "_", hash_short, "_", Sys.Date(), ".rds")
}

#' Create a cache handler
#'
#' Returns a function that manages caching of API responses.
#' Modeled after rKolada's cache_handler pattern.
#'
#' @param entity Character entity name (e.g. "tables", "enriched").
#' @param cache Logical, whether to enable caching.
#' @param cache_location Directory for cache files. Defaults to `rpx_cache_dir`.
#' @param key_params A named list of values that, together with `entity`, form
#'   a unique cache key. Different params produce different cache files.
#' @return A function with signature `(method, df)` where method is
#'   "discover", "load", or "store".
#' @noRd
cache_handler <- function(entity, cache, cache_location, key_params = list()) {
  if (is.function(cache_location)) {
    cache_location <- cache_location()
  }

  storage <- if (isTRUE(cache)) {
    file.path(cache_location, cache_filename(entity, key_params))
  } else {
    ""
  }

  # No-op handler when caching is disabled
  if (storage == "") {
    return(function(method, df = NULL) {
      if (method == "store") return(df)
      return(FALSE)
    })
  }

  # Active handler
  function(method, df = NULL) {
    switch(method,
      discover = file.exists(storage),
      load = readRDS(storage),
      store = {
        saveRDS(df, file = storage)
        return(df)
      },
      NULL
    )
  }
}

#' Clear rpx cache files
#'
#' Removes cached API responses stored in the default or specified location.
#' Can selectively clear by entity type and/or API.
#'
#' @param entity Character entity to clear (e.g. `"tables"`, `"enriched"`),
#'   or `NULL` (default) to clear all rpx cache files.
#' @param api A `<px_api>` object. If provided, only cache files for that
#'   API's alias are cleared. `NULL` (default) clears all APIs.
#' @param cache_location Directory to clear. Defaults to [rpx_cache_dir()].
#' @return `invisible(NULL)`
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb")
#' if (px_available(scb)) {
#'   rpx_clear_cache()
#'   rpx_clear_cache(entity = "tables")
#'   rpx_clear_cache(api = scb)
#'   rpx_clear_cache(entity = "enriched", api = scb)
#' }}
rpx_clear_cache <- function(entity = NULL, api = NULL,
                            cache_location = rpx_cache_dir()) {
  # Build pattern: rpx_{entity}_{alias}_{hash}_{date}.rds
  entity_part <- if (!is.null(entity)) entity else "[^_]+"
  alias_part <- if (!is.null(api)) (api$alias %||% "default") else "[^_]+"
  pattern <- paste0("^rpx_", entity_part, "_", alias_part, "_[a-f0-9]+_.*\\.rds$")

  files <- list.files(cache_location, pattern = pattern, full.names = TRUE)

  if (length(files) > 0) {
    file.remove(files)
    inform(paste("Removed", length(files), "cached file(s)."))
  } else {
    inform("No rpx cache files found.")
  }

  invisible(NULL)
}
