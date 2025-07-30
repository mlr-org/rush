test_that("a segfault on a local worker is detected", {
  config = start_flush_redis()
  rush = rsh(network_id = "test-rush", config = config)
  worker_loop = function(rush) {
    while(TRUE) {
      Sys.sleep(1)
      xs = list(x1 = 1, x2 = 2)
      key = rush$push_running_tasks(list(xs))
      get("attach")(structure(list(), class = "UserDefinedDatabase"))
    }
  }

  worker_ids = rush$start_local_workers(
    worker_loop = worker_loop,
    n_workers = 1,
    lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(1, timeout = 5)

  Sys.sleep(3)

  expect_null(rush$lost_worker_ids)
  rush$detect_lost_workers()
  expect_equal(rush$lost_worker_ids, worker_ids)
  rush$fetch_failed_tasks()

  expect_rush_reset(rush)
})

test_that("a segfault on a mirai worker", {
  config = start_flush_redis()
  rush = rsh(network_id = "test-rush", config = config)
  worker_loop = function(rush) {
    while(TRUE) {
      Sys.sleep(1)
      xs = list(x1 = 1, x2 = 2)
      key = rush$push_running_tasks(list(xs))
      get("attach")(structure(list(), class = "UserDefinedDatabase"))
    }
  }

  mirai::daemons(1)
  worker_ids = rush$start_remote_workers(
    worker_loop = worker_loop,
    n_workers = 1,
    lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(1, timeout = 5)

  Sys.sleep(3)

  expect_null(rush$lost_worker_ids)
  rush$detect_lost_workers()
  expect_equal(rush$lost_worker_ids, worker_ids)
  rush$fetch_failed_tasks()

  expect_rush_reset(rush)
})
