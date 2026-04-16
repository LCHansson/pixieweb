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
#> ── TAB1743: Income standard (median) for families with children aged 0-17 living at home, by population groups. Year 1995-2013  
#>   Subject: Living conditions > Children and their Families > Older tables, not updated
#>   Period: 1995 – 2013 (Annual)
#>   Updated: 2015-10-01T07:30:00Z
#>   Category: public
#>   Variables: population group, observations, year
#>   Source: Statistics Sweden 
#> 
#> ── TAB934: Family´s disposable income per consumption unit in SEK thousands. Children in families living at home aged 0-17, by population groups. Year 1995-2013  
#>   Subject: Living conditions > Children and their Families > Older tables, not updated
#>   Period: 1995 – 2013 (Annual)
#>   Updated: 2015-10-01T07:30:00Z
#>   Category: public
#>   Variables: population group, observations, year
#>   Source: Statistics Sweden 
#> 
#> ── TAB4552: Population connected to public network. Year 1960-2023 ────────────── 
#>   Subject: Environment > Water withdrawal and water use in Sweden > Water and wastewater services
#>   Period: 1960 – 2023 (Annual)
#>   Updated: 2025-06-12T06:00:00Z
#>   Category: public
#>   Variables: type of network, observations, year
#>   Source: Statistics Sweden 
#> 
#> ... and 347 more table(s).
```
