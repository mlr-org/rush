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

# starts one set of daemons per compute profile, e.g. `start_rush_profiles(c(cpu = 2, gpu = 1))`
start_rush_profiles = function(profiles) {
  config = redis_configuration()

  rush::rush_plan(profiles = profiles)
  rush = rush::rsh(config = config)

  for (profile in names(profiles)) {
    mirai::daemons(profiles[[profile]], .compute = profile)
  }

  rush
}

# shuts down the daemons of every compute profile started by `start_rush_profiles()`
stop_rush_profiles = function(profiles) {
  for (profile in names(profiles)) {
    mirai::daemons(0, .compute = profile)
  }
}

start_rush_worker = function() {
  config = redis_configuration()

  network_id = uuid::UUIDgenerate()
  rush::RushWorker$new(network_id = network_id, config = config)
}

# runs the string returned by rush$worker_script() through a POSIX shell like a user would
# exec replaces the shell with Rscript, so the process handle points at the worker itself
start_script_worker = function(script) {
  px = processx::process$new("sh",
    args = c("-c", paste("exec", script)),
    supervise = TRUE,
    stderr = "|", stdout = "|")
  px
}
