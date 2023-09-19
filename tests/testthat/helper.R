start_flush_redis = function() {
  future::plan("sequential")
  config = redux::redis_config()
  r = redux::hiredis(config)
  r$FLUSHDB()
  config
}

initialize_default_rush = function(config) {
  rush = Rush$new(instance_id = "test-rush", config = config)
  future::plan("multisession", workers = 2)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  rush$start_workers(fun)
  rush
}

expect_task = function(task) {
  expect_list(task)
  expect_names(names(task), must.include = c("key", "xs"))
  expect_list(task, names = "unique")
}

