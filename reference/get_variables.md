# Get variables (dimensions) for a table

Retrieves the variable structure of a PX-Web table, including available
values and codelists. This is the key discovery step before fetching
data.

## Usage

``` r
get_variables(
  api,
  table_id,
  cache = FALSE,
  cache_location = pixieweb_cache_dir,
  verbose = FALSE
)
```

## Arguments

- api:

  A `<px_api>` object.

- table_id:

  A single table ID (character).

- cache:

  Logical, cache results locally. When combined with a sqlite
  `cache_location` (an `nxt_handle` from nordstatExtras), the response
  is stored in the shared multi-process cache; otherwise a legacy `.rds`
  file is written under
  [`pixieweb_cache_dir()`](https://lchansson.github.io/pixieweb/reference/pixieweb_cache_dir.md).

- cache_location:

  Either a path to a `.sqlite` file / `nxt_handle`, or a directory for
  legacy `.rds` caching. Defaults to
  [`pixieweb_cache_dir()`](https://lchansson.github.io/pixieweb/reference/pixieweb_cache_dir.md).

- verbose:

  Print request details.

## Value

A tibble with columns: `code`, `text`, `n_values`, `elimination`,
`time`, `values`, `codelists`, `table_id`.

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {
  get_variables(scb, "TAB638")
}# }
#> # A tibble: 6 × 8
#>   code         text       n_values elimination time  values   codelists table_id
#>   <chr>        <chr>         <int> <lgl>       <lgl> <list>   <list>    <chr>   
#> 1 Region       region          312 TRUE        FALSE <tibble> <tibble>  TAB638  
#> 2 Civilstand   marital s…        4 TRUE        FALSE <tibble> <NULL>    TAB638  
#> 3 Alder        age             102 TRUE        FALSE <tibble> <tibble>  TAB638  
#> 4 Kon          sex               2 TRUE        FALSE <tibble> <NULL>    TAB638  
#> 5 ContentsCode observati…        2 FALSE       FALSE <tibble> <NULL>    TAB638  
#> 6 Tid          year             57 FALSE       TRUE  <tibble> <NULL>    TAB638  
```
