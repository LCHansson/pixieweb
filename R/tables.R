#' Get tables from a PX-Web API
#'
#' Search for and list statistical tables available on a PX-Web instance.
#'
#' @param api A `<px_api>` object.
#' @param query Free-text search string (sent to API as server-side search).
#'   On v2 APIs (e.g. SCB) the server-side search is an **exact token match**
#'   by default — `query = "befolk"` will not find tables with "befolkning"
#'   in the title. Use explicit wildcards (`query = "befolk*"`) for prefix
#'   matching. Wildcards can also appear mid-term (e.g. `*arbets*`). This is
#'   a property of the PX-Web server, not pixieweb; behaviour may vary by
#'   agency. Case-insensitive. Non-ASCII characters (å/ä/ö etc.) are
#'   URL-encoded automatically.
#' @param id Character vector of specific table IDs to retrieve.
#' @param updated_since Only return tables updated in the last N days (integer).
#' @param max_results Maximum number of tables to return.
#' @param .timeout Maximum seconds to spend on v1 hierarchy tree walks (default
#'   15). Only relevant when a v1 API lacks a `?query=` search endpoint and must
#'   fall back to walking the folder tree. Increase for exhaustive searches on
#'   large APIs. Has no effect on v2 APIs (which have native search).
#' @param cache Logical, cache results locally.
#' @param cache_location Cache directory. Defaults to [pixieweb_cache_dir()].
#' @param verbose Print request details.
#' @return A tibble with columns: `id`, `title`, `description`, `category`,
#'   `updated`, `first_period`, `last_period`, `time_unit`, `variables`,
#'   `subject_code`, `subject_path`, `source`, `discontinued`.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'
#'   # Server-side search
#'   get_tables(scb, query = "population")
#'
#'   # Fetch specific tables by ID
#'   get_tables(scb, id = c("TAB638", "TAB1278"))
#'
#'   # Tables updated in the last 30 days
#'   get_tables(scb, updated_since = 30)
#' }}
get_tables <- function(api,
                       query = NULL,
                       id = NULL,
                       updated_since = NULL,
                       max_results = NULL,
                       .timeout = 15,
                       cache = FALSE,
                       cache_location = pixieweb_cache_dir,
                       verbose = FALSE) {
  check_px_api(api)

  key <- list(
    alias = api$alias %||% "default",
    lang = api$lang %||% "default",
    query = query %||% "",
    id = paste(sort(id %||% ""), collapse = ","),
    max_results = as.character(max_results %||% ""),
    updated_since = as.character(updated_since %||% "")
  )

  # SQLite-backed metadata cache via nordstatExtras. Opt-in when
  # cache_location is a sqlite target; otherwise the legacy .rds path
  # is used unchanged.
  #
  # NOTE: `updated_since` is a time-relative filter — a cache entry keyed
  # on updated_since=30 becomes semantically stale as the 30-day window
  # slides. Callers using updated_since should either use a short ttl_days
  # or skip the SQLite backend for that specific call.
  nxt_ch <- NULL
  ch <- NULL
  if (isTRUE(cache) && !is.null(cache_location) &&
      requireNamespace("nordstatExtras", quietly = TRUE) &&
      nordstatExtras::nxt_is_backend(cache_location)) {
    nxt_ch <- nordstatExtras::nxt_cache_handler(
      source = "pixieweb", entity = "tables", cache = TRUE,
      cache_location = cache_location,
      kind = "metadata",
      key_params = key
    )
    if (nxt_ch("discover")) return(nxt_ch("load"))
  } else {
    ch <- cache_handler("tables", cache, cache_location, key_params = key)
    if (ch("discover")) return(ch("load"))
  }

  if (api$version == "v2") {
    result <- get_tables_v2(api, query, id, updated_since, max_results, verbose)
  } else {
    result <- get_tables_v1(api, query, id, updated_since, max_results, verbose,
                            timeout = .timeout)
  }

  if (is.null(result)) return(NULL)

  # Attach the API object so downstream functions (table_enrich etc.) can use it
  attr(result, "px_api") <- api

  if (!is.null(nxt_ch)) {
    nxt_ch("store", result)
    return(result)
  }
  ch("store", result)
}

