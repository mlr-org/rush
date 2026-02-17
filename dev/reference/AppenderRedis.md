# Log to Redis Database

AppenderRedis writes log messages to a Redis data base. This
[lgr::Appender](https://s-fleck.github.io/lgr/reference/Appender.html)
is created internally by
[RushWorker](https://rush.mlr-org.com/dev/reference/RushWorker.md) when
logger thresholds are passed via
[`rush_plan()`](https://rush.mlr-org.com/dev/reference/rush_plan.md).

## Value

Object of class
[R6::R6Class](https://r6.r-lib.org/reference/R6Class.html) and
`AppenderRedis` with methods for writing log events to Redis data bases.

## Super classes

[`lgr::Filterable`](https://s-fleck.github.io/lgr/reference/Filterable.html)
-\>
[`lgr::Appender`](https://s-fleck.github.io/lgr/reference/Appender.html)
-\>
[`lgr::AppenderMemory`](https://s-fleck.github.io/lgr/reference/AppenderMemory.html)
-\> `AppenderRedis`

## Methods

### Public methods

- [`AppenderRedis$new()`](#method-AppenderRedis-new)

- [`AppenderRedis$flush()`](#method-AppenderRedis-flush)

Inherited methods

- [`lgr::Filterable$add_filter()`](https://s-fleck.github.io/lgr/reference/Filterable.html#method-add_filter)
- [`lgr::Filterable$filter()`](https://s-fleck.github.io/lgr/reference/Filterable.html#method-filter)
- [`lgr::Filterable$remove_filter()`](https://s-fleck.github.io/lgr/reference/Filterable.html#method-remove_filter)
- [`lgr::Filterable$set_filters()`](https://s-fleck.github.io/lgr/reference/Filterable.html#method-set_filters)
- [`lgr::Appender$set_layout()`](https://s-fleck.github.io/lgr/reference/Appender.html#method-set_layout)
- [`lgr::Appender$set_threshold()`](https://s-fleck.github.io/lgr/reference/Appender.html#method-set_threshold)
- [`lgr::AppenderMemory$append()`](https://s-fleck.github.io/lgr/reference/AppenderMemory.html#method-append)
- [`lgr::AppenderMemory$clear()`](https://s-fleck.github.io/lgr/reference/AppenderMemory.html#method-clear)
- [`lgr::AppenderMemory$format()`](https://s-fleck.github.io/lgr/reference/AppenderMemory.html#method-format)
- [`lgr::AppenderMemory$set_buffer_size()`](https://s-fleck.github.io/lgr/reference/AppenderMemory.html#method-set_buffer_size)
- [`lgr::AppenderMemory$set_flush_on_exit()`](https://s-fleck.github.io/lgr/reference/AppenderMemory.html#method-set_flush_on_exit)
- [`lgr::AppenderMemory$set_flush_on_rotate()`](https://s-fleck.github.io/lgr/reference/AppenderMemory.html#method-set_flush_on_rotate)
- [`lgr::AppenderMemory$set_flush_threshold()`](https://s-fleck.github.io/lgr/reference/AppenderMemory.html#method-set_flush_threshold)
- [`lgr::AppenderMemory$set_should_flush()`](https://s-fleck.github.io/lgr/reference/AppenderMemory.html#method-set_should_flush)
- [`lgr::AppenderMemory$show()`](https://s-fleck.github.io/lgr/reference/AppenderMemory.html#method-show)

------------------------------------------------------------------------

### Method `new()`

Creates a new instance of this
[R6](https://r6.r-lib.org/reference/R6Class.html) class.

#### Usage

    AppenderRedis$new(
      config,
      key,
      threshold = NA_integer_,
      layout = lgr::LayoutJson$new(timestamp_fmt = "%Y-%m-%d %H:%M:%OS3"),
      buffer_size = 0,
      flush_threshold = "error",
      flush_on_exit = TRUE,
      flush_on_rotate = TRUE,
      should_flush = NULL,
      filters = NULL
    )

#### Arguments

- `config`:

  ([redux::redis_config](https://richfitz.github.io/redux/reference/redis_config.html))  
  Redis configuration options.

- `key`:

  (`character(1)`)  
  Key of the list holding the log messages in the Redis data store.

- `threshold`:

  (`integer(1)` \| `character(1)`)  
  Threshold for the log messages.

- `layout`:

  ([lgr::Layout](https://s-fleck.github.io/lgr/reference/Layout.html))  
  Layout for the log messages.

- `buffer_size`:

  (`integer(1)`)  
  Size of the buffer.

- `flush_threshold`:

  (`character(1)`)  
  Threshold for flushing the buffer.

- `flush_on_exit`:

  (`logical(1)`)  
  Flush the buffer on exit.

- `flush_on_rotate`:

  (`logical(1)`)  
  Flush the buffer on rotate.

- `should_flush`:

  (`function`)  
  Function that determines if the buffer should be flushed.

- `filters`:

  (`list`)  
  List of filters.

------------------------------------------------------------------------

### Method [`flush()`](https://rdrr.io/r/base/connections.html)

Sends the buffer's contents to the Redis data store, and then clears the
buffer.

#### Usage

    AppenderRedis$flush()

## Examples

``` r
# This example is not executed since Redis must be installed
# \donttest{
   config_local = redux::redis_config()

   rush_plan(
     config = config_local,
     n_workers = 2,
     lgr_thresholds = c(rush = "info"))

   rush = rsh(network_id = "test_network")
   rush
#> 
#> ── <Rush> ──────────────────────────────────────────────────────────────────────
#> • Running Workers: 0
#> • Queued Tasks: 0
#> • Running Tasks: 0
#> • Finished Tasks: 0
#> • Failed Tasks: 0
# }
```
