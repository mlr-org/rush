skip_if_no_redis()

# test_that("rush_plan family works", {
#   skip_on_cran()

#   on.exit(remove_rush_plan())

#   expect_false(rush_available())
#   config = redux::redis_config()
#   rush_plan(n_workers = 2, config)
#   expect_identical(config, rush_env$config)
#   expect_identical(rush_config()$config, config)
#   expect_equal(rush_env$n_workers, 2)
#   expect_equal(rush_config()$n_workers, 2)
#   expect_true(rush_available())
# })

test_that("rush_plan throws and error if redis is not available", {
  on.exit(remove_rush_plan())

  config = redux::redis_config(url = "redis://localhost:1234")
  expect_error(rush_plan(n_workers = 2, config), class = "Mlr3ErrorConfig")
})

test_that("start workers", {
  on.exit({
    rush$reset()
    remove_rush_plan()
    mirai::daemons(0)
  })

  config = redis_configuration()
  rush_plan(n_workers = 1, config)
  mirai::daemons(1)

  expect_equal(rush_env$n_workers, 1)

  rush = rsh("test-rush")
  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 1)
  rush$wait_for_workers(1, timeout = 5)

  expect_equal(rush$n_running_workers, 1)
})

test_that("set threshold", {
  config = redis_configuration()
  mirai::daemons(2)
  on.exit({
    rush$reset()
    remove_rush_plan()
    mirai::daemons(0)
  })

  lg_rush = lgr::get_logger("mlr3/rush")
  old_threshold_rush = lg_rush$threshold
  on.exit(lg_rush$set_threshold(old_threshold_rush))
  lg_rush$set_threshold("debug")

  rush_plan(n_workers = 2, config, lgr_thresholds = c("mlr3/rush" = "debug"))

  expect_equal(rush_env$n_workers, 2)
  expect_equal(rush_env$lgr_thresholds, c("mlr3/rush" = "debug"))

  rush = rsh("test-rush")
  expect_output(rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 2,
    wait_for_workers = TRUE),
  "Pushing.*")

  Sys.sleep(2)
})

