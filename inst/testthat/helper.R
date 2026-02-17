skip_if_no_redis = function() {
  testthat::skip_on_cran()

  if (identical(Sys.getenv("RUSH_TEST_USE_REDIS"), "true") && redux::redis_available()) {
    return(invisible())
  }

  testthat::skip("Redis is not available")
}

redis_configuration = function() {
  config = redux::redis_config()
  r = redux::hiredis(config)
  r$FLUSHDB()
  config
}

start_rush = function(n_workers = 2) {
  config = redis_configuration()

  rush::rush_plan(n_workers = n_workers)
  rush = rush::rsh(config = config)

  mirai::daemons(n_workers)

  rush
}

start_rush_worker = function(n_workers = 2) {
  config = redis_configuration()

  network_id = uuid::UUIDgenerate()
  rush::RushWorker$new(network_id = network_id, config = config)
}

# parses the string returned by rush$worker_script() and starts a processx process
start_script_worker = function(script) {
  script = sub('^Rscript\\s+-e\\s+\\"(.*)\\"$', '\\1', script, perl = TRUE)

  px = processx::process$new("Rscript",
    args = c("-e", script),
    supervise = TRUE,
    stderr = "|", stdout = "|")
  px
}
