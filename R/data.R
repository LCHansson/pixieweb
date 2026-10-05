#' Fetch data from a PX-Web table
#'
#' The core function for downloading statistical data. Variable selections
#' are passed as named arguments via `...`, or via a prepared query object
#' from [prepare_query()].
#'
#' @param api A `<px_api>` object.
#' @param table_id A single table ID (character). Vectors are not supported;
#'   use `purrr::map()` + `dplyr::bind_rows()` for multiple tables.
#'   Ignored when `query` is provided.
#' @param ... Variable selections as named arguments. Each name is a variable
#'   code, each value is one of:
#'   - A character vector of specific value codes (item selection)
#'   - `"*"` for all values
#'   - A [px_selections] helper: `px_all()`, `px_top()`, `px_bottom()`,
#'     `px_from()`, `px_to()`, `px_range()`
#'   - Omitted variables are eliminated if the API allows it
#'
#'   Only variables whose metadata reports `elimination = TRUE` may be
#'   omitted on a v2 API. Omitting a mandatory one (including `ContentsCode`
#'   and the time variable) is an error naming the variables to add — the
#'   server's own HTTP 400 does not say which variable is missing. Use
#'   `get_variables()` to see the flag, or let [prepare_query()] fill the
#'   mandatory variables for you.
#'   Ignored when `query` is provided.
#' @param query A `<px_query>` object from [prepare_query()]. When provided,
#'   `table_id`, `...`, and `.codelist` are taken from the query object.
#' @param .codelist Named list of codelist overrides
#'   (e.g. `list(Region = "agg_RegionLan")`).
#' @param .output `"long"` (default, tidy) or `"wide"` (pivot content variables).
#' @param .comments Include footnotes/comments as an attribute.
#' @param simplify Add human-readable text label columns alongside codes.
#' @param auto_chunk Automatically split large queries that exceed the cell
#'   limit into multiple requests. When `TRUE` (default), the variable
#'   with the most values is split into batches, each request staying under
#'   the limit. A progress bar is shown. Set to `FALSE` to error instead.
#' @param max_results Override the API's cell limit. When set, this value is
#'   used instead of the limit reported by the API's config endpoint. Useful
#'   for keeping result size manageable or for testing chunking behavior.
#' @param cache Logical. If `TRUE` and `cache_location` points at a SQLite
#'   file (or an `nxt_handle` from nordstatExtras), the data is cached at
#'   cell granularity in that database. Supports concurrent multi-process
#'   read/write and cross-query cell reuse. Requires `nordstatExtras`.
#' @param cache_location Either a path to a `.sqlite` file or an `nxt_handle`
#'   from `nordstatExtras::nxt_open()`. Ignored unless `cache = TRUE`.
#' @param verbose Print request details.
#' @param .status Keep the source's status symbol for cells without a value.
#'   PX-Web marks a cell it withholds or cannot give with a symbol such as
#'   `".."` (not available or suppressed) or `"."` (not applicable); by
#'   default such a cell is simply `NA` in `value`, indistinguishable from a
#'   cell the response does not carry. With `.status = TRUE` the result gains
#'   a character column `status`, placed after `value`: the symbol exactly as
#'   the source sent it, and `NA` where the cell has a value (or no symbol).
#'   Default `FALSE` leaves the result unchanged. Only for `.output = "long"`;
#'   the SQLite cell cache is bypassed, since it stores numeric cells only.
#' @return A tibble of data. See Details for column structure.
#'
#' @details
#' When `simplify = TRUE` and `.output = "long"` (defaults), columns are:
#' - `table_id`: back-reference to the source table
#' - One pair per dimension: `{code}` (raw code) + `{code}_text` (label)
#' - `value`: the numeric measurement
#'
#' When `simplify = FALSE`, only raw codes and `value` are returned.
#'
#' When `.output = "wide"`, content variables are pivoted into separate columns.
#'
#' A v1 API returns the values of a contents variable as separate content
#' columns, and they are folded into a column named `ContentsCode` even when
#' the table metadata calls the variable something else (as in the
#' `*_Cont.px` tables of Energimyndigheten). When that happens the result
#' carries the name the source uses in `attr(x, "px_contents_variable")`.
#'
#' When `auto_chunk = TRUE` and the query would exceed the API's cell limit,
#' `get_data()` automatically splits the request. It picks the variable with
#' the most values and batches its values so each request fits under the limit.
#' Requests are paced to respect the API's rate limit.
#'
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'
#'   # Fetch with explicit selections. ContentsCode and Tid are mandatory
#'   # in this table (elimination = FALSE); Region is not.
#'   get_data(scb, "TAB638",
#'     Region = c("0180", "1480"),
#'     ContentsCode = "*",
#'     Tid = px_top(5)
#'   )
#'
#'   # Fetch from a prepared query
#'   q <- prepare_query(scb, "TAB638", Region = c("0180"))
#'   get_data(scb, query = q)
#' }}
get_data <- function(api,
                     table_id,
                     ...,
                     query = NULL,
                     .codelist = NULL,
                     .output = "long",
                     .comments = FALSE,
                     simplify = TRUE,
                     auto_chunk = TRUE,
                     max_results = NULL,
                     cache = FALSE,
                     cache_location = NULL,
                     verbose = FALSE,
                     .status = FALSE) {
  check_px_api(api)
  stopifnot(.output %in% c("long", "wide"))
  stopifnot(is.logical(.status), length(.status) == 1, !is.na(.status))
  if (.status && .output != "long") {
    abort(c(
      "`.status = TRUE` requires `.output = \"long\"`.",
      i = "Pivot the long result yourself if you need status symbols in a wide table."
    ))
  }

  # Extract table_id, selections, and codelist from query or arguments
  if (inherits(query, "px_query")) {
    table_id <- query$table_id
    .codelist <- query$.codelist
    selections <- Filter(Negate(is.null), query$selections)
  } else {
    if (missing(table_id)) {
      abort("Must provide either `table_id` or `query`.")
    }

    # Catch common mistake: passing a px_query as table_id positionally
    if (inherits(table_id, "px_query")) {
      abort(c(
        "A <px_query> object was passed as `table_id`.",
        i = "Use the named argument instead: `get_data(api, query = <your query>)`"
      ))
    }

    # Guard against multiple table IDs
    if (length(table_id) > 1) {
      ids_display <- if (length(table_id) > 5) {
        paste0(
          paste(utils::head(table_id, 5), collapse = '", "'),
          '", ...'
        )
      } else {
        paste(table_id, collapse = '", "')
      }

      abort(c(
        "get_data() accepts a single table ID.",
        i = "For multiple tables, use:",
        i = paste0(
          'purrr::map(c("', ids_display, '"), ',
          "\\(id) get_data(api, id, ...)) |> dplyr::bind_rows()"
        )
      ))
    }

    stopifnot(is.character(table_id), length(table_id) == 1)
    selections <- list(...)
  }

  # SQLite-backed cell cache via nordstatExtras. Key is the full selection
  # dict + output/simplify options + api alias.
  nxt_ch <- NULL
  if (isTRUE(cache) && !.status && !is.null(cache_location) &&
      requireNamespace("nordstatExtras", quietly = TRUE) &&
      nordstatExtras::nxt_is_backend(cache_location)) {
    alias <- api$alias %||% "default"
    nxt_ch <- nordstatExtras::nxt_cache_handler(
      source         = "pixieweb",
      entity         = "data",
      cache          = TRUE,
      cache_location = cache_location,
      key_params     = c(
        list(alias = alias, table_id = table_id,
             .output = .output, simplify = simplify,
             .codelist_keys = paste(names(.codelist), collapse = ","),
             .codelist_vals = paste(unlist(.codelist), collapse = ",")),
        selections
      ),
      normalize_extra = list(alias = alias)
    )
    if (nxt_ch("discover")) return(nxt_ch("load"))
  }

  # Check if chunking is needed
  max_cells <- max_results %||% api$config$max_cells %||% 100000
  # Use variable metadata from query object if available, otherwise fetch it
  # once and reuse it for both the mandatory-variable check and the chunk plan.
  vars_meta <- if (inherits(query, "px_query")) query$variables else NULL
  if (is.null(vars_meta)) {
    vars_meta <- get_variables(api, table_id, verbose = verbose)
  }

  check_mandatory_selections(selections, vars_meta, table_id, api)

  chunk_info <- if (is.null(vars_meta) || nrow(vars_meta) == 0) {
    list(needs_chunking = FALSE)
  } else {
    check_query_size(selections, api, table_id, max_cells, verbose,
                     vars = vars_meta)
  }

  if (chunk_info$needs_chunking) {
    if (!auto_chunk) {
      abort(c(
        paste0(
          "Query would request ~", chunk_info$estimated_cells,
          " cells, exceeding the API limit of ", max_cells, "."
        ),
        i = "Set `auto_chunk = TRUE` to automatically split this into multiple requests.",
        i = paste0(
          "The query would be split into ~", chunk_info$n_chunks,
          " requests along variable '", chunk_info$split_var, "'."
        )
      ))
    }

    result <- execute_chunked(
      api, table_id, selections, .codelist,
      chunk_info, simplify, verbose, status = .status
    )
  } else {
    # Single request
    q <- do.call(
      compose_data_query,
      c(list(api = api, table_id = table_id, .codelist = .codelist), selections)
    )
    raw <- execute_query(api, q$url, q$body, verbose = verbose)

    if (is.null(raw)) return(NULL)

    if (api$version == "v2") {
      result <- parse_data_v2(raw, table_id, simplify, status = .status)
    } else {
      result <- parse_data_v1(raw, table_id, simplify, status = .status)
    }
  }

  if (is.null(result)) return(NULL)

  if (api$version != "v2") {
    result <- label_v1_result(result, vars_meta, names(selections), simplify)
  }

  # Handle wide output
  if (.output == "wide") {
    result <- pivot_data_wide(result)
  }

  # Store metadata for px_cite()
  attr(result, "px_source") <- list(
    api = api$description,
    table_id = table_id,
    fetched = Sys.time()
  )

  if (!is.null(nxt_ch) && !is.null(result) && nrow(result) > 0) {
    nxt_ch("store", result)
  }

  result
}

