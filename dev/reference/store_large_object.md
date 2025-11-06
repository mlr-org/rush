# Store Large Objects

Store large objects to disk and return a reference to the object.

## Usage

``` r
store_large_object(obj, path)
```

## Arguments

- obj:

  (`any`)  
  Object to store.

- path:

  (`character(1)`)  
  Path to store the object.

## Value

[`list()`](https://rdrr.io/r/base/list.html) of class
`"rush_large_object"` with the name and path of the stored object.

## Examples

``` r
obj = list(a = 1, b = 2)
rush_large_object = store_large_object(obj, tempdir())
```
