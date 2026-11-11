# Get the unit and measurement properties of a table's contents

Returns one row per value of the table's contents variable (the
measures), with the unit the source states for it. The unit is the fact
a number cannot be read without (`tkr` or `mnkr`?), and it is not part
of what
[`get_variables()`](https://lchansson.github.io/pixieweb/reference/get_variables.md)
returns.

## Usage

``` r
get_contents(api, table_id, verbose = FALSE)
```

## Arguments

- api:

  A `<px_api>` object.

- table_id:

  A single table ID (character).

- verbose:

  Print request details.

## Value

A tibble with columns `table_id`, `variable` (the code of the contents
variable), `code`, `text`, `unit`, `decimals`, `measuring_type`,
`price_type`, `adjustment`, `refperiod` and `base_period`; or `NULL`
when the API could not be reached.

## Details

For a v2 API the table metadata carries the unit, together with the
measuring type (stock or flow), price type (current or fixed), seasonal
adjustment and reference period where the source states them. One
request.

A v1 API states no unit in its table metadata, but answers a data
request in json-stat2 form with the same block. `get_contents()`
therefore asks for a single cell in that form, and once more for every
value of the contents variable when there are several: at most two small
data requests on top of the metadata. A v1 table without a contents
variable, or an instance that does not serve json-stat2, gives zero rows
or `NULL`; a field the source does not state is `NA`.

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {
  get_contents(scb, "TAB638")
}# }
#> # A tibble: 2 × 11
#>   table_id variable     code     text   unit  decimals measuring_type price_type
#>   <chr>    <chr>        <chr>    <chr>  <chr>    <int> <chr>          <chr>     
#> 1 TAB638   ContentsCode BE0101N1 Popul… numb…        0 Stock          NotApplic…
#> 2 TAB638   ContentsCode BE0101N2 Popul… numb…        0 Flow           NotApplic…
#> # ℹ 3 more variables: adjustment <chr>, refperiod <chr>, base_period <chr>
```
