test_that("rush_plan", {
  expect_false(rush_available())
  config = redis_config()
  rush_plan(config)
  expect_identical(config, rush_env$config)
  expect_true(rush_available())
})

test_that("start workers", {
  config = redux::redis_config()
  rush_plan(config, 2)

  rush = rsh("test-rush")
  fun = function(x1, x2, ...) list(y = x1 + x2)
  rush$start_workers(fun = fun)

  expect_equal(rush$n_running_workers, 2)

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})
