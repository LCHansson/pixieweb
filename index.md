# pixieweb ![](reference/figures/logo.png)

[`pixieweb`](https://lchansson.github.io/pixieweb/index.html) is an R
client for [PX-Web](https://www.scb.se/px-web) statistical APIs. It
provides a pipe-friendly, tibble-based interface for *discovering*,
*inspecting* and *downloading* data from national statistics agencies —
including SCB (Sweden), SSB (Norway), Statistics Finland, and more.

To learn more about using `pixieweb`, it is recommended you use the
following resources in order:

## Getting started with pixieweb

1.  To get up and running quickly with pixieweb, please see the vignette
    [A quick start guide to
    pixieweb](https://lchansson.github.io/pixieweb/articles/a-quickstart.html).
2.  For an introduction to pixieweb and the design principles of
    functions included, please see [Introduction to
    pixieweb](https://lchansson.github.io/pixieweb/articles/introduction-to-pixieweb.html).
3.  For cross-country comparisons and multi-API workflows, see [Working
    with multiple
    APIs](https://lchansson.github.io/pixieweb/articles/multi-api.html).
4.  See the [Reference section of the package
    homepage](https://lchansson.github.io/pixieweb/reference/index.html)
    to learn about the full set of functionality included with the
    package.

`pixieweb` is open source licensed under the Affero Gnu Public License
version 3. This means you are free to download the source, modify and
redistribute it as you please, but any copies or modifications must
retain the original license. Please see the file LICENSE.md for further
information.

> **Note on pxweb:** The excellent
> [pxweb](https://cran.r-project.org/package=pxweb) package by rOpenGov
> already provides comprehensive R access to PX-Web APIs. pixieweb is
> not a replacement — it offers an *alternative paradigm* built around
> search-then-fetch discovery and progressive disclosure. If you already
> use pxweb and it works for you, there is no need to switch. Choose the
> workflow that fits your needs.

## Installation

pixieweb is on CRAN. To install it, run the following code in R:

``` r
install.packages("pixieweb")
```

To install the latest development version from GitHub, use the `remotes`
package:

``` r
library("remotes")
remotes::install_github("LCHansson/pixieweb")
```

## Quick start

``` r
library(pixieweb)

# Connect to Statistics Sweden
scb <- px_api("scb", lang = "en")

# Search for tables about population
tables <- get_tables(scb, query = "population")

# Inspect variables in a table
vars <- get_variables(scb, tables$id[1])

# Download data
data <- get_data(scb, tables$id[1])
```

## Features

- **Search-then-fetch workflow**: Discover tables, inspect variables,
  then download data
- **Multiple APIs**: Built-in catalogue of Nordic and European
  statistical agencies
- **Selection helpers**:
  [`px_all()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
  [`px_top()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
  [`px_bottom()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
  [`px_from()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
  [`px_to()`](https://lchansson.github.io/pixieweb/reference/px_selections.md),
  [`px_range()`](https://lchansson.github.io/pixieweb/reference/px_selections.md)
  for concise variable selections
- **Automatic chunking**: Large queries are split and rate-limited
  automatically
- **Persistent caching**: Cache responses to disk with
  [`pixieweb_cache_dir()`](https://lchansson.github.io/pixieweb/reference/pixieweb_cache_dir.md)
- **v1 and v2 support**: Works with both PX-Web API versions

## Enhanced caching with nordstatExtras

For multi-user web applications or workflows that benefit from a shared,
persistent cache, pixieweb integrates with the
[nordstatExtras](https://github.com/LCHansson/nordstatExtras) package.
When installed,
[`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md),
[`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md),
[`table_enrich()`](https://lchansson.github.io/pixieweb/reference/table_enrich.md),
and other functions can write to a shared SQLite file instead of
per-session `.rds` files:

``` r
# install.packages("devtools")
devtools::install_github("LCHansson/nordstatExtras")

library(nordstatExtras)
handle <- nxt_open("cache.sqlite")

scb <- px_api("scb")

# Metadata and data cached in the same SQLite file
tables <- get_tables(scb, cache = TRUE, cache_location = handle)
data <- get_data(scb, "TAB638",
  Region = c("0180", "1480"),
  cache = TRUE, cache_location = handle
)

# table_enrich with per-table caching + async support
enriched <- table_enrich(tables, cache = TRUE,
                         cache_location = handle)

nxt_close(handle)
```

Features include cell-level deduplication across overlapping queries,
per-table incremental enrichment with resume-on-crash, async background
fetching via `mirai`, and FTS5-powered typeahead search via
[`nxt_search()`](https://rdrr.io/pkg/nordstatExtras/man/nxt_search.html).
See the [nordstatExtras
README](https://github.com/LCHansson/nordstatExtras) for details.

## Contributing

You are welcome to contribute to the further development of the pixieweb
package in any of the following ways:

- Open an [issue](https://github.com/LCHansson/pixieweb/issues)
- Clone this repo, make modifications and create a pull request
- Spread the word!

## Related packages

`pixieweb` is part of a family of R packages for Swedish and Nordic open
statistics that share the same design philosophy — tibble-based,
pipe-friendly, and offline-safe:

- [rKolada](https://lchansson.github.io/rKolada/) — R client for the
  [Kolada](https://kolada.se/) database of Swedish municipal and
  regional Key Performance Indicators
- [rTrafa](https://lchansson.github.io/rTrafa/) — R client for the
  [Trafa](https://api.trafa.se/) API of Swedish transport statistics

See also [pxweb](https://cran.r-project.org/package=pxweb) — the
original and established PX-Web client for R, by rOpenGov.

### Code of Conduct

Please note that the pixieweb project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/0/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.

## License

AGPL (\>= 3)