#' @noRd
get_tables_v2 <- function(api, query, id, updated_since, max_results, verbose) {
  # If specific IDs requested, fetch each
  if (!is.null(id)) {
    rows <- lapply(id, function(tid) {
      url <- api_url(api, "tables", tid)
      raw <- px_get(url, verbose = verbose)
      if (is.null(raw)) return(NULL)
      parse_table_v2(raw, api)
    })
    rows <- rows[!vapply(rows, is.null, logical(1))]
    if (length(rows) == 0) return(NULL)
    return(dplyr::bind_rows(rows))
  }

  # Search / list — paginate transparently.
  # PX-Web v2 caps pageSize server-side (SCB allows up to 10000; we use 1000
  # per page as a safe default). Loop over pageNumber until we've exhausted
  # totalPages, or until max_results has been reached.
  base <- api_url(api, "tables")

  # Target number of rows — NULL means "all". Safety: when the caller doesn't
  # set max_results and doesn't supply any filter (neither query nor
  # updated_since), cap the full-listing walk to avoid accidentally pulling
  # every table on the server.
  unbounded_full_listing <- is.null(max_results) &&
                            is.null(query) &&
                            is.null(updated_since)
  target <- max_results
  page_size <- if (!is.null(target) && is.finite(target)) {
    as.integer(min(1000L, max(1L, target)))
  } else {
    1000L
  }

  all_rows <- list()
  page_number <- 1L
  total_pages <- NA_integer_

  repeat {
    extra_params <- list(
      query = query,
      pastDays = updated_since,
      pageSize = page_size,
      pageNumber = page_number
    )
    extra_params <- extra_params[!vapply(extra_params, is.null, logical(1))]
    extra_str <- paste(
      names(extra_params),
      vapply(extra_params, function(x) {
        utils::URLencode(as.character(x), reserved = TRUE)
      }, character(1)),
      sep = "="
    )
    url <- paste0(base, "&", paste(extra_str, collapse = "&"))

    raw <- px_get(url, verbose = verbose)
    if (is.null(raw)) {
      if (page_number == 1L) return(NULL)
      break
    }

    tables <- raw$tables %||% raw
    if (length(tables) == 0) break

    all_rows <- c(all_rows, lapply(tables, function(t) parse_table_v2(t, api)))

    # Determine stop conditions
    total_pages <- raw$page$totalPages %||% total_pages
    got_rows <- length(all_rows)
    if (!is.null(target) && got_rows >= target) break
    if (!is.na(total_pages) && page_number >= total_pages) break
    # If we received fewer than page_size rows, there can be no further page
    if (length(tables) < page_size) break
    # Safety cap for truly unbounded full listings
    if (unbounded_full_listing && got_rows >= 50000L) {
      cli::cli_warn(c(
        "Stopped fetching tables at 50000 rows as a safety cap.",
        i = "Pass {.code max_results = Inf} explicitly to override, or add a {.arg query} filter."
      ))
      break
    }

    page_number <- page_number + 1L
  }

  if (length(all_rows) == 0) return(empty_tables_tibble())

  result <- dplyr::bind_rows(all_rows)
  if (!is.null(target) && nrow(result) > target) {
    result <- utils::head(result, target)
  }
  result
}

#' @noRd
parse_table_v2 <- function(raw, api) {
  # Flatten the hierarchical paths into a readable string
  # paths is a list of path arrays, each containing {id, label, sortCode}
  subject_path <- if (!is.null(raw$paths) && length(raw$paths) > 0) {
    path_labels <- vapply(
      raw$paths[[1]],
      function(p) p$label %||% p$id %||% "",
      character(1)
    )
    paste(path_labels, collapse = " > ")
  } else {
    NA_character_
  }

  tibble::tibble(
    id = raw$id %||% NA_character_,
    title = raw$label %||% raw$text %||% raw$title %||% NA_character_,
    description = raw$description %||% NA_character_,
    category = raw$category %||% NA_character_,
    updated = raw$updated %||% NA_character_,
    first_period = raw$firstPeriod %||% NA_character_,
    last_period = raw$lastPeriod %||% NA_character_,
    time_unit = raw$timeUnit %||% NA_character_,
    variables = list(raw$variableNames %||% raw$variables %||% character()),
    subject_code = raw$subjectCode %||% NA_character_,
    subject_path = subject_path,
    source = raw$source %||% api$alias %||% api$base_url,
    discontinued = raw$discontinued %||% FALSE
  )
}

#' Empty tables tibble with all columns
#' @noRd
empty_tables_tibble <- function() {
  tibble::tibble(
    id = character(), title = character(), description = character(),
    category = character(), updated = character(),
    first_period = character(), last_period = character(),
    time_unit = character(), variables = list(),
    subject_code = character(), subject_path = character(),
    source = character(), discontinued = logical()
  )
}