#' Fail early when a mandatory v2 variable has no selection
#'
#' PX-Web v2 (verified against SCB, 2026-08-20) requires an explicit
#' selection for every variable whose metadata reports
#' `extension.elimination = FALSE` — including `ContentsCode` and the time
#' variable. Only variables with `elimination = TRUE` may be omitted; those
#' the server sums away by itself.
#'
#' When a mandatory variable is missing, the server answers HTTP 400 with
#' `{"title": "Missing selection for mandantory variable"}` and does **not**
#' name the variable, so `get_data()` used to surface an unactionable warning
#' and return `NULL`. Check client-side instead, where the metadata is
#' already in hand, and name both the variables and the remedy.
#'
#' v1 APIs are deliberately excluded: PX-Web v1 expands omitted
#' non-eliminable variables instead of rejecting the request (verified
#' against Konjunkturinstitutet's `KonjBar/indikatorer/Indikatorm.px`,
#' where selecting only the time variable returns all 84 indicators).
#'
#' @param selections Named list of user selections.
#' @param vars Variable metadata tibble from `get_variables()`, or NULL.
#' @param table_id Table id, used in the message.
#' @param api A `<px_api>` object.
#' @noRd
check_mandatory_selections <- function(selections, vars, table_id, api) {
  if (api$version != "v2") return(invisible(NULL))
  if (is.null(vars) || nrow(vars) == 0) return(invisible(NULL))
  if (!"elimination" %in% names(vars)) return(invisible(NULL))

  mandatory <- vars$code[!vapply(vars$elimination, isTRUE, logical(1))]
  selected <- names(selections)[
    !vapply(selections, is.null, logical(1))
  ]
  missing_vars <- setdiff(mandatory, selected)

  if (length(missing_vars) == 0) return(invisible(NULL))

  examples <- vapply(missing_vars, function(code) {
    row <- vars[vars$code == code, ][1, ]
    if (isTRUE(row$time)) {
      paste0(code, " = px_top(5)")
    } else {
      paste0(code, ' = "*"')
    }
  }, character(1))

  eliminable <- vars$code[vapply(vars$elimination, isTRUE, logical(1))]

  msg <- c(
    paste0(
      "Missing selection for mandatory variable",
      if (length(missing_vars) > 1) "s" else "",
      " in table '", table_id, "': ",
      paste0("`", missing_vars, "`", collapse = ", "), "."
    ),
    x = paste0(
      "PX-Web v2 rejects a data query that omits a variable whose metadata ",
      "has `elimination = FALSE`, and its HTTP 400 does not say which one."
    ),
    i = paste0(
      "Add a selection, e.g. `get_data(api, \"", table_id, "\", ",
      paste(examples, collapse = ", "), ", ...)`."
    )
  )

  if (length(eliminable) > 0) {
    msg <- c(msg, i = paste0(
      "Variable", if (length(eliminable) > 1) "s" else "", " ",
      paste0("`", eliminable, "`", collapse = ", "),
      " may be omitted (elimination = TRUE)."
    ))
  }

  msg <- c(msg, i = paste0(
    "`get_variables(api, \"", table_id, "\")` lists every variable and its ",
    "`elimination` flag; `prepare_query()` fills the mandatory ones for you."
  ))

  abort(msg)
}

