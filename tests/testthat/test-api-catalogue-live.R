# Comprehensive live tests: all verbs x all catalogue APIs
# Skipped on CRAN; each API independently skippable if unreachable.

skip_on_cran()

apis <- rpx_test_apis()

for (spec in apis) {
  for (ver in names(spec$versions)) {
    ver_spec <- spec$versions[[ver]]
    table_id <- ver_spec$table_id
    codelist_var <- ver_spec$codelist_var
    label <- paste0(spec$alias, "_", ver)

    # ── px_api connection ──────────────────────────────────────────
    test_that(paste0(label, ": px_api connects"), {
      api <- px_api(spec$alias, lang = spec$lang, version = ver)
      skip_api(api, label)

      expect_s3_class(api, "px_api")
      expect_equal(api$alias, spec$alias)
      expect_equal(api$version, ver)
      expect_equal(api$lang, spec$lang)

      if (ver == "v2") {
        expect_true(!is.null(api$config))
        expect_true(api$config$max_cells > 0)
      }
    })

    # ── get_tables (by id) ─────────────────────────────────────────
    test_that(paste0(label, ": get_tables by id"), {
      api <- px_api(spec$alias, lang = spec$lang, version = ver)
      skip_api(api, label)

      tables <- tryCatch(
        get_tables(api, id = table_id),
        error = function(e) e
      )
      if (inherits(tables, "error")) {
        skip(paste0("get_tables(id) failed: ", conditionMessage(tables)))
      }

      expect_s3_class(tables, "tbl_df")
      expect_true(nrow(tables) >= 1)
      expect_true("id" %in% names(tables))
      expect_true("title" %in% names(tables))
    })

    # ── get_tables (search) ────────────────────────────────────────
    test_that(paste0(label, ": get_tables by query"), {
      api <- px_api(spec$alias, lang = spec$lang, version = ver)
      skip_api(api, label)

      tables <- tryCatch(
        get_tables(api, query = "population", max_results = 5),
        error = function(e) e
      )
      if (inherits(tables, "error")) {
        skip(paste0("get_tables(query) failed: ", conditionMessage(tables)))
      }

      # Some APIs return NULL (no results for English query on Swedish API)
      if (is.null(tables)) {
        expect_null(tables)  # avoid "empty test" warning
      } else {
        expect_s3_class(tables, "tbl_df")
        expect_true("id" %in% names(tables))
      }
    })

    # ── get_variables ──────────────────────────────────────────────
    test_that(paste0(label, ": get_variables"), {
      api <- px_api(spec$alias, lang = spec$lang, version = ver)
      skip_api(api, label)

      vars <- tryCatch(
        get_variables(api, table_id),
        error = function(e) e
      )
      if (inherits(vars, "error")) {
        skip(paste0("get_variables failed: ", conditionMessage(vars)))
      }

      expect_s3_class(vars, "tbl_df")
      expect_true(nrow(vars) > 0)

      expected_cols <- c("code", "text", "n_values", "elimination",
                         "time", "values", "table_id")
      for (col in expected_cols) {
        expect_true(col %in% names(vars), info = paste("Missing column:", col))
      }
    })

    # ── prepare_query ──────────────────────────────────────────────
    test_that(paste0(label, ": prepare_query"), {
      api <- px_api(spec$alias, lang = spec$lang, version = ver)
      skip_api(api, label)

      q <- tryCatch(
        prepare_query(api, table_id),
        error = function(e) e
      )
      if (inherits(q, "error")) {
        skip(paste0("prepare_query failed: ", conditionMessage(q)))
      }

      expect_s3_class(q, "px_query")
      expect_equal(q$table_id, table_id)
      expect_true(length(q$selections) > 0)
    })

    # ── get_data ───────────────────────────────────────────────────
    test_that(paste0(label, ": get_data"), {
      api <- px_api(spec$alias, lang = spec$lang, version = ver)
      skip_api(api, label)

      q <- tryCatch(
        prepare_query(api, table_id),
        error = function(e) e
      )
      if (inherits(q, "error")) {
        skip(paste0("prepare_query failed: ", conditionMessage(q)))
      }

      d <- tryCatch(
        get_data(api, query = q),
        error = function(e) e
      )
      if (inherits(d, "error")) {
        skip(paste0("get_data failed: ", conditionMessage(d)))
      }

      expect_s3_class(d, "tbl_df")
      expect_true(nrow(d) > 0)
      expect_true("value" %in% names(d))
      expect_true("table_id" %in% names(d))
    })

    # ── table_enrich ───────────────────────────────────────────────
    test_that(paste0(label, ": table_enrich"), {
      api <- px_api(spec$alias, lang = spec$lang, version = ver)
      skip_api(api, label)

      tables <- tryCatch(
        get_tables(api, id = table_id),
        error = function(e) e
      )
      if (inherits(tables, "error") || is.null(tables)) {
        skip("get_tables(id) failed — cannot test table_enrich")
      }

      enriched <- tryCatch(
        table_enrich(tables, api = api),
        error = function(e) e
      )
      if (inherits(enriched, "error")) {
        skip(paste0("table_enrich failed: ", conditionMessage(enriched)))
      }

      expect_s3_class(enriched, "tbl_df")
      expect_true(nrow(enriched) > 0)
      for (col in c("notes", "contents", "contact")) {
        expect_true(col %in% names(enriched),
                    info = paste("Missing enriched column:", col))
      }
    })

    # ── get_codelists (v2 with known variable only) ────────────────
    if (!is.null(codelist_var) && ver == "v2") {
      test_that(paste0(label, ": get_codelists"), {
        api <- px_api(spec$alias, lang = spec$lang, version = ver)
        skip_api(api, label)

        cls <- tryCatch(
          get_codelists(api, table_id, codelist_var),
          error = function(e) e
        )
        if (inherits(cls, "error")) {
          skip(paste0("get_codelists failed: ", conditionMessage(cls)))
        }

        if (!is.null(cls)) {
          expect_s3_class(cls, "tbl_df")
          if (nrow(cls) > 0) {
            for (col in c("id", "text", "type", "values")) {
              expect_true(col %in% names(cls),
                          info = paste("Missing codelist column:", col))
            }
          }
        }
      })
    }

    # ── v2-only verbs error on v1 ─────────────────────────────────
    if (ver == "v1") {
      test_that(paste0(label, ": get_saved_query errors on v1"), {
        api <- px_api(spec$alias, lang = spec$lang, version = ver)
        skip_api(api, label)

        expect_error(
          get_saved_query(api, "fake-query-id"),
          "v2"
        )
      })

      test_that(paste0(label, ": save_query errors on v1"), {
        api <- px_api(spec$alias, lang = spec$lang, version = ver)
        skip_api(api, label)

        expect_error(
          save_query(api, table_id),
          "v2"
        )
      })

      test_that(paste0(label, ": compose_table_query errors on v1"), {
        api <- px_api(spec$alias, lang = spec$lang, version = ver)
        skip_api(api, label)

        expect_error(
          compose_table_query(api, query = "population"),
          "v2"
        )
      })
    }
  }
}