#' @noRd
get_tables_v1 <- function(api, query, id, updated_since, max_results, verbose,
                          timeout) {
  # If specific IDs requested, fetch metadata directly
  if (!is.null(id)) {
    rows <- lapply(id, function(tid) {
      url <- px_url(api_base_url(api), tid)
      raw <- px_get(url, verbose = verbose)
      if (is.null(raw)) return(NULL)
      parse_table_v1(raw, tid, api)
    })
    rows <- rows[!vapply(rows, is.null, logical(1))]
    if (length(rows) == 0) return(NULL)
    return(dplyr::bind_rows(rows))
  }

  base <- api_base_url(api)

  # When a search query is provided, try the v1 ?query= search endpoint first.
  # Most PX-Web v1 instances support this — it returns matching tables in a
  # single request, avoiding the slow recursive tree walk.
  if (!is.null(query)) {
    result <- search_tables_v1(api, base, query, max_results, verbose)
    if (!is.null(result)) return(result)
    # If search endpoint failed (e.g. SCB returns 400), fall back to tree walk
  }

  # Fall back: walk the top-level hierarchy (with timeout)
  raw <- px_get(base, verbose = verbose)
  if (is.null(raw)) return(NULL)

  walk_result <- v1_tree_walk_with_timeout(
    raw, base, query, verbose, max_results, timeout, api
  )

  if (is.null(walk_result)) return(NULL)
  result <- walk_result

  if (!is.null(updated_since)) {
    cutoff <- Sys.Date() - updated_since
    result <- result |>
      dplyr::filter(
        is.na(.data$updated) | as.Date(.data$updated) >= cutoff
      )
  }

  if (!is.null(max_results) && nrow(result) > max_results) {
    result <- result[seq_len(max_results), ]
  }

  result
}

#' Run the v1 tree walk with a timeout, warning on slow searches
#' @noRd
v1_tree_walk_with_timeout <- function(raw, base, query, verbose, max_results,
                                       timeout, api) {
  deadline <- Sys.time() + timeout

  tables <- collect_tables_v1(raw, base, query, verbose,
                               depth = 0, max_depth = 5, path_prefix = "",
                               max_results = max_results %||% Inf,
                               deadline = deadline)

  timed_out <- Sys.time() >= deadline
  if (timed_out) {
    n_found <- length(tables)
    msg <- paste0(
      "Table search timed out after ", timeout,
      "s (found ", n_found, " table(s) before timeout)."
    )
    hints <- c(i = "Increase the timeout: `get_tables(..., .timeout = 60)`")

    # If this API also has v2, suggest using that instead
    if (v1_api_has_v2(api)) {
      hints <- c(hints,
        i = paste0(
          "This API supports v2, which has fast server-side search: ",
          "`px_api(\"", api$alias, "\", version = \"v2\")`"
        )
      )
    }

    warn(c(msg, hints))
  }

  if (length(tables) == 0) return(NULL)
  dplyr::bind_rows(tables)
}

#' Check if a v1 API also has a v2 version in the catalogue
#' @noRd
v1_api_has_v2 <- function(api) {
  if (is.null(api$alias)) return(FALSE)
  catalogue <- tryCatch(px_api_catalogue(), error = function(e) NULL)
  if (is.null(catalogue)) return(FALSE)
  row <- catalogue[catalogue$alias == api$alias, ]
  if (nrow(row) == 0) return(FALSE)
  "v2" %in% row$versions[[1]]
}

#' Search for tables using the v1 ?query= endpoint
#'
#' Most PX-Web v1 instances support `?query=<term>` appended to a database
#' level URL. The response is a flat list of matching tables with `id`, `path`,
#' `title`, `score`, and `published` fields. This is orders of magnitude faster
#' than walking the tree.
#' @noRd
search_tables_v1 <- function(api, base, query, max_results, verbose) {
  # Get the root level to find database entry points
  root <- px_get(base, verbose = verbose)
  if (is.null(root) || length(root) == 0) return(NULL)

  # Identify database-level paths to search under
  db_paths <- vapply(root, function(item) {
    item$dbid %||% item$id %||% ""
  }, character(1))
  db_paths <- db_paths[nzchar(db_paths)]

  if (length(db_paths) == 0) return(NULL)

  all_tables <- list()

  for (db in db_paths) {
    search_url <- paste0(
      px_url(base, db),
      "?query=", utils::URLencode(query, reserved = TRUE)
    )
    raw <- suppressWarnings(px_get(search_url, verbose = verbose))

    if (is.null(raw) || length(raw) == 0) next

    # Check if the response looks like search results (has $id + $title or $path)
    first <- raw[[1]]
    if (is.null(first$id) && is.null(first$title)) next

    for (item in raw) {
      # Build full table path from db + path + id
      item_path <- item$path %||% ""
      item_path <- gsub("^/+|/+$", "", item_path)
      full_id <- if (nzchar(item_path)) {
        paste(db, item_path, item$id, sep = "/")
      } else {
        paste(db, item$id, sep = "/")
      }

      tbl <- tibble::tibble(
        id = full_id,
        title = item$title %||% NA_character_,
        description = NA_character_,
        category = NA_character_,
        updated = item$published %||% NA_character_,
        first_period = NA_character_,
        last_period = NA_character_,
        time_unit = NA_character_,
        variables = list(character()),
        subject_code = NA_character_,
        subject_path = item_path,
        source = api$alias %||% api$base_url,
        discontinued = FALSE
      )
      all_tables <- c(all_tables, list(tbl))
    }
  }

  if (length(all_tables) == 0) return(NULL)

  result <- dplyr::bind_rows(all_tables)

  if (!is.null(max_results) && nrow(result) > max_results) {
    result <- result[seq_len(max_results), ]
  }

  result
}

