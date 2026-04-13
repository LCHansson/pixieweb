# Package index

## Connect to a PX-Web API

Create API connection objects and check availability.

- [`px_api()`](https://lchansson.github.io/pixieweb/reference/px_api.md)
  [`print(`*`<px_api>`*`)`](https://lchansson.github.io/pixieweb/reference/px_api.md)
  [`format(`*`<px_api>`*`)`](https://lchansson.github.io/pixieweb/reference/px_api.md)
  : Connect to a PX-Web API
- [`px_api_catalogue()`](https://lchansson.github.io/pixieweb/reference/px_api_catalogue.md)
  : List known PX-Web API instances
- [`px_available()`](https://lchansson.github.io/pixieweb/reference/px_available.md)
  : Check if a PX-Web API is reachable

## Discover tables

Search, inspect, and filter statistical tables.

- [`get_tables()`](https://lchansson.github.io/pixieweb/reference/get_tables.md)
  : Get tables from a PX-Web API
- [`table_search()`](https://lchansson.github.io/pixieweb/reference/table_search.md)
  : Client-side search on a table tibble
- [`table_describe()`](https://lchansson.github.io/pixieweb/reference/table_describe.md)
  : Print human-readable table summaries
- [`table_enrich()`](https://lchansson.github.io/pixieweb/reference/table_enrich.md)
  : Enrich a table tibble with full metadata
- [`table_minimize()`](https://lchansson.github.io/pixieweb/reference/table_minimize.md)
  : Remove monotonous columns from a table tibble
- [`table_extract_ids()`](https://lchansson.github.io/pixieweb/reference/table_extract_ids.md)
  : Extract table IDs from a table tibble

## Explore variables

Examine dimensions and available values within a table.

- [`get_variables()`](https://lchansson.github.io/pixieweb/reference/get_variables.md)
  : Get variables (dimensions) for a table
- [`variable_search()`](https://lchansson.github.io/pixieweb/reference/variable_search.md)
  : Client-side search on a variable tibble
- [`variable_describe()`](https://lchansson.github.io/pixieweb/reference/variable_describe.md)
  : Print human-readable variable summaries
- [`variable_minimize()`](https://lchansson.github.io/pixieweb/reference/variable_minimize.md)
  : Remove nested columns for a compact variable overview
- [`variable_extract_ids()`](https://lchansson.github.io/pixieweb/reference/variable_extract_ids.md)
  : Extract variable codes from a variable tibble
- [`variable_values()`](https://lchansson.github.io/pixieweb/reference/variable_values.md)
  : Extract values for a specific variable
- [`variable_name_to_code()`](https://lchansson.github.io/pixieweb/reference/variable_name_to_code.md)
  : Convert variable names to codes

## Codelists

Alternative groupings and aggregations of variable values.

- [`get_codelists()`](https://lchansson.github.io/pixieweb/reference/get_codelists.md)
  : Get codelists for a variable in a table
- [`codelist_describe()`](https://lchansson.github.io/pixieweb/reference/codelist_describe.md)
  : Print human-readable codelist summaries
- [`codelist_extract_ids()`](https://lchansson.github.io/pixieweb/reference/codelist_extract_ids.md)
  : Extract codelist IDs
- [`codelist_values()`](https://lchansson.github.io/pixieweb/reference/codelist_values.md)
  : Extract values for a specific codelist

## Prepare and fetch data

Build queries with smart defaults and download data.

- [`prepare_query()`](https://lchansson.github.io/pixieweb/reference/prepare_query.md)
  [`print(`*`<px_query>`*`)`](https://lchansson.github.io/pixieweb/reference/prepare_query.md)
  : Prepare a data query with smart defaults
- [`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md)
  : Fetch data from a PX-Web table
- [`px_all()`](https://lchansson.github.io/pixieweb/reference/px_selections.md)
  [`px_top()`](https://lchansson.github.io/pixieweb/reference/px_selections.md)
  [`px_bottom()`](https://lchansson.github.io/pixieweb/reference/px_selections.md)
  [`px_from()`](https://lchansson.github.io/pixieweb/reference/px_selections.md)
  [`px_to()`](https://lchansson.github.io/pixieweb/reference/px_selections.md)
  [`px_range()`](https://lchansson.github.io/pixieweb/reference/px_selections.md)
  [`print(`*`<px_selection>`*`)`](https://lchansson.github.io/pixieweb/reference/px_selections.md)
  : Create a PX-Web selection object

## Data utilities

Post-processing helpers for downloaded data.

- [`data_minimize()`](https://lchansson.github.io/pixieweb/reference/data_minimize.md)
  : Remove monotonous columns from a data tibble
- [`data_legend()`](https://lchansson.github.io/pixieweb/reference/data_legend.md)
  : Generate a source caption for plots
- [`data_comments()`](https://lchansson.github.io/pixieweb/reference/data_comments.md)
  : Extract comments from data
- [`px_cite()`](https://lchansson.github.io/pixieweb/reference/px_cite.md)
  : Generate a citation for downloaded data

## Advanced query composition

Low-level functions for building and executing raw API queries.

- [`compose_table_query()`](https://lchansson.github.io/pixieweb/reference/compose_table_query.md)
  : Compose a table query URL
- [`compose_data_query()`](https://lchansson.github.io/pixieweb/reference/compose_data_query.md)
  : Compose a data query
- [`execute_query()`](https://lchansson.github.io/pixieweb/reference/execute_query.md)
  : Execute a composed query
- [`get_saved_query()`](https://lchansson.github.io/pixieweb/reference/get_saved_query.md)
  : Execute a saved query
- [`save_query()`](https://lchansson.github.io/pixieweb/reference/save_query.md)
  : Save a query on the server

## Cache management

- [`pixieweb_cache_dir()`](https://lchansson.github.io/pixieweb/reference/pixieweb_cache_dir.md)
  : Get the persistent pixieweb cache directory
- [`pixieweb_clear_cache()`](https://lchansson.github.io/pixieweb/reference/pixieweb_clear_cache.md)
  : Clear pixieweb cache files
