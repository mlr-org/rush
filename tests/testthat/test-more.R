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

test_that("a segfault on a worker is detected via the heartbeat", {
  config = start_flush_redis()
  rush = rsh(network_id = "test-rush", config = config)
  expect_data_table(rush$worker_info, nrows = 0)

  worker_loop = function(rush) {
    while(TRUE) {
      Sys.sleep(1)
      xs = list(x1 = 1, x2 = 2)
      key = rush$push_running_tasks(list(xs))
      get("attach")(structure(list(), class = "UserDefinedDatabase"))
    }
  }

  rush$worker_script(
    worker_loop = worker_loop,
    heartbeat_period = 1,
    heartbeat_expire = 2,
    lgr_thresholds = c("mlr3/rush" = "debug"))

  px = processx::process$new("Rscript",
    args = c("-e", "rush::start_worker(network_id = 'test-rush', config = list(url = 'redis://127.0.0.1:6379', scheme = 'redis', host = '127.0.0.1', port = '6379'), remote = TRUE, lgr_thresholds = c('mlr3/rush' = 'debug'), lgr_buffer_size = 0, heartbeat_period = 1, heartbeat_expire = 2)"),
    supervise = TRUE,
    stderr = "|", stdout = "|")

  on.exit({
    px$kill()
  }, add = TRUE)

  Sys.sleep(10)

  expect_null(rush$lost_worker_ids)
  rush$detect_lost_workers()
  expect_string(rush$lost_worker_ids)

  expect_rush_reset(rush)
})

test_that("segfaults on workers are detected via the heartbeat", {
  config = start_flush_redis()
  rush = rsh(network_id = "test-rush", config = config)
  expect_data_table(rush$worker_info, nrows = 0)

  worker_loop = function(rush) {
    while(TRUE) {
      Sys.sleep(1)
      xs = list(x1 = 1, x2 = 2)
      key = rush$push_running_tasks(list(xs))
      get("attach")(structure(list(), class = "UserDefinedDatabase"))
    }
  }

  rush$worker_script(
    worker_loop = worker_loop,
    heartbeat_period = 1,
    heartbeat_expire = 2,
    lgr_thresholds = c("mlr3/rush" = "debug"))

  px_1 = processx::process$new("Rscript",
    args = c("-e", "rush::start_worker(network_id = 'test-rush', config = list(url = 'redis://127.0.0.1:6379', scheme = 'redis', host = '127.0.0.1', port = '6379'), remote = TRUE, lgr_thresholds = c('mlr3/rush' = 'debug'), lgr_buffer_size = 0, heartbeat_period = 1, heartbeat_expire = 2)"),
    supervise = TRUE,
    stderr = "|", stdout = "|")

  px_2 = processx::process$new("Rscript",
    args = c("-e", "rush::start_worker(network_id = 'test-rush', config = list(url = 'redis://127.0.0.1:6379', scheme = 'redis', host = '127.0.0.1', port = '6379'), remote = TRUE, lgr_thresholds = c('mlr3/rush' = 'debug'), lgr_buffer_size = 0, heartbeat_period = 1, heartbeat_expire = 2)"),
    supervise = TRUE,
    stderr = "|", stdout = "|")

  on.exit({
    px_1$kill()
    px_2$kill()
  }, add = TRUE)

  Sys.sleep(10)

  expect_null(rush$lost_worker_ids)
  rush$detect_lost_workers()
  expect_character(rush$lost_worker_ids, len = 2)

  expect_rush_reset(rush)
})