#' Recursively collect tables from v1 level hierarchy
#' @noRd
collect_tables_v1 <- function(items, base_url, query, verbose,
                               depth = 0, max_depth = 5, path_prefix = "",
                               max_results = Inf, deadline = NULL) {
  if (depth > max_depth) return(list())

  tables <- list()

  for (item in items) {
    # Early termination once we have enough results or time is up
    if (length(tables) >= max_results) break
    if (!is.null(deadline) && Sys.time() >= deadline) break

    item_type <- item$type %||% NA_character_

    # Detect non-standard root items: dbid entries or items with only text
    # (no type field). These are folder-like — recurse into them.
    is_dbid <- !is.null(item$dbid) && is.na(item_type)
    is_untyped_folder <- is.na(item_type) && !is_dbid && !is.null(item$text) && is.null(item$id)

    if (identical(item_type, "t")) {
      # It's a table — build full path ID
      full_id <- if (nzchar(path_prefix)) {
        paste0(path_prefix, "/", item$id)
      } else {
        item$id %||% NA_character_
      }

      tbl <- tibble::tibble(
        id = full_id,
        title = item$text %||% NA_character_,
        description = NA_character_,
        category = NA_character_,
        updated = item$updated %||% NA_character_,
        first_period = NA_character_,
        last_period = NA_character_,
        time_unit = NA_character_,
        variables = list(character()),
        subject_code = NA_character_,
        subject_path = NA_character_,
        source = NA_character_,
        discontinued = FALSE
      )

      if (!is.null(query)) {
        match <- grepl(query, tbl$title, ignore.case = TRUE) ||
          grepl(query, tbl$id, ignore.case = TRUE)
        if (!match) next
      }

      tables <- c(tables, list(tbl))

    } else if (identical(item_type, "l") || is_dbid || is_untyped_folder) {
      # It's a folder (level, dbid entry, or untyped root item) — recurse
      folder_id <- item$dbid %||% item$id %||% ""
      child_url <- px_url(base_url, folder_id)
      child_path <- if (nzchar(path_prefix) && nzchar(folder_id)) {
        paste0(path_prefix, "/", folder_id)
      } else if (nzchar(folder_id)) {
        folder_id
      } else {
        path_prefix
      }

      children <- px_get(child_url, verbose = verbose)
      if (!is.null(children)) {
        remaining <- max_results - length(tables)
        sub_tables <- collect_tables_v1(
          children, child_url, query, verbose,
          depth + 1, max_depth, path_prefix = child_path,
          max_results = remaining, deadline = deadline
        )
        tables <- c(tables, sub_tables)
      }
    }
  }

  tables
}

#' @noRd
parse_table_v1 <- function(raw, table_id, api) {
  # v1 metadata response contains a list of variables
  var_names <- if (is.list(raw)) {
    vapply(raw$variables %||% list(), function(v) v$code %||% "", character(1))
  } else {
    character()
  }

  tibble::tibble(
    id = table_id,
    title = raw$title %||% NA_character_,
    description = NA_character_,
    category = NA_character_,
    updated = raw$updated %||% NA_character_,
    first_period = NA_character_,
    last_period = NA_character_,
    time_unit = NA_character_,
    variables = list(var_names),
    subject_code = NA_character_,
    subject_path = NA_character_,
    source = api$alias %||% api$base_url,
    discontinued = FALSE
  )
}

#' Client-side search on a table tibble
#'
#' Filter an already-fetched table tibble by regex. Complements
#' `get_tables(query = ...)` which does server-side search. Use this for
#' further refinement on cached results.
#'
#' @param table_df A tibble returned by [get_tables()].
#' @param query Character vector of search terms (combined with OR).
#' @param column Column names to search. `NULL` searches all character columns.
#' @return A filtered tibble.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   tables <- get_tables(scb, query = "population")
#'
#'   # Further filter by regex
#'   tables |> table_search("municipality")
#' }}
table_search <- function(table_df, query, column = NULL) {
  api <- attr(table_df, "px_api")
  result <- entity_search(table_df, query, column, caller = "table_search")
  attr(result, "px_api") <- api
  result
}

