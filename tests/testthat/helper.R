start_flush_redis = function() {
  future::plan("sequential")
  config = redux::redis_config()
  r = redux::hiredis(config)
  r$FLUSHDB()
  config
}

expect_task = function(task) {
  expect_list(task)
  expect_names(names(task), must.include = c("key", "xs"))
  expect_list(task, names = "unique")
}

expect_reset_rush = function(rush) {
  rush$reset()
  expect_list(rush$connector$command(c("KEYS", "*")), len = 0)
}

expect_stopped_workers = function(pids) {
  pid_exists = choose_pid_exists()
  walk(pids, function(pid) {
    expect_false(pid_exists(pid))
  })
}

clean_test_env = function(pids) {
  walk(pids, tools::pskill)
  future::plan("sequential")
}

lg$set_threshold(0)