#' Check if a query needs chunking and compute the split plan
#' @noRd
check_query_size <- function(selections, api, table_id, max_cells, verbose,
                             vars = NULL) {
  # We need variable metadata to know how many values "*" or px_top(N) expands to
  if (is.null(vars)) {
    vars <- get_variables(api, table_id, verbose = verbose)
  }

  if (is.null(vars) || nrow(vars) == 0) {
    return(list(needs_chunking = FALSE))
  }

  # Resolve each selection to its effective value count and actual values
  var_sizes <- list()
  var_values <- list()

  # v1 metadata stores the per-variable value tibble with list-columns
  # (each code is a length-1 list element); v2 stores plain character
  # vectors. Normalize to character so chunk batches are always valid
  # selections downstream (resolve_selection_*() rejects bare lists).
  codes_of <- function(v) as.character(unlist(v$values[[1]]$code))

  for (i in seq_len(nrow(vars))) {
    v <- vars[i, ]
    code <- v$code
    sel <- selections[[code]]

    if (is.null(sel)) {
      # Eliminated. Note: assigning NULL into var_values would *remove*
      # the element, so only var_sizes gets an entry here.
      var_sizes[[code]] <- 1
    } else if (is.character(sel) && length(sel) == 1 && sel == "*") {
      var_sizes[[code]] <- v$n_values
      var_values[[code]] <- codes_of(v)
    } else if (is.character(sel)) {
      var_sizes[[code]] <- length(sel)
      var_values[[code]] <- sel
    } else if (inherits(sel, "px_selection")) {
      # Resolve the helper to the codes the server will actually return, so
      # the cell estimate is not inflated (px_range("2015") is not "all
      # periods") and a split along this variable never asks for values
      # outside the selection.
      picked <- selection_codes(sel, codes_of(v), isTRUE(v[["time"]]))
      var_sizes[[code]] <- length(picked)
      var_values[[code]] <- picked
    } else {
      var_sizes[[code]] <- v$n_values
      var_values[[code]] <- codes_of(v)
    }
  }

  estimated_cells <- prod(unlist(var_sizes))

  if (estimated_cells <= max_cells) {
    return(list(needs_chunking = FALSE, estimated_cells = estimated_cells))
  }

  # Find the variable to split on: the one with the most values
  # (excluding eliminated variables, which have no var_values entry --
  # indexing by name avoids the misaligned logical index that a
  # NULL-removed element would cause)
  splittable <- var_sizes[names(var_values)]
  split_var <- names(which.max(splittable))
  split_values <- var_values[[split_var]]

  # How many values can we include per chunk?
  cells_per_value <- estimated_cells / var_sizes[[split_var]]
  values_per_chunk <- max(1, floor(max_cells / cells_per_value))
  n_chunks <- ceiling(length(split_values) / values_per_chunk)

  list(
    needs_chunking = TRUE,
    estimated_cells = estimated_cells,
    split_var = split_var,
    split_values = split_values,
    values_per_chunk = values_per_chunk,
    n_chunks = n_chunks,
    max_cells = max_cells
  )
}

