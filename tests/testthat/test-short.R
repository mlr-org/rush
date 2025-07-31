test_that("a local worker is killed", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(network_id = "test-rush", config = config)
  worker_ids = rush$start_local_workers(
      worker_loop = test_worker_loop,
      n_workers = 2,
      lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(2, timeout = 5)

  worker_id_1 = rush$running_worker_ids[1]
  worker_id_2 = rush$running_worker_ids[2]

  rush$worker_info

  # worker 1
  rush$stop_workers(worker_ids = worker_id_1, type = "kill")
  Sys.sleep(1)
  expect_equal(worker_id_1, rush$killed_worker_ids)
  expect_false(rush$processes_processx[[worker_id_1]]$is_alive())
  expect_true(rush$processes_processx[[worker_id_2]]$is_alive())

  # worker 2
  rush$stop_workers(worker_ids = worker_id_2, type = "kill")
  Sys.sleep(1)
  expect_set_equal(c(worker_id_1, worker_id_2), rush$killed_worker_ids)
  expect_false(rush$processes_processx[[worker_id_1]]$is_alive())
  expect_false(rush$processes_processx[[worker_id_2]]$is_alive())

  expect_rush_reset(rush)
})

test_that("a mirai worker is killed", {
  skip_on_cran()

  config = start_flush_redis()
  mirai::daemons(2)
  rush = rsh(network_id = "test-rush", config = config)
  worker_ids = rush$start_remote_workers(
      worker_loop = test_worker_loop,
      n_workers = 2,
      lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(2, timeout = 5)

  worker_id_1 = rush$running_worker_ids[1]
  worker_id_2 = rush$running_worker_ids[2]
  worker_info = rush$worker_info
  expect_true(all(tools::pskill(worker_info$pid, signal = 0L)))

  # worker 1
  rush$stop_workers(worker_ids = worker_id_1, type = "kill")
  Sys.sleep(1)
  expect_equal(worker_id_1, rush$killed_worker_ids)
  expect_equal(rush$running_worker_ids, worker_id_2)

  expect_true(mirai::is_error_value(rush$processes_mirai[[worker_id_1]]$data))
  expect_false(mirai::is_error_value(rush$processes_mirai[[worker_id_2]]$data))

  # worker 2
  rush$stop_workers(worker_ids = worker_id_2, type = "kill")
  Sys.sleep(1)
  expect_set_equal(c(worker_id_1, worker_id_2), rush$killed_worker_ids)

  expect_true(mirai::is_error_value(rush$processes_mirai[[worker_id_1]]$data))
  expect_true(mirai::is_error_value(rush$processes_mirai[[worker_id_2]]$data))

  expect_rush_reset(rush)
  daemons(0)
})

test_that("a simple error is catched", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(network_id = "test-rush", config = config)

  worker_loop = function(rush) {
    while(!rush$terminated && !rush$terminated_on_idle) {
      task = rush$pop_task(fields = c("xs", "seed"))
      if (!is.null(task)) {
        tryCatch({
          fun = function(x1, x2, ...) {
            if (x1 < 1) stop("Test error")
            list(y = x1 + x2)
          }
          ys = with_rng_state(fun, args = c(task$xs), seed = task$seed)
          rush$push_results(task$key, yss = list(ys))
        }, error = function(e) {
          condition = list(message = e$message)
          rush$push_failed(task$key, conditions = list(condition))
        })
      }
    }

    return(NULL)
  }

  on.exit({
    mirai::daemons(0)
  }, add = TRUE)

  mirai::daemons(1)

  worker_ids = rush$start_remote_workers(
    worker_loop = worker_loop,
    n_workers = 1,
    lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(1, timeout = 5)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys, detect_lost_workers = TRUE)
  Sys.sleep(2)

  # check task count
  expect_equal(rush$n_tasks, 2)
  expect_equal(rush$n_queued_tasks, 0)
  expect_equal(rush$n_running_tasks, 0)
  expect_equal(rush$n_finished_tasks, 1)
  expect_equal(rush$n_failed_tasks, 1)

  # check keys in sets
  expect_character(rush$tasks, len = 2)
  expect_null(rush$queued_tasks)
  expect_null(rush$running_tasks)
  expect_string(rush$finished_tasks)
  expect_string(rush$failed_tasks)

  # check fetching
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_running_tasks(), nrows = 0)
  expect_data_table(rush$fetch_tasks(), nrows = 2)

  data = rush$fetch_finished_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "y", "keys"))
  expect_data_table(data, nrows = 1)

  data = rush$fetch_failed_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "message", "keys"))
  expect_data_table(data, nrows = 1)

  expect_rush_reset(rush)
})
