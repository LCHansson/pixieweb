# Compose a data query

Build the URL and JSON body for a data request without executing it.
Useful for inspecting or modifying queries before sending them.

## Usage

``` r
compose_data_query(api, table_id, ..., .codelist = NULL)
```

## Arguments

- api:

  A `<px_api>` object.

- table_id:

  Single table ID.

- ...:

  Variable selections (same as
  [`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md)).

- .codelist:

  Named list of codelist overrides.

## Value

A list with `$url` (character) and `$body` (list, JSON-serializable).

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {
  q <- compose_data_query(scb, "TAB638", Region = c("0180"),
                          ContentsCode = "*", Tid = px_top(5))
  str(q$url)
  str(q$body)
}# }
#>  chr "https://api.scb.se/ov0104/v2beta/api/v2/tables/TAB638/data?lang=en&outputFormat=json-stat2"
#> List of 1
#>  $ selection:List of 3
#>   ..$ :List of 2
#>   .. ..$ variableCode: chr "Region"
#>   .. ..$ valueCodes  :List of 1
#>   .. .. ..$ : chr "0180"
#>   ..$ :List of 2
#>   .. ..$ variableCode: chr "ContentsCode"
#>   .. ..$ valueCodes  :List of 1
#>   .. .. ..$ : chr "*"
#>   ..$ :List of 2
#>   .. ..$ variableCode: chr "Tid"
#>   .. ..$ valueCodes  :List of 1
#>   .. .. ..$ : chr "top(5)"
```