#' The value codes a selection helper stands for
#'
#' `from`/`to`/`range` are positional in the variable's value list, bounds
#' included. `top(n)` is the first n values and `bottom(n)` the last n,
#' except for a time variable, where the server counts from the latest
#' period: `top(n)` is the n latest, `bottom(n)` the n earliest (verified
#' against SCB v2 `TAB638`, 2026-10-05). A bound that is not among the
#' codes falls back to all codes, the safe overestimate.
#' @param sel A `<px_selection>`.
#' @param all_codes Character vector of the variable's codes, in order.
#' @param is_time Whether the variable is the time variable.
#' @return Character vector of codes.
#' @noRd
selection_codes <- function(sel, all_codes, is_time = FALSE) {
  n_all <- length(all_codes)
  if (n_all == 0) return(all_codes)
  first_n <- function(n) utils::head(all_codes, n)
  last_n <- function(n) utils::tail(all_codes, n)
  count <- function() min(suppressWarnings(as.integer(sel$values[1])), n_all)
  at <- function(code) match(code, all_codes)
  switch(sel$type,
    top = {
      n <- count()
      if (is.na(n)) all_codes else if (is_time) last_n(n) else first_n(n)
    },
    bottom = {
      n <- count()
      if (is.na(n)) all_codes else if (is_time) first_n(n) else last_n(n)
    },
    from = {
      i <- at(sel$values[1])
      if (is.na(i)) all_codes else all_codes[i:n_all]
    },
    to = {
      i <- at(sel$values[1])
      if (is.na(i)) all_codes else all_codes[seq_len(i)]
    },
    range = {
      i <- at(sel$values[1])
      j <- at(sel$values[2])
      if (is.na(i) || is.na(j)) all_codes else all_codes[min(i, j):max(i, j)]
    },
    all_codes
  )
}