#' Print human-readable table summaries
#'
#' @param table_df A tibble returned by [get_tables()].
#' @param max_n Maximum number of tables to describe.
#' @param format Output format: `"inline"` (console) or `"md"` (markdown).
#' @param heading_level Heading level for output.
#' @return `table_df` invisibly (for piping).
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   get_tables(scb, query = "population") |> table_describe(max_n = 3)
#' }}
table_describe <- function(table_df, max_n = 5, format = "inline",
                           heading_level = 2) {
  if (is.null(table_df) || nrow(table_df) == 0) {
    warn("No tables to describe.")
    return(invisible(table_df))
  }

  n <- min(max_n, nrow(table_df))

  for (i in seq_len(n)) {
    row <- table_df[i, ]
    cat(format_heading(
      paste0(row$id, ": ", row$title),
      level = heading_level,
      format = format
    ), "\n")

    # Time range display (columns may be missing after table_minimize)
    has_period <- "first_period" %in% names(row) && "last_period" %in% names(row)
    time_range <- if (has_period && !is.na(row$first_period) && !is.na(row$last_period)) {
      unit_label <- if ("time_unit" %in% names(row) && !is.na(row$time_unit)) {
        paste0(" (", row$time_unit, ")")
      } else {
        ""
      }
      paste0(row$first_period, " \u2013 ", row$last_period, unit_label)
    } else {
      NULL
    }

    # Helper to safely get a column value (may be missing after minimize)
    col <- function(name) {
      if (name %in% names(row)) row[[name]] else NA
    }

    # Enriched columns (present after table_enrich())
    is_enriched <- "contents" %in% names(row)

    # Subject: prefer enriched subject_area, fall back to subject_path
    subject <- if (is_enriched && !is.na(col("subject_area"))) {
      col("subject_area")
    } else {
      col("subject_path")
    }

    fields <- list(
      format_field("Contents", if (is_enriched && !is.na(col("contents"))) col("contents") else NULL),
      format_field("Description", if (!is.na(col("description")) && col("description") != "") col("description") else NULL),
      format_field("Subject", if (!is.na(subject)) subject else NULL),
      format_field("Period", time_range),
      format_field("Updated", if (!is.na(col("updated"))) col("updated") else NULL),
      format_field("Category", if (!is.na(col("category"))) col("category") else NULL),
      format_field("Variables", if ("variables" %in% names(row)) truncate_list(row$variables[[1]], 10) else NULL),
      format_field("Source", if (!is.na(col("source"))) col("source") else NULL),
      format_field("Contact", if (is_enriched && !is.na(col("contact"))) col("contact") else NULL),
      format_field("Official statistics", if (is_enriched && isTRUE(col("official_statistics"))) "Yes" else NULL),
      format_field("Discontinued", if (isTRUE(col("discontinued"))) "Yes" else NULL)
    )
    fields <- fields[!vapply(fields, is.null, logical(1))]
    cat(paste(fields, collapse = "\n"), "\n")

    # Notes (enriched only)
    if (is_enriched && "notes" %in% names(row)) {
      notes <- row$notes[[1]]
      if (length(notes) > 0) {
        cat("  Notes:\n")
        for (note in notes) {
          wrapped <- strwrap(note, width = 76, prefix = "    ")
          cat(paste(wrapped, collapse = "\n"), "\n")
        }
      }
    }
    cat("\n")
  }

  if (nrow(table_df) > max_n) {
    cat(paste0("... and ", nrow(table_df) - max_n, " more table(s).\n"))
  }

  invisible(table_df)
}

