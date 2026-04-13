# Working with multiple APIs

One of pixieweb’s strengths is its ability to connect to any PX-Web
instance with the same interface. This vignette shows how to compare
data across national statistics agencies.

**The honest truth about cross-country comparison:** The pixieweb
functions work identically across APIs, but the *data* is not
harmonised. Table IDs, variable names, and code systems differ between
countries. The workflow is: find a comparable table in each country (the
hard part), then use identical pixieweb code to fetch and combine the
results.

> **Prerequisite:** This vignette assumes you are comfortable with the
> basics from
> [`vignette("a-quickstart")`](https://lchansson.github.io/pixieweb/articles/a-quickstart.md).

## Available APIs

``` r
library("pixieweb")
```

``` r
px_api_catalogue()
```

    #> # A tibble: 13 × 7
    #>    alias    description                 url   url_v1 versions langs default_lang
    #>    <chr>    <chr>                       <chr> <chr>  <list>   <lis> <chr>       
    #>  1 scb      Statistics Sweden (SCB)     http… https… <chr>    <chr> sv          
    #>  2 ssb      Statistics Norway (SSB)     http… https… <chr>    <chr> no          
    #>  3 statfi   Statistics Finland          http… https… <chr>    <chr> fi          
    #>  4 statis   Statistics Iceland          http… https… <chr>    <chr> en          
    #>  5 hagstova Statistics Faroe Islands    http… https… <chr>    <chr> fo          
    #>  6 statgl   Statistics Greenland        http… https… <chr>    <chr> da          
    #>  7 asub     Statistics Åland (ÅSUB)     http… https… <chr>    <chr> sv          
    #>  8 sjv      Swedish Board of Agricultu… http… https… <chr>    <chr> sv          
    #>  9 energi   Swedish Energy Agency (Ene… http… https… <chr>    <chr> sv          
    #> 10 fohm     Public Health Agency of Sw… http… https… <chr>    <chr> sv          
    #> 11 konj     National Institute of Econ… http… https… <chr>    <chr> sv          
    #> 12 msb      Swedish Civil Contingencie… http… https… <chr>    <chr> sv          
    #> 13 slu      Swedish University of Agri… http… https… <chr>    <chr> sv

pixieweb ships with a catalogue of known PX-Web instances. You can also
connect to any PX-Web API by providing a full URL.

## Connecting to multiple agencies

``` r
scb <- px_api("scb", lang = "en")      # Sweden (v2)
ssb <- px_api("ssb", lang = "en")      # Norway (v2)
statfi <- px_api("statfi", lang = "en") # Finland (v1)
```

Each API object stores the base URL, language, API version, and
configuration (cell limits, rate limits):

``` r
scb
#> PX-Web API: Statistics Sweden (SCB) (v2, en)
#>   Max cells: 150000 | Rate limit: 30/10s
```

## API version differences

PX-Web has two API versions: - **v1**: Legacy, POST-only data queries,
no search endpoint. Table discovery requires walking a folder
hierarchy. - **v2**: Modern, GET+POST data queries, full-text search,
codelists endpoint, saved queries.

pixieweb handles both versions transparently. The user-facing functions
have the same signatures — only the internal request building differs.

Some selection helpers are v2-only:
[`px_bottom()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
[`px_from()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
[`px_to()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
and
[`px_range()`](https://lchansson.github.io/pixieweb/reference/px_selections.md)
will raise an informative error if used against a v1 API.

## Cross-country comparison example

Suppose you want to compare population data across Sweden and Norway.
The table IDs and variable codes will differ, but the workflow is
identical:

``` r
library("dplyr")

# Find population tables in each country
scb_tables <- get_tables(scb, query = "population")
ssb_tables <- get_tables(ssb, query = "population")

# Explore a table from each
scb_tables |> table_describe(max_n = 3)
ssb_tables |> table_describe(max_n = 3)
```

Note that table IDs are completely different between countries, and
variable names may also differ (“Region” in SCB vs other names
elsewhere). Always run
[`variable_describe()`](https://lchansson.github.io/pixieweb/reference/variable_describe.md)
on each table before building your query:

``` r
# Fetch data using prepare_query() for quick exploration
scb_q <- prepare_query(scb, "TAB638",
  Region = "00",       # "Riket" (whole country)
  Tid = px_top(5),
  ContentsCode = "BE0101N1" # Population
)

# Norwegian table IDs are different — explore to find the right one
ssb_vars <- get_variables(ssb, "05803")
ssb_vars |> variable_describe()
```

## Combining results

Since
[`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md)
returns standard tibbles with a `table_id` attribute, you can bind
results from different APIs:

``` r
results <- list(
  sweden = get_data(scb, query = scb_q),
  norway = get_data(ssb, "05803",
    ContentsCode = "Personer",
    Tid = px_top(5)
  )
)

# .id = "country" adds a column tracking which list element each row
# came from — essential for traceability after binding
dplyr::bind_rows(results, .id = "country")
# NOTE: column names may differ between countries. If so, you may need
# to rename() before bind_rows() to align them.
```

## Tips for cross-agency work

- **Language matters.** Codes are often language-dependent.
  `lang = "en"` gives the most consistent *labels* across countries, but
  codes and table IDs are language-independent.
- **Table structure varies.** Swedish tables may have “Region” while
  Finnish tables have “Alue”. Run
  `get_variables() |> variable_describe()` on each table before writing
  queries.
- **API limits differ.** SCB allows ~100 000 cells per request; other
  agencies may allow less. Use `api$config$max_cells` to check.
  [`prepare_query()`](https://lchansson.github.io/pixieweb/reference/prepare_query.md)
  respects the limit automatically.
- **v1 vs v2.** Not all agencies have migrated to v2. Selection helpers
  [`px_from()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
  [`px_range()`](https://lchansson.github.io/pixieweb/reference/px_selections.md)
  etc. raise an informative error if used against a v1 API. Check
  `api$version` and the catalogue’s `versions` column.

## Next steps

- **Data model & advanced features** —
  [`vignette("introduction-to-pixieweb")`](https://lchansson.github.io/pixieweb/articles/introduction-to-pixieweb.md)
  covers codelists, wide output, and query composition.
- **Quick refresher** —
  [`vignette("a-quickstart")`](https://lchansson.github.io/pixieweb/articles/a-quickstart.md)
  for the single-API basics.

## Related packages

`pixieweb` is part of a family of R packages for Swedish and Nordic open
statistics that share the same design philosophy:

- [rKolada](https://lchansson.github.io/rKolada/) — R client for the
  [Kolada](https://kolada.se/) database of Swedish municipal and
  regional Key Performance Indicators
- [rTrafa](https://lchansson.github.io/rTrafa/) — R client for the
  [Trafa](https://api.trafa.se/) API of Swedish transport statistics