#' Execute a query in chunks with progress bar
#' @noRd
execute_chunked <- function(api, table_id, selections, .codelist,
                            chunk_info, simplify, verbose, status = FALSE) {
  split_var <- chunk_info$split_var
  split_values <- chunk_info$split_values
  values_per_chunk <- chunk_info$values_per_chunk
  n_chunks <- chunk_info$n_chunks

  # Build the value batches
  batches <- split(
    split_values,
    ceiling(seq_along(split_values) / values_per_chunk)
  )

  # Rate limit: calculate delay between requests
  max_calls <- api$config$max_calls %||% 30
  time_window <- api$config$time_window %||% 10
  delay <- time_window / max_calls

  cli::cli_alert_info(
    "Query requires ~{chunk_info$estimated_cells} cells (limit: {chunk_info$max_cells}). Splitting into {length(batches)} requests along '{split_var}'."
  )

  results <- list()
  cli::cli_progress_bar(
    "Fetching data",
    total = length(batches),
    .envir = environment()
  )

  for (i in seq_along(batches)) {
    # Build selections for this chunk
    chunk_selections <- selections
    chunk_selections[[split_var]] <- batches[[i]]

    q <- do.call(
      compose_data_query,
      c(list(api = api, table_id = table_id, .codelist = .codelist),
        chunk_selections)
    )
    raw <- execute_query(api, q$url, q$body, verbose = verbose)

    if (!is.null(raw)) {
      parsed <- if (api$version == "v2") {
        parse_data_v2(raw, table_id, simplify, status = status)
      } else {
        parse_data_v1(raw, table_id, simplify, status = status)
      }
      if (!is.null(parsed)) {
        results <- c(results, list(parsed))
      }
    }

    cli::cli_progress_update(.envir = environment())

    # Rate-limit delay between requests (not after the last one)
    if (i < length(batches)) {
      Sys.sleep(delay)
    }
  }

  cli::cli_progress_done(.envir = environment())

  if (length(results) == 0) return(NULL)

  dplyr::bind_rows(results)
}

#' Parse v2 (json-stat2) data response
#' @noRd
parse_data_v2 <- function(raw, table_id, simplify, status = FALSE) {
  # json-stat2 format has dimensions and values
  dims <- raw$dimension %||% raw$dimensions
  values <- raw$value

  if (is.null(dims) || is.null(values)) {
    # Try alternative v2 response format with columns + data
    out <- parse_data_v2_tabular(raw, table_id, simplify)
    if (status && !is.null(out)) out$status <- NA_character_
    return(out)
  }

  # Build dimension index
  dim_info <- list()
  dim_sizes <- integer()
  dim_order <- raw$id %||% names(dims)

  for (dim_name in dim_order) {
    d <- dims[[dim_name]]
    cats <- d$category
    codes <- cats$index
    labels <- cats$label

    # codes might be a named list with numeric indices, or a character vector
    if (is.list(codes)) {
      code_vec <- names(codes)
    } else {
      code_vec <- names(labels)
    }

    label_vec <- as.character(labels)

    dim_info[[dim_name]] <- list(
      label = d$label %||% dim_name,
      codes = code_vec,
      texts = label_vec
    )
    dim_sizes <- c(dim_sizes, length(code_vec))
  }

  # Expand grid of all dimension combinations (in json-stat2 order)
  # json-stat2 stores values in row-major order matching the dimension order in $id
  grid_args <- lapply(dim_info, function(d) seq_along(d$codes))
  names(grid_args) <- dim_order
  grid <- expand.grid(rev(grid_args), KEEP.OUT.ATTRS = FALSE)
  # Reverse back to original dimension order
  grid <- grid[, rev(names(grid)), drop = FALSE]

  n_rows <- nrow(grid)

  # Build the result tibble
  result <- tibble::tibble(table_id = rep(table_id, n_rows))

  for (dim_name in dim_order) {
    info <- dim_info[[dim_name]]
    idx <- grid[[dim_name]]
    result[[dim_name]] <- info$codes[idx]
    if (simplify) {
      result[[paste0(dim_name, "_text")]] <- info$texts[idx]
    }
  }

  # json-stat values may contain NULLs for missing data
  result$value <- as.numeric(vapply(values, function(v) {
    if (is.null(v)) NA_real_ else as.numeric(v)
  }, numeric(1)))

  if (status) result$status <- status_symbols_v2(raw$status, n_rows)

  result
}