#' Enrich a table tibble with full metadata
#'
#' Fetches the metadata endpoint for each table and adds columns with
#' notes, contents description, contact information, and more. This is
#' an extra API call per table, so it's separated from [get_tables()] to
#' give users control over when the cost is incurred.
#'
#' When `cache_location` points at a SQLite file (or `nxt_handle` from the
#' nordstatExtras package) the cache is **per table** rather than per
#' enrich call. That gives three properties you don't get from the legacy
#' `.rds` path: (1) enrichment results are reused across any
#' `table_enrich()` call that touches the same `table_id`; (2) a long
#' enrich run can be interrupted and resumes from where it left off; and
#' (3) with `async = TRUE`, the call returns immediately with whatever is
#' already cached and keeps fetching in the background.
#'
#' @param table_df A tibble returned by [get_tables()].
#' @param api A `<px_api>` object. Optional — if omitted, the API connection
#'   stored by [get_tables()] is used automatically.
#' @param cache Logical. If `TRUE`, stores the enriched result locally and
#'   loads it on subsequent calls instead of re-fetching metadata.
#' @param cache_location Either a directory path (legacy `.rds` cache), a
#'   path to a `.sqlite` file, or an `nxt_handle` from
#'   `nordstatExtras::nxt_open()`. Defaults to [pixieweb_cache_dir()].
#' @param async Logical. When `TRUE` (and `cache_location` is a SQLite
#'   backend), missing rows are fetched in a background `mirai` task;
#'   `table_enrich()` returns immediately with the currently-cached subset
#'   plus NA placeholders for pending rows. The return value carries
#'   `attr(x, "nxt_pending_ids")` (IDs still fetching) and
#'   `attr(x, "nxt_promise")` (a `mirai` task the caller can await or
#'   bridge to `promises::then()`). Ignored when the backend is not
#'   SQLite or when `cache = FALSE`.
#' @param verbose Print request details.
#' @return The input tibble with additional columns: `notes`, `contents`,
#'   `subject_area`, `official_statistics`, `contact`.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'
#'   # API is picked up automatically from the tibble
#'   get_tables(scb, query = "population", max_results = 5) |>
#'     table_enrich() |>
#'     table_describe()
#'
#'   # Cache enriched results for offline use (legacy .rds path)
#'   get_tables(scb, query = "population", cache = TRUE) |>
#'     table_enrich(cache = TRUE)
#'
#'   # Per-table cache in a shared SQLite file
#'   handle <- nordstatExtras::nxt_open("cache.sqlite")
#'   get_tables(scb, query = "population", cache = TRUE,
#'              cache_location = handle) |>
#'     table_enrich(cache = TRUE, cache_location = handle)
#' }}
table_enrich <- function(table_df, api = NULL, cache = FALSE,
                         cache_location = pixieweb_cache_dir,
                         async = FALSE, verbose = FALSE) {
  if (is.null(api)) {
    api <- attr(table_df, "px_api")
  }
  if (is.null(api) || !inherits(api, "px_api")) {
    abort(c(
      "No API connection found.",
      i = "Either pipe from get_tables() or pass `api` explicitly."
    ))
  }
  if (is.null(table_df) || nrow(table_df) == 0) {
    warn("No tables to enrich.")
    return(table_df)
  }

  backend_is_sqlite <- isTRUE(cache) && !is.null(cache_location) &&
    requireNamespace("nordstatExtras", quietly = TRUE) &&
    nordstatExtras::nxt_is_backend(cache_location)

  if (!backend_is_sqlite) {
    # Legacy .rds whole-tibble path — unchanged behavior.
    return(table_enrich_legacy(table_df, api, cache, cache_location, verbose))
  }

  # v1 metadata is empty — just stamp the empty columns and return. The
  # per-table cache path isn't useful when there's nothing to fetch.
  if (api$version != "v2") {
    return(enrich_v1_empty(table_df, api))
  }

  n <- nrow(table_df)
  ids <- table_df$id
  alias <- api$alias %||% "default"
  lang <- api$lang %||% "default"

  make_ch <- function(tid) {
    nordstatExtras::nxt_cache_handler(
      source = "pixieweb", entity = "enriched_row",
      cache = TRUE, cache_location = cache_location,
      kind = "metadata",
      key_params = list(alias = alias, lang = lang, table_id = tid)
    )
  }

  # Classify rows into cached / missing
  cached_rows <- vector("list", n)
  missing_ids <- character(0)
  for (i in seq_len(n)) {
    ch <- make_ch(ids[i])
    if (ch("discover")) {
      cached_rows[[i]] <- ch("load")
    } else {
      missing_ids <- c(missing_ids, ids[i])
    }
  }

  if (length(missing_ids) == 0) {
    return(assemble_enriched(table_df, cached_rows, api))
  }

  if (isTRUE(async)) {
    # Resolve to an explicit path so the background worker can re-open
    # the cache with its own connection.
    path <- if (inherits(cache_location, "nxt_handle")) {
      cache_location$path
    } else if (is.function(cache_location)) {
      cache_location()
    } else {
      cache_location
    }

    task <- launch_background_enrich(api, missing_ids, path)
    partial <- assemble_enriched(table_df, cached_rows, api,
                                 pending_ids = missing_ids)
    attr(partial, "nxt_pending_ids") <- missing_ids
    attr(partial, "nxt_promise") <- task
    return(partial)
  }

  # Sync path — fetch missing inline, cache per table as we go
  max_calls <- api$config$max_calls %||% 30
  time_window <- api$config$time_window %||% 10
  delay <- time_window / max_calls

  if (length(missing_ids) > 1) {
    cli::cli_alert_info("Enriching {length(missing_ids)} table(s) with metadata.")
    cli::cli_progress_bar("Fetching metadata",
                          total = length(missing_ids),
                          .envir = environment())
  }

  for (i in seq_along(missing_ids)) {
    tid <- missing_ids[i]
    row <- fetch_single_enriched(api, tid, verbose)
    ch <- make_ch(tid)
    ch("store", row)
    cached_rows[[match(tid, ids)]] <- row

    if (length(missing_ids) > 1) {
      cli::cli_progress_update(.envir = environment())
      if (i < length(missing_ids)) Sys.sleep(delay)
    }
  }
  if (length(missing_ids) > 1) cli::cli_progress_done(.envir = environment())

  assemble_enriched(table_df, cached_rows, api)
}

