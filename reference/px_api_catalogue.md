# List known PX-Web API instances

Returns a tibble of known PX-Web APIs with their aliases, URLs,
supported versions, and available languages.

## Usage

``` r
px_api_catalogue()
```

## Value

A tibble with columns: `alias`, `description`, `url`, `url_v1`,
`versions`, `langs`, `default_lang`.

## Examples

``` r
px_api_catalogue()
#> # A tibble: 14 × 7
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
#> 14 tva      Swedish Agency for Growth … http… https… <chr>    <chr> sv          
```
