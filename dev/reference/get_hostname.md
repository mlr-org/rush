# Get the computer name of the current host

Returns the computer name of the current host. First it tries to get the
computer name from the environment variables `HOST`, `HOSTNAME` or
`COMPUTERNAME`. If this fails it tries to get the computer name from the
function [`Sys.info()`](https://rdrr.io/r/base/Sys.info.html). Finally,
if this fails it queries the computer name from the command `uname -n`.
Copied from the `R.utils` package.

## Usage

``` r
get_hostname()
```

## Value

`character(1)` of hostname.

## Examples

``` r
get_hostname()
#>        nodename 
#> "runnervm6qbrg" 
```