#' Status symbols of a json-stat2 response, one per cell
#'
#' json-stat2 carries the symbols apart from the values: `status` is an
#' object keyed by the cell's zero-based position (PX-Web's form, sparse),
#' an array with one entry per cell, or a single string for every cell.
#' @param st `raw$status`, or NULL.
#' @param n Number of cells.
#' @return Character vector of length `n`, `NA` where no symbol is given.
#' @noRd
status_symbols_v2 <- function(st, n) {
  out <- rep(NA_character_, n)
  if (is.null(st) || length(st) == 0) return(out)
  as_chr <- function(v) if (is.null(v) || length(v) == 0) NA_character_ else as.character(v)[1]
  if (!is.null(names(st))) {
    idx <- suppressWarnings(as.integer(names(st))) + 1L
    ok <- !is.na(idx) & idx >= 1L & idx <= n
    out[idx[ok]] <- vapply(st[ok], as_chr, character(1))
  } else if (length(st) == n) {
    out <- vapply(st, as_chr, character(1), USE.NAMES = FALSE)
  } else if (length(st) == 1) {
    out <- rep(as_chr(st[[1]]), n)
  }
  out[!is.na(out) & !nzchar(out)] <- NA_character_
  out
}

#' Parse v2 tabular response format (columns + data)
#' @noRd
parse_data_v2_tabular <- function(raw, table_id, simplify) {
  columns <- raw$columns
  data_rows <- raw$data

  if (is.null(columns) || is.null(data_rows)) {
    warn("Unexpected API response format.")
    return(NULL)
  }

  # columns is a list of {code, text, type}
  col_codes <- vapply(columns, function(c) c$code %||% "", character(1))
  col_texts <- vapply(columns, function(c) c$text %||% "", character(1))
  col_types <- vapply(columns, function(c) c$type %||% "d", character(1))

  # data_rows is a list of {key: [...], values: [...]}
  rows <- lapply(data_rows, function(row) {
    keys <- row$key %||% list()
    vals <- row$values %||% list()
    c(keys, vals)
  })

  mat <- do.call(rbind, rows)
  df <- as.data.frame(mat, stringsAsFactors = FALSE)
  names(df) <- col_codes

  # Convert value columns to numeric
  for (i in seq_along(col_types)) {
    if (col_types[i] %in% c("c", "d")) {
      df[[i]] <- as.numeric(df[[i]])
    }
  }

  result <- tibble::as_tibble(df)
  result <- tibble::tibble(table_id = table_id) |>
    dplyr::bind_cols(result)

  result
}

#' Parse v1 JSON response
#'
#' Normalizes to long format with a `value` column, matching v2 output.
#' Dimension columns (type "d" or "t") become code columns; content columns
#' (type "c") are pivoted into `value` (and `ContentsCode` when there are
#' multiple content variables).
#' @noRd
parse_data_v1 <- function(raw, table_id, simplify, status = FALSE) {
  columns <- raw$columns
  data_rows <- raw$data

  if (is.null(columns) || is.null(data_rows)) {
    warn("Unexpected v1 API response format.")
    return(NULL)
  }

  col_codes <- vapply(columns, function(c) c$code %||% "", character(1))
  col_texts <- vapply(columns, function(c) c$text %||% "", character(1))
  col_types <- vapply(columns, function(c) c$type %||% "d", character(1))

  # Build a lookup from code -> display text for dimension values
  # v1 responses carry valueTexts alongside values in each data row
  col_value_texts <- lapply(columns, function(c) {
    vt <- c$valueTexts %||% NULL
    vals <- c$values %||% NULL
    if (!is.null(vt) && !is.null(vals) && length(vt) == length(vals)) {
      stats::setNames(as.character(vt), as.character(vals))
    } else {
      NULL
    }
  })
  names(col_value_texts) <- col_codes

  rows <- lapply(data_rows, function(row) {
    keys <- row$key %||% list()
    vals <- row$values %||% list()
    as.character(c(keys, vals))
  })

  if (length(rows) == 0) {
    warn("v1 API returned 0 data rows.")
    return(NULL)
  }

  mat <- do.call(rbind, rows)
  df <- as.data.frame(mat, stringsAsFactors = FALSE)
  names(df) <- col_codes

  # Identify dimension vs content columns
  dim_idx <- which(col_types %in% c("d", "t"))
  content_idx <- which(col_types == "c")

  # The source's own symbol for a cell without a value ("..", ".") arrives
  # as the cell's string; keep it aside before the numeric conversion.
  raw_content <- df[content_idx]
  symbol_of <- function(chr, num) {
    ifelse(is.na(num) & !is.na(chr) & nzchar(chr) & chr != "NA", chr, NA_character_)
  }

  # Convert content columns to numeric
  for (i in content_idx) {
    df[[i]] <- as.numeric(df[[i]])
  }

  # Build result with table_id
  result <- tibble::tibble(table_id = rep(table_id, nrow(df)))

  # Add dimension columns (with optional _text columns)
  for (i in dim_idx) {
    code <- col_codes[i]
    result[[code]] <- df[[code]]
    if (simplify) {
      lookup <- col_value_texts[[code]]
      if (!is.null(lookup)) {
        result[[paste0(code, "_text")]] <- unname(lookup[df[[code]]])
      } else {
        result[[paste0(code, "_text")]] <- df[[code]]
      }
    }
  }

  # Normalize content columns to a single `value` column
  if (length(content_idx) == 1) {
    # Single content variable — just rename to value
    result$value <- df[[col_codes[content_idx]]]
    if (status) result$status <- symbol_of(raw_content[[1]], result$value)
  } else if (length(content_idx) > 1) {
    # Multiple content variables — pivot to long format
    content_codes <- col_codes[content_idx]
    content_texts <- col_texts[content_idx]
    content_text_lookup <- stats::setNames(content_texts, content_codes)

    # Repeat each row for each content variable
    n_rows <- nrow(df)
    n_content <- length(content_codes)
    row_idx <- rep(seq_len(n_rows), each = n_content)

    # Build expanded result
    expanded <- result[row_idx, , drop = FALSE]
    expanded$ContentsCode <- rep(content_codes, times = n_rows)
    if (simplify) {
      expanded$ContentsCode_text <- rep(content_texts, times = n_rows)
    }

    vals <- numeric(n_rows * n_content)
    for (j in seq_along(content_codes)) {
      vals[seq(j, length(vals), by = n_content)] <- df[[content_codes[j]]]
    }
    expanded$value <- vals
    if (status) {
      syms <- character(n_rows * n_content)
      for (j in seq_along(content_codes)) {
        syms[seq(j, length(syms), by = n_content)] <- raw_content[[j]]
      }
      expanded$status <- symbol_of(syms, vals)
    }

    result <- tibble::as_tibble(expanded)
  } else {
    # No content columns at all — unusual, but don't crash
    result$value <- NA_real_
    if (status) result$status <- NA_character_
  }

  result
}

