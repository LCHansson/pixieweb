# pixieweb <img src="man/figures/logo.png" align="right" height="139" alt="" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/lchansson/pixieweb/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/lchansson/pixieweb/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

pixieweb is an R client for [PX-Web](https://www.scb.se/px-web) statistical APIs. It provides a pipe-friendly, tibble-based interface for discovering and downloading data from national statistics agencies — including SCB (Sweden), SSB (Norway), Statistics Finland, and more.

> **Note on pxweb:** The excellent [pxweb](https://cran.r-project.org/package=pxweb) package by
> rOpenGov already provides comprehensive R access to PX-Web APIs.
> pixieweb is not a replacement — it offers an *alternative paradigm*
> built around search-then-fetch discovery and progressive disclosure.
> If you already use pxweb and it works for you, there is no need to
> switch. Choose the workflow that fits your needs.

## Installation

Install the development version from GitHub:

```r
# install.packages("pak")
pak::pak("lchansson/pixieweb")
```

## Quick start

```r
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

- **Search-then-fetch workflow**: Discover tables, inspect variables, then download data
- **Multiple APIs**: Built-in catalogue of Nordic and European statistical agencies
- **Selection helpers**: `px_all()`, `px_top()`, `px_bottom()`, `px_from()`, `px_to()`, `px_range()` for concise variable selections
- **Automatic chunking**: Large queries are split and rate-limited automatically
- **Persistent caching**: Cache responses to disk with `pixieweb_cache_dir()`
- **v1 and v2 support**: Works with both PX-Web API versions

## Related packages

- [rKolada](https://lchansson.github.io/rKolada/) — R client for the Kolada API (Swedish municipality statistics). Sibling package with the same design principles.
- [pxweb](https://cran.r-project.org/package=pxweb) — the original and established PX-Web client for R, by rOpenGov

## License

AGPL (>= 3)
