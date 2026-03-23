# Test fixtures for API catalogue live tests
# Auto-sourced by testthat before all test files

#' Test specifications for each API in the catalogue
#'
#' Each entry contains the minimum info needed to exercise all verbs:
#' - alias, lang: how to connect
#' - versions: named list mapping version string to a list with:
#'   - table_id: full path to a known table (v1 uses path-based IDs)
#'   - codelist_var: variable code with codelists (NULL if unknown)
#'
#' All table paths verified against live APIs on 2026-03-19.
pixieweb_test_apis <- function() {
  list(
    # --- Nordic national statistics ---
    list(
      alias    = "scb",
      lang     = "en",
      versions = list(
        v2 = list(table_id = "TAB638", codelist_var = "Region"),
        v1 = list(table_id = "ssd/BE/BE0101/BE0101A/BefolkManad", codelist_var = NULL)
      )
    ),
    list(
      alias    = "ssb",
      lang     = "en",
      versions = list(
        v2 = list(table_id = "05803", codelist_var = "Region"),
        v1 = list(table_id = "table/05803", codelist_var = NULL)
      )
    ),
    list(
      alias    = "statfi",
      lang     = "en",
      versions = list(
        v1 = list(table_id = "StatFin/matk/statfin_matk_pxt_117s.px", codelist_var = NULL)
      )
    ),
    list(
      alias    = "statis",
      lang     = "en",
      versions = list(
        v1 = list(table_id = "Ibuar/mannfjoldi/1_yfirlit/arsfjordungstolur/MAN10001.px", codelist_var = NULL)
      )
    ),
    list(
      alias    = "hagstova",
      lang     = "en",
      versions = list(
        v1 = list(table_id = "H2/land_oyfj.px", codelist_var = NULL)
      )
    ),
    list(
      alias    = "statgl",
      lang     = "en",
      versions = list(
        v1 = list(table_id = "Greenland/ESXINVST.px", codelist_var = NULL)
      )
    ),
    list(
      alias    = "asub",
      lang     = "sv",
      versions = list(
        v1 = list(table_id = "Statistik/AR001.px", codelist_var = NULL)
      )
    ),
    # --- Swedish agencies ---
    list(
      alias    = "sjv",
      lang     = "sv",
      versions = list(
        v1 = list(table_id = "Jordbruksverkets%20statistikdatabas/JO0604A1.px", codelist_var = NULL)
      )
    ),
    list(
      alias    = "energi",
      lang     = "sv",
      versions = list(
        v1 = list(table_id = "Energimyndighetens_statistikdatabas/EN_IND1A.px", codelist_var = NULL)
      )
    ),
    list(
      alias    = "fohm",
      lang     = "sv",
      versions = list(
        v1 = list(table_id = "A_Folkhalsodata/atcTVAld.px", codelist_var = NULL)
      )
    ),
    list(
      alias    = "konj",
      lang     = "sv",
      versions = list(
        v1 = list(table_id = "KonjBar/Indikatorm.px", codelist_var = NULL)
      )
    ),
    list(
      alias    = "msb",
      lang     = "sv",
      versions = list(
        v1 = list(table_id = "PxData/A10", codelist_var = NULL)
      )
    ),
    list(
      alias    = "slu",
      lang     = "sv",
      versions = list(
        v1 = list(table_id = "OffStat/AM_Areal_agoslag_SVL_tab.px", codelist_var = NULL)
      )
    )
  )
}

#' Skip test if API is not reachable
skip_api <- function(api, label) {
  skip_if_not(px_available(api), paste0(label, " not reachable"))
}
