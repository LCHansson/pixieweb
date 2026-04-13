# Generate a source caption for plots

Builds a human-readable source attribution string from a data tibble
returned by
[`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md)
and, optionally, a variable tibble returned by
[`get_variables()`](https://lchansson.github.io/pixieweb/reference/get_variables.md).
The string is suitable for use as a `caption` in
[`ggplot2::labs()`](https://ggplot2.tidyverse.org/reference/labs.html).

## Usage

``` r
data_legend(
  data_df,
  var_df = NULL,
  lang = NULL,
  omit_varname = FALSE,
  omit_desc = FALSE
)
```

## Arguments

- data_df:

  A tibble returned by
  [`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md).

- var_df:

  Optional tibble returned by
  [`get_variables()`](https://lchansson.github.io/pixieweb/reference/get_variables.md).
  If supplied, a line listing the table's variables is added below the
  source line.

- lang:

  Language for the caption wording: `"EN"` (English, default) or `"SV"`
  (Swedish). Defaults to `getOption("pixieweb.lang", "EN")`. PX-Web
  variable labels are returned by the API in whichever language was
  requested in
  [`px_api()`](https://lchansson.github.io/pixieweb/reference/px_api.md)
  regardless of this setting.

- omit_varname:

  Logical. If `TRUE`, omit the raw variable codes (the parenthesised IDs
  like `Region`) and show only the labels.

- omit_desc:

  Logical. If `TRUE`, omit the human-readable labels and show only the
  codes.

## Value

A single character string suitable for plot captions.

## Details

By default the caption shows the API and table that the data came from,
and — if `var_df` is supplied — the variables included in the table with
both a human-readable label and the raw code, e.g.

    Source: Statistics Sweden (SCB), table TAB638
    Region (Region) | Marital status (Civilstand) | Year (Tid)

Use `omit_varname` to drop the codes, `omit_desc` to drop the labels,
and `lang` to switch between English and Swedish wording of the source
prefix.

## Examples

``` r
# \donttest{
scb <- px_api("scb", lang = "en")
if (px_available(scb)) {
  vars <- get_variables(scb, "TAB638")
  d <- get_data(scb, "TAB638", Region = "0180", Tid = px_top(3))
  data_legend(d, vars)
  data_legend(d, vars, lang = "SV")
  data_legend(d, vars, omit_varname = TRUE)
  data_legend(d, vars, omit_desc = TRUE)
}# }
#> Warning: PX-Web API returned HTTP 400: {"type":"Parameter error","title":"Missing selection for mandantory variable","status":400}
#> [1] "Region | Civilstand | Alder | Kon | ContentsCode | Tid"
```
