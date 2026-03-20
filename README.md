# rpx <img src="man/figures/logo.png" align="right" height="139" alt="" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/lchansson/rpx/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/lchansson/rpx/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

rpx is an R client for [PX-Web](https://www.scb.se/px-web) statistical APIs. It provides a pipe-friendly, tibble-based interface for discovering and downloading data from national statistics agencies — including SCB (Sweden), SSB (Norway), Statistics Finland, and more.

## Installation

Install the development version from GitHub:

```r
# install.packages("pak")
pak::pak("lchansson/rpx")
```

## Quick start

```r
library(rpx)

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
- **Persistent caching**: Cache responses to disk with `rpx_cache_dir()`
- **v1 and v2 support**: Works with both PX-Web API versions

## Related packages

- [rKolada](https://lchansson.github.io/rKolada/) — R client for the Kolada API (Swedish municipality statistics)
- [pxweb](https://cran.r-project.org/package=pxweb) — another PX-Web client for R

## License

AGPL (>= 3)
