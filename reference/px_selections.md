# Create a PX-Web selection object

These helpers create `<px_selection>` objects that
[`get_data()`](https://lchansson.github.io/pixieweb/reference/get_data.md)
translates into the appropriate API filter. Each represents a different
way to select variable values in PX-Web queries.

## Usage

``` r
px_all(pattern = "*")

px_top(n)

px_bottom(n)

px_from(value)

px_to(value)

px_range(from, to = NULL)

# S3 method for class 'px_selection'
print(x, ...)
```

## Arguments

- pattern:

  Glob pattern (default `"*"` for all).

- n:

  Number of values.

- value:

  Value code (inclusive bound).

- from, to:

  Value codes for range bounds (inclusive).

- x:

  A `<px_selection>` object.

- ...:

  Ignored.

## Value

A `<px_selection>` object.