#' Fetch a single enriched-row tibble for one table_id.
#'
#' Extracted from the original `table_enrich()` loop body so both the sync
#' path and the mirai background path can call it. Returns a one-row tibble
#' with the enrichment columns (notes, contents, subject_area,
#' official_statistics, contact). On API failure returns a row of NA
#' placeholders rather than aborting — the caller can decide what to do
#' with a partial enrich run.
#'
#' @keywords internal
#' @export
fetch_single_enriched <- function(api, tid, verbose = FALSE) {
  raw <- fetch_table_metadata(api, tid, verbose)

  if (is.null(raw)) {
    return(tibble::tibble(
      notes = list(character()),
      contents = NA_character_,
      subject_area = NA_character_,
      official_statistics = NA,
      contact = NA_character_
    ))
  }

  px <- raw$extension$px %||% list()
  contacts <- raw$extension$contact %||% list()
  contact_str <- if (length(contacts) > 0) {
    paste0(
      contacts[[1]]$name %||% "",
      if (!is.null(contacts[[1]]$organization)) {
        paste0(", ", contacts[[1]]$organization)
      } else {
        ""
      }
    )
  } else {
    NA_character_
  }

  tibble::tibble(
    notes = list(raw$note %||% character()),
    contents = px$contents %||% NA_character_,
    subject_area = px$`subject-area` %||% NA_character_,
    official_statistics = px$`official-statistics` %||% NA,
    contact = contact_str
  )
}

# Bind per-row enrichment results onto the input table_df and re-attach the
# px_api attribute. If `pending_ids` is non-empty, missing rows get NA
# placeholders in the enrichment columns.
assemble_enriched <- function(table_df, cached_rows, api,
                              pending_ids = character(0)) {
  n <- nrow(table_df)
  notes_col <- vector("list", n)
  contents_col <- character(n)
  subject_area_col <- character(n)
  official_col <- logical(n)
  contact_col <- character(n)

  for (i in seq_len(n)) {
    row <- cached_rows[[i]]
    if (is.null(row)) {
      notes_col[[i]] <- character()
      contents_col[i] <- NA_character_
      subject_area_col[i] <- NA_character_
      official_col[i] <- NA
      contact_col[i] <- NA_character_
    } else {
      notes_col[[i]] <- row$notes[[1]]
      contents_col[i] <- row$contents
      subject_area_col[i] <- row$subject_area
      official_col[i] <- row$official_statistics
      contact_col[i] <- row$contact
    }
  }

  table_df$notes <- notes_col
  table_df$contents <- contents_col
  table_df$subject_area <- subject_area_col
  table_df$official_statistics <- official_col
  table_df$contact <- contact_col
  attr(table_df, "px_api") <- api
  table_df
}

# Fire off a mirai background task that loops over `tids`, fetching each
# table's enriched row and writing to the shared SQLite file. Rate limit is
# respected inside the worker via Sys.sleep. Returns the mirai task object
# so the caller can attach as `attr(x, "nxt_promise")` and the app can
# bridge to promises::then() or call mirai::call_mirai() to block.
launch_background_enrich <- function(api, tids, path) {
  if (!requireNamespace("mirai", quietly = TRUE)) {
    abort(c(
      "table_enrich(async = TRUE) requires the mirai package.",
      i = "Install it with install.packages('mirai')."
    ))
  }

  max_calls <- api$config$max_calls %||% 30
  time_window <- api$config$time_window %||% 10
  delay <- time_window / max_calls
  alias <- api$alias %||% "default"
  lang <- api$lang %||% "default"

  mirai::mirai(
    enrich_worker(api, tids, path, alias, lang, delay),
    enrich_worker = enrich_worker,
    api = api, tids = tids, path = path,
    alias = alias, lang = lang, delay = delay
  )
}

# Worker function for the mirai background enrich. Written as a standalone
# function so mirai can serialize it cleanly (no package-scope closure
# captures). Inside the worker it loads the two package namespaces and
# looks up the actual fetch function via getFromNamespace().
enrich_worker <- function(api, tids, path, alias, lang, delay) {
  loadNamespace("pixieweb")
  loadNamespace("nordstatExtras")

  fetch <- utils::getFromNamespace("fetch_single_enriched", "pixieweb")

  h <- nordstatExtras::nxt_open(path)
  on.exit(nordstatExtras::nxt_close(h), add = TRUE)

  for (i in seq_along(tids)) {
    tid <- tids[i]
    row <- fetch(api, tid, FALSE)
    ch <- nordstatExtras::nxt_cache_handler(
      source = "pixieweb", entity = "enriched_row",
      cache = TRUE, cache_location = h,
      kind = "metadata",
      key_params = list(alias = alias, lang = lang, table_id = tid)
    )
    ch("store", row)
    if (i < length(tids)) Sys.sleep(delay)
  }
  length(tids)
}

