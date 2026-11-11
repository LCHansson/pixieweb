# Extract values for a specific codelist

Extract values for a specific codelist

## Usage

``` r
codelist_values(cl_df, codelist_id)
```

## Arguments

- cl_df:

  A tibble returned by
  [`get_codelists()`](https://lchansson.github.io/pixieweb/reference/get_codelists.md).

- codelist_id:

  Codelist ID (character).

## Value

A tibble with columns `code` and `text`.

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {
  cls <- get_codelists(scb, "TAB638", "Region")
  codelist_values(cls, cls$id[1])
}# }
#> # A tibble: 70 × 3
#>    code  text                           value_map 
#>    <chr> <chr>                          <list>    
#>  1 A-01  Stockholms/Södertälje A-region <chr [25]>
#>  2 A-02  Norrtälje A-region             <chr [1]> 
#>  3 A-03  Enköpings A-region             <chr [2]> 
#>  4 A-04  Uppsala A-region               <chr [3]> 
#>  5 A-05  Nyköpings A-region             <chr [4]> 
#>  6 A-06  Katrineholms A-region          <chr [3]> 
#>  7 A-07  Eskilstuna A-region            <chr [2]> 
#>  8 A-08  Mjölby/Motala A-region         <chr [5]> 
#>  9 A-09  Linköpings A-region            <chr [3]> 
#> 10 A-10  Norrköpings A-region           <chr [4]> 
#> # ℹ 60 more rows
```