#' Put the metadata labels on a v1 result
#'
#' A v1 (px-json) data response carries codes only, so the `<var>_text`
#' twin column repeated the code. The variable metadata `get_data()` has
#' already fetched knows the label of every code; use it wherever the twin
#' still equals the code.
#'
#' The same response also re-shapes a contents variable: its values come
#' back as separate content columns, which the parser folds into
#' `ContentsCode` whatever the variable is called in the metadata (for
#' example in the `*_Cont.px` tables of Energimyndigheten). The column name
#' is kept, for the sake of stored specs that read it, and the name the
#' source uses is put in the attribute `px_contents_variable` so the mapping
#' can be read rather than discovered.
#' @param result Parsed tibble.
#' @param vars Variable metadata tibble, or NULL.
#' @param selected Names of the variables the caller selected.
#' @param simplify Whether `_text` columns were asked for.
#' @noRd
label_v1_result <- function(result, vars, selected = character(), simplify = TRUE) {
  if (is.null(result) || is.null(vars) || nrow(vars) == 0) return(result)

  if (simplify) {
    for (i in seq_len(nrow(vars))) {
      code <- vars$code[i]
      text_col <- paste0(code, "_text")
      if (is.na(code) || !all(c(code, text_col) %in% names(result))) next
      vals <- vars$values[[i]]
      if (!is.data.frame(vals) || nrow(vals) == 0) next
      lookup <- stats::setNames(px_chr(vals$text), px_chr(vals$code))
      codes <- as.character(result[[code]])
      labels <- unname(lookup[codes])
      current <- as.character(result[[text_col]])
      fill <- !is.na(labels) & (is.na(current) | current == codes)
      if (any(fill)) {
        current[fill] <- labels[fill]
        result[[text_col]] <- current
      }
    }
  }

  if ("ContentsCode" %in% names(result) && !"ContentsCode" %in% vars$code) {
    folded <- setdiff(intersect(selected, vars$code), names(result))
    if (length(folded) == 1) attr(result, "px_contents_variable") <- folded
  }

  result
}

#' Pivot data to wide format
#' @noRd
pivot_data_wide <- function(df) {
  # If there's a ContentsCode column, pivot on it
  if ("ContentsCode" %in% names(df)) {
    value_cols <- grep("^value", names(df), value = TRUE)
    if (length(value_cols) > 0) {
      id_cols <- setdiff(
        names(df),
        c("ContentsCode", "ContentsCode_text", value_cols)
      )
      df <- df |>
        tidyr::pivot_wider(
          id_cols = dplyr::all_of(id_cols),
          names_from = "ContentsCode",
          values_from = dplyr::all_of(value_cols)
        )
    }
  }

  df
}

#' Parse comments from API response
#' @noRd
parse_comments <- function(comments) {
  if (is.null(comments) || length(comments) == 0) return(NULL)

  rows <- lapply(comments, function(c) {
    tibble::tibble(
      variable = c$variable %||% NA_character_,
      value = c$value %||% NA_character_,
      comment = c$comment %||% c$text %||% NA_character_
    )
  })

  dplyr::bind_rows(rows)
}