# The original .rds-backed whole-tibble enrich path. Kept verbatim from
# before the SQLite integration so users who pass a directory path instead
# of a sqlite file still get the exact behavior they had.
table_enrich_legacy <- function(table_df, api, cache, cache_location,
                                verbose = FALSE) {
  ch <- cache_handler("enriched", cache, cache_location, key_params = list(
    alias = api$alias %||% "default",
    lang = api$lang %||% "default",
    ids = digest_ids(table_df$id)
  ))
  if (ch("discover")) return(ch("load"))

  if (api$version != "v2") {
    result <- enrich_v1_empty(table_df, api)
    return(ch("store", result))
  }

  n <- nrow(table_df)
  max_calls <- api$config$max_calls %||% 30
  time_window <- api$config$time_window %||% 10
  delay <- time_window / max_calls

  if (n > 1) {
    cli::cli_alert_info("Enriching {n} table(s) with metadata.")
    cli::cli_progress_bar("Fetching metadata", total = n,
                          .envir = environment())
  }

  notes_col <- vector("list", n)
  contents_col <- character(n)
  subject_area_col <- character(n)
  official_col <- logical(n)
  contact_col <- character(n)

  for (i in seq_len(n)) {
    tid <- table_df$id[i]
    row <- fetch_single_enriched(api, tid, verbose)
    notes_col[[i]] <- row$notes[[1]]
    contents_col[i] <- row$contents
    subject_area_col[i] <- row$subject_area
    official_col[i] <- row$official_statistics
    contact_col[i] <- row$contact

    if (n > 1) {
      cli::cli_progress_update(.envir = environment())
      if (i < n) Sys.sleep(delay)
    }
  }
  if (n > 1) cli::cli_progress_done(.envir = environment())

  table_df$notes <- notes_col
  table_df$contents <- contents_col
  table_df$subject_area <- subject_area_col
  table_df$official_statistics <- official_col
  table_df$contact <- contact_col
  attr(table_df, "px_api") <- api

  ch("store", table_df)
}

# Produce an enriched tibble with empty columns for v1 APIs (which don't
# expose enrichment metadata at all). Centralized so both the SQLite and
# .rds paths warn + populate the same way.
enrich_v1_empty <- function(table_df, api) {
  hints <- "Columns are added for compatibility but will be empty."
  if (v1_api_has_v2(api)) {
    hints <- c(hints, paste0(
      "For richer metadata, use the v2 API: ",
      "`px_api(\"", api$alias, "\", version = \"v2\")`"
    ))
  }
  warn(c(
    "PX-Web v1 metadata does not include enrichment fields (notes, contents, contact, etc.).",
    stats::setNames(hints, rep("i", length(hints)))
  ))
  n <- nrow(table_df)
  table_df$notes <- vector("list", n)
  for (i in seq_len(n)) table_df$notes[[i]] <- character()
  table_df$contents <- NA_character_
  table_df$subject_area <- NA_character_
  table_df$official_statistics <- NA
  table_df$contact <- NA_character_
  attr(table_df, "px_api") <- api
  table_df
}

#' Create a short stable hash from a vector of table IDs (for cache keys)
#' @noRd
digest_ids <- function(ids) {
  # Create a short, stable, filesystem-safe key from table IDs
  key <- paste(sort(ids), collapse = "_")
  # Truncate if very long, but keep it readable
  if (nchar(key) > 60) {
    key <- paste0(substr(key, 1, 50), "_n", length(ids))
  }
  key
}

#' Fetch raw metadata for a single table
#' @noRd
fetch_table_metadata <- function(api, table_id, verbose = FALSE) {
  if (api$version == "v2") {
    url <- api_url(api, "tables", table_id, "metadata")
    px_get(url, verbose = verbose)
  } else {
    url <- px_url(api_base_url(api), table_id)
    px_get(url, verbose = verbose)
  }
}

#' Remove monotonous columns from a table tibble
#'
#' @param table_df A tibble returned by [get_tables()].
#' @param remove_monotonous_data Remove columns where all values are identical.
#' @return A tibble.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   get_tables(scb, query = "population") |> table_minimize()
#' }}
table_minimize <- function(table_df, remove_monotonous_data = TRUE) {
  api <- attr(table_df, "px_api")
  result <- remove_monotonous(table_df, remove_monotonous_data)
  attr(result, "px_api") <- api
  result
}

#' Extract table IDs from a table tibble
#'
#' @param table_df A tibble returned by [get_tables()].
#' @return A character vector of table IDs.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   get_tables(scb, query = "population") |> table_extract_ids()
#' }}
table_extract_ids <- function(table_df) {
  if (is.null(table_df) || nrow(table_df) == 0) return(character())
  table_df$id
}
