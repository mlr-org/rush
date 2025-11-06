# Set RNG Sate before Running a Function

This function sets the rng state before running a function. Use with
caution. The global environment is changed.

## Usage

``` r
with_rng_state(fun, args, seed)
```

## Arguments

- fun:

  (`function`)  
  Function to run.

- args:

  (`list`)  
  Arguments to pass to `fun`.

- seed:

  (`integer`)  
  RNG state to set before running `fun`.

## Value

`any`

## Examples

``` r
with_rng_state(runif, list(n = 1), .Random.seed)
#> [1] 0.9805397
```
