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
#'   # Fetch with explicit selections
#'   get_data(scb, "TAB638",
#'     Region = c("0180", "1480"),
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
                     verbose = FALSE) {
  check_px_api(api)
  stopifnot(.output %in% c("long", "wide"))

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
  if (isTRUE(cache) && !is.null(cache_location) &&
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
  vars_meta <- if (inherits(query, "px_query")) query$variables else NULL
  chunk_info <- check_query_size(selections, api, table_id, max_cells, verbose,
                                  vars = vars_meta)

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
      chunk_info, simplify, verbose
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
      result <- parse_data_v2(raw, table_id, simplify)
    } else {
      result <- parse_data_v1(raw, table_id, simplify)
    }
  }

  if (is.null(result)) return(NULL)

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

  for (i in seq_len(nrow(vars))) {
    v <- vars[i, ]
    code <- v$code
    sel <- selections[[code]]

    if (is.null(sel)) {
      # Eliminated
      var_sizes[[code]] <- 1
      var_values[[code]] <- NULL
    } else if (is.character(sel) && length(sel) == 1 && sel == "*") {
      var_sizes[[code]] <- v$n_values
      var_values[[code]] <- v$values[[1]]$code
    } else if (is.character(sel)) {
      var_sizes[[code]] <- length(sel)
      var_values[[code]] <- sel
    } else if (inherits(sel, "px_selection")) {
      n <- switch(sel$type,
        top = min(as.integer(sel$values), v$n_values),
        bottom = min(as.integer(sel$values), v$n_values),
        all = v$n_values,
        v$n_values  # from/to/range — estimate as all
      )
      var_sizes[[code]] <- n
      # For top/bottom, get the actual value codes
      all_codes <- v$values[[1]]$code
      var_values[[code]] <- switch(sel$type,
        top = utils::head(all_codes, n),
        bottom = utils::tail(all_codes, n),
        all_codes
      )
    } else {
      var_sizes[[code]] <- v$n_values
      var_values[[code]] <- v$values[[1]]$code
    }
  }

  estimated_cells <- prod(unlist(var_sizes))

  if (estimated_cells <= max_cells) {
    return(list(needs_chunking = FALSE, estimated_cells = estimated_cells))
  }

  # Find the variable to split on: the one with the most values
  # (excluding eliminated variables)
  splittable <- var_sizes[!vapply(var_values, is.null, logical(1))]
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

#' Execute a query in chunks with progress bar
#' @noRd
execute_chunked <- function(api, table_id, selections, .codelist,
                            chunk_info, simplify, verbose) {
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
        parse_data_v2(raw, table_id, simplify)
      } else {
        parse_data_v1(raw, table_id, simplify)
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
parse_data_v2 <- function(raw, table_id, simplify) {
  # json-stat2 format has dimensions and values
  dims <- raw$dimension %||% raw$dimensions
  values <- raw$value

  if (is.null(dims) || is.null(values)) {
    # Try alternative v2 response format with columns + data
    return(parse_data_v2_tabular(raw, table_id, simplify))
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

  result
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
parse_data_v1 <- function(raw, table_id, simplify) {
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

    result <- tibble::as_tibble(expanded)
  } else {
    # No content columns at all — unusual, but don't crash
    result$value <- NA_real_
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
#'   d <- get_data(scb, "TAB638", Region = "0180", Tid = px_top(3))
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
#'   d <- get_data(scb, "TAB638", Region = "0180", Tid = px_top(3))
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
#'   d <- get_data(scb, "TAB638", Region = "0180", Tid = px_top(3), .comments = TRUE)
#'   data_comments(d)
#' }}
data_comments <- function(data_df) {
  attr(data_df, "comments")
}
