start_flush_redis = function() {
  config = redux::redis_config()
  r = redux::hiredis(config)
  r$FLUSHDB()
  config
}

expect_rush_task = function(task) {
  expect_list(task)
  expect_names(names(task), must.include = c("key", "xs"))
  expect_list(task, names = "unique")
}

expect_rush_reset = function(rush, type = "kill") {
  remove_rush_plan()
  processes = rush$processes
  rush$reset(type = type)
  expect_list(rush$connector$command(c("KEYS", "*")), len = 0)
  walk(processes, function(p) p$kill())
}
