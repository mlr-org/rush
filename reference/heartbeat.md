# Heartbeat Loop

The heartbeat loop updates the heartbeat key if the worker is still
alive. If the kill key is set, the worker is killed. This function is
called in a callr session.

## Usage

``` r
heartbeat(
  network_id,
  config,
  worker_id,
  heartbeat_key,
  heartbeat_period,
  heartbeat_expire,
  pid
)
```

## Arguments

- network_id:

  (`character(1)`)  
  Identifier of the rush network. Controller and workers must have the
  same instance id. Keys in Redis are prefixed with the instance id.

- config:

  ([redux::redis_config](https://richfitz.github.io/redux/reference/redis_config.html))  
  Redis configuration options.

- worker_id:

  (`character(1)`)  
  Identifier of the worker. Keys in redis specific to the worker are
  prefixed with the worker id.

- heartbeat_key:

  (`character(1)`)  
  Heartbeat key.

- heartbeat_period:

  (`integer(1)`)  
  Period of the heartbeat in seconds. The heartbeat is updated every
  `heartbeat_period` seconds.

- heartbeat_expire:

  (`integer(1)`)  
  Time to live of the heartbeat in seconds. The heartbeat key is set to
  expire after `heartbeat_expire` seconds.

- pid:

  (`integer(1)`)  
  Process ID of the worker.

## Value

`NULL`
