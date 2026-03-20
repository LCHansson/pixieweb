# Explore raw PX-Web API responses
# Run interactively to understand the JSON structures that rpx parses.

library(httr2)
library(jsonlite)

base <- "https://api.scb.se/ov0104/v2beta/api/v2"

# ── 1. get_tables (search) ──────────────────────────────────────────────
cat("=== GET /tables?query=... ===\n")
resp <- request(paste0(base, "/tables?lang=sv&query=fordon&pageSize=10")) |>
  req_perform() |> resp_body_json()
cat(toJSON(resp, pretty = TRUE, auto_unbox = TRUE), "\n\n")

# ── 2. get_tables (by ID) ──────────────────────────────────────────────
cat("=== GET /tables/{id} ===\n")
resp <- request(paste0(base, "/tables/TAB638?lang=sv")) |>
  req_perform() |> resp_body_json()
cat(toJSON(resp, pretty = TRUE, auto_unbox = TRUE), "\n\n")

# ── 3. get_variables (metadata) ─────────────────────────────────────────
cat("=== GET /tables/{id}/metadata ===\n")
resp <- request(paste0(base, "/tables/TAB638/metadata?lang=sv&outputFormat=json")) |>
  req_perform() |> resp_body_json()
cat(toJSON(resp, pretty = TRUE, auto_unbox = TRUE), "\n\n")

# ── 4. get_codelists ────────────────────────────────────────────────────
# First, find a codelist ID from the metadata (look in dimension extensions)
cat("=== Codelist IDs from metadata ===\n")
for (dname in names(resp$dimension)) {
  cls <- resp$dimension[[dname]]$extension$codelists
  if (length(cls) > 0) {
    cat(dname, "codelists:\n")
    cat(toJSON(cls, pretty = TRUE, auto_unbox = TRUE), "\n")
  }
}
# If codelists were found, fetch one:
# cat("=== GET /codelists/{id} ===\n")
# resp <- request(paste0(base, "/codelists/CODELIST_ID?lang=en")) |>
#   req_perform() |> resp_body_json()
# cat(toJSON(resp, pretty = TRUE, auto_unbox = TRUE), "\n\n")

# ── 5. get_data (POST) ─────────────────────────────────────────────────
cat("=== POST /tables/{id}/data ===\n")
body <- list(
  selection = list(
    list(variableCode = "Region", valueCodes = list("00")),
    list(variableCode = "ContentsCode", valueCodes = list("BE0101N1")),
    list(variableCode = "Tid", valueCodes = list("top(5)"))
  )
)
cat("Request body:\n")
cat(toJSON(body, pretty = TRUE, auto_unbox = TRUE), "\n\n")

resp <- request(paste0(base, "/tables/TAB638/data?lang=en&outputFormat=json-stat2")) |>
  req_body_json(body) |>
  req_perform() |> resp_body_json()
cat("Response:\n")
cat(toJSON(resp, pretty = TRUE, auto_unbox = TRUE), "\n\n")

# ── 6. API config ──────────────────────────────────────────────────────
cat("=== GET /config ===\n")
resp <- request(paste0(base, "/config")) |>
  req_perform() |> resp_body_json()
cat(toJSON(resp, pretty = TRUE, auto_unbox = TRUE), "\n\n")
