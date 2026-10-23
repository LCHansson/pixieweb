# Print human-readable table summaries

Print human-readable table summaries

## Usage

``` r
table_describe(table_df, max_n = 5, format = "inline", heading_level = 2)
```

## Arguments

- table_df:

  A tibble returned by
  [`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md).

- max_n:

  Maximum number of tables to describe.

- format:

  Output format: `"inline"` (console) or `"md"` (markdown).

- heading_level:

  Heading level for output.

## Value

`table_df` invisibly (for piping).

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {
  get_tables(scb, query = "population") |> table_describe(max_n = 3)
}# }
#> ── TAB6473: Population statistics by region and sex.  Month 2025M01-2026M08 ───── 
#>   Subject: Population > Population statistics > Summary of vital events
#>   Period: 2025M01 – 2026M08 (Monthly)
#>   Updated: 2026-10-07T06:00:00Z
#>   Category: public
#>   Variables: region, population changes, sex, observations, month
#>   Source: Statistics Sweden 
#> 
#> ── TAB1625: Population statistics by region and sex. Month 2000M01-2024M12 ────── 
#>   Subject: Population > Population statistics > Summary of vital events
#>   Period: 2000M01 – 2024M12 (Monthly)
#>   Updated: 2025-02-21T07:00:00Z
#>   Category: public
#>   Variables: region, population changes, sex, observations, month
#>   Source: Statistics Sweden 
#> 
#> ── TAB6481: Population statistics per quarter/half year/year by region and sex.  Year 2025-2026  
#>   Subject: Population > Population statistics > Summary of vital events
#>   Period: 2025 – 2026 (Annual)
#>   Updated: 2026-08-21T06:00:00Z
#>   Category: public
#>   Variables: region, population changes, period, sex, observations, year
#>   Source: Statistics Sweden 
#> 
#> ... and 610 more table(s).
```