#' Remove monotonous columns from a data tibble
#'
#' @param data_df A tibble returned by [get_data()].
#' @param remove_monotonous_data Remove columns where all values are identical.
#' @return A tibble.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   d <- get_data(scb, "TAB638", Region = "0180", ContentsCode = "*",
#'                 Tid = px_top(3))
#'   d |> data_minimize()
#' }}
data_minimize <- function(data_df, remove_monotonous_data = TRUE) {
  remove_monotonous(data_df, remove_monotonous_data)
}

#' Generate a source caption for plots
#'
#' Builds a human-readable source attribution string from a data tibble
#' returned by [get_data()] and, optionally, a variable tibble returned
#' by [get_variables()]. The string is suitable for use as a `caption`
#' in `ggplot2::labs()`.
#'
#' By default the caption shows the API and table that the data came
#' from, and — if `var_df` is supplied — the variables included in the
#' table with both a human-readable label and the raw code, e.g.
#'
#' \preformatted{
#' Source: Statistics Sweden (SCB), table TAB638
#' Region (Region) | Marital status (Civilstand) | Year (Tid)
#' }
#'
#' Use `omit_varname` to drop the codes, `omit_desc` to drop the labels,
#' and `lang` to switch between English and Swedish wording of the
#' source prefix.
#'
#' @param data_df A tibble returned by [get_data()].
#' @param var_df Optional tibble returned by [get_variables()]. If
#'   supplied, a line listing the table's variables is added below the
#'   source line.
#' @param lang Language for the caption wording: `"EN"` (English,
#'   default) or `"SV"` (Swedish). Defaults to
#'   `getOption("pixieweb.lang", "EN")`. PX-Web variable labels are
#'   returned by the API in whichever language was requested in
#'   [px_api()] regardless of this setting.
#' @param omit_varname Logical. If `TRUE`, omit the raw variable codes
#'   (the parenthesised IDs like `Region`) and show only the labels.
#' @param omit_desc Logical. If `TRUE`, omit the human-readable labels
#'   and show only the codes.
#' @return A single character string suitable for plot captions.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   vars <- get_variables(scb, "TAB638")
#'   d <- get_data(scb, "TAB638", Region = "0180", ContentsCode = "*",
#'                 Tid = px_top(3))
#'   data_legend(d, vars)
#'   data_legend(d, vars, lang = "SV")
#'   data_legend(d, vars, omit_varname = TRUE)
#'   data_legend(d, vars, omit_desc = TRUE)
#' }}
data_legend <- function(data_df,
                        var_df = NULL,
                        lang = NULL,
                        omit_varname = FALSE,
                        omit_desc = FALSE) {

  lang <- resolve_lang(lang)
  s <- legend_strings(lang)

  source_info <- attr(data_df, "px_source")
  source_line <- if (!is.null(source_info)) {
    paste0(
      s$source, ": ", source_info$api, ", ",
      s$table, " ", source_info$table_id
    )
  } else {
    NULL
  }

  var_line <- if (!is.null(var_df) && nrow(var_df) > 0) {
    parts <- vapply(seq_len(nrow(var_df)), function(i) {
      format_legend_field(var_df$text[i], var_df$code[i],
                          omit_varname, omit_desc)
    }, character(1))
    paste(parts, collapse = " | ")
  } else {
    NULL
  }

  parts <- c(source_line, var_line)
  if (length(parts) == 0) return("")
  paste(parts, collapse = "\n")
}

#' Localized strings for data_legend
#' @noRd
legend_strings <- function(lang) {
  switch(lang,
    SV = list(source = "K\u00e4lla", table = "tabell"),
    EN = list(source = "Source", table = "table")
  )
}

#' Format a single variable entry for the legend
#' @noRd
format_legend_field <- function(label, code, omit_varname, omit_desc) {
  has_label <- !is.null(label) && !is.na(label) && nzchar(label)

  if (omit_varname) return(if (has_label) label else code)
  if (omit_desc || !has_label) return(code)
  paste0(label, " (", code, ")")
}

#' Extract comments from data
#'
#' @param data_df A tibble returned by [get_data()] with `.comments = TRUE`.
#' @return A tibble with columns `variable`, `value`, `comment`, or `NULL`.
#' @export
#' @examples
#' \donttest{
#' scb <- px_api("scb", lang = "en")
#' if (px_available(scb)) {
#'   d <- get_data(scb, "TAB638", Region = "0180", ContentsCode = "*",
#'                 Tid = px_top(3), .comments = TRUE)
#'   data_comments(d)
#' }}
data_comments <- function(data_df) {
  attr(data_df, "comments")
}
