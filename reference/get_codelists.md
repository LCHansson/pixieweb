# Get codelists for a variable in a table

Codelists provide alternative groupings of variable values (e.g.
municipalities grouped into counties).

## Usage

``` r
get_codelists(api, table_id, variable_code, verbose = FALSE)
```

## Arguments

- api:

  A `<px_api>` object.

- table_id:

  Table ID (character).

- variable_code:

  Variable code (character).

- verbose:

  Print request details.

## Value

A tibble with columns: `id`, `text`, `type`, `values`. For a v2 API it
also has `elimination` and `elimination_value_code` (the codelist's own,
`NA` where not stated), and each nested `values` tibble has, beside
`code` and `text`, the list-column `value_map`: the codes of the table's
variable that the codelist value stands for. For an aggregation
(municipalities into counties) that is the total-to-parts mapping; for a
plain value set each code maps to itself.

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {
  get_codelists(scb, "TAB638", "Region")
}# }
#> # A tibble: 18 × 6
#>    id                    text  type  values   elimination elimination_value_code
#>    <chr>                 <chr> <chr> <list>   <lgl>       <chr>                 
#>  1 agg_RegionA-region_2  A-re… Aggr… <tibble> FALSE       NA                    
#>  2 agg_RegionLA1998      Loca… Aggr… <tibble> FALSE       NA                    
#>  3 agg_RegionLA2003_1    Loca… Aggr… <tibble> FALSE       NA                    
#>  4 agg_RegionLA2008      Loca… Aggr… <tibble> FALSE       NA                    
#>  5 agg_RegionLA2013      Loca… Aggr… <tibble> FALSE       NA                    
#>  6 agg_RegionLA2018      Loca… Aggr… <tibble> FALSE       NA                    
#>  7 agg_RegionStoromr-04… Metr… Aggr… <tibble> FALSE       NA                    
#>  8 agg_RegionStoromr05-… Metr… Aggr… <tibble> FALSE       NA                    
#>  9 agg_RegionNUTS1_2008  NUTS… Aggr… <tibble> FALSE       NA                    
#> 10 agg_RegionNUTS2_2008  NUTS… Aggr… <tibble> FALSE       NA                    
#> 11 agg_RegionNUTS3_2008  NUTS… Aggr… <tibble> FALSE       NA                    
#> 12 agg_RegionKommungrup… Type… Aggr… <tibble> FALSE       NA                    
#> 13 agg_RegionKommungrup… Type… Aggr… <tibble> FALSE       NA                    
#> 14 agg_RegionKommungrup… Type… Aggr… <tibble> FALSE       NA                    
#> 15 agg_RegionKommungrup… Type… Aggr… <tibble> FALSE       NA                    
#> 16 vs_RegionKommun07     Muni… Valu… <tibble> FALSE       NA                    
#> 17 vs_RegionLän07        Coun… Valu… <tibble> FALSE       NA                    
#> 18 vs_RegionRiket99      Swed… Valu… <tibble> TRUE        00                    
```
