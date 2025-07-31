test_that("local workers are started with Redis on unix socket", {
  #skip_if(TRUE)

  system(sprintf("redis-server --port 0 --unixsocket /tmp/redis.sock --daemonize yes --pidfile /tmp/redis.pid --dir %s", tempdir()))
  Sys.sleep(5)

  config = redux::redis_config(path = "/tmp/redis.sock")
  r = redux::hiredis(config)

  on.exit({
    try({r$SHUTDOWN()}, silent = TRUE)
  })

  r$FLUSHDB()

  rush = rsh(network_id = "test-rush", config = config)
  worker_ids = rush$start_local_workers(
    worker_loop = test_worker_loop,
    n_workers = 2,
    lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(2, timeout = 5)

  # check fields
  walk(rush$processes_processx, function(process) expect_class(process, "process"))

  # check meta data from redis
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 2)
  expect_integer(worker_info$pid, unique = TRUE)
  expect_false(any(worker_info$remote))
  expect_set_equal(worker_ids, worker_info$worker_id)
  expect_set_equal(rush$worker_ids, worker_ids)
  expect_set_equal(rush$worker_states$state, "running")
})

test_that("workers are started with script", {
  # skip_if(TRUE)
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(network_id = "test-rush", config = config)
  expect_data_table(rush$worker_info, nrows = 0)

  rush$worker_script(
    worker_loop = test_worker_loop,
    lgr_thresholds = c("mlr3/rush" = "debug"))

  px = processx::process$new("Rscript",
    args = c("-e", sprintf("rush::start_worker(network_id = 'test-rush', config = list(url = 'redis://127.0.0.1:6379', scheme = 'redis', host = '127.0.0.1', port = '6379'), remote = TRUE, lgr_thresholds = c('mlr3/rush' = 'debug'), lgr_buffer_size = 0)")),
    supervise = TRUE,
    stderr = "|", stdout = "|")

  on.exit({
    px$kill()
  }, add = TRUE)

  Sys.sleep(5)

  expect_true(px$is_alive())
  expect_equal(rush$n_running_workers, 1)
  expect_true(all(rush$worker_info$remote))

  px$kill()
  expect_rush_reset(rush, type = "terminate")
})

test_that("printing logs with redis appender works", {
  skip_on_cran()
  skip_if(TRUE) # does not work in testthat on environment

  lg_rush = lgr::get_logger("mlr3/rush")
  old_threshold_rush = lg_rush$threshold
  on.exit(lg_rush$set_threshold(old_threshold_rush))
  lg_rush$set_threshold("info")

  config = start_flush_redis()
  rush = rsh(network_id = "test-rush", config = config, seed = 123)
  worker_loop = function(rush) {
    while(!rush$terminated && !rush$terminated_on_idle) {
      task = rush$pop_task(fields = c("xs", "seed"))
      if (!is.null(task)) {
        tryCatch({
          # evaluate task with seed
          fun = function(x1, x2, ...) {
            lg = lgr::get_logger("mlr3/rush")
            lg$info("test-1-info")
            lg$warn("test-1-warn")
            lg$error("test-1-error")
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

  worker_ids = rush$start_local_workers(
    worker_loop = worker_loop,
    n_workers = 2,
    lgr_thresholds = c("mlr3/rush" = "info"))
  rush$wait_for_workers(2, timeout = 5)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 2, x2 = 2))
  keys = rush$push_tasks(xss)

  Sys.sleep(5)

  expect_output(rush$print_log(), ".*test-1-info.*test-1-warn.*test-1-error")
  expect_silent(rush$print_log())

  xss = list(list(x1 = 3, x2 = 2))
  keys = rush$push_tasks(xss)

  Sys.sleep(5)

  expect_output(rush$print_log(), ".*test-1-info.*test-1-warn.*test-1-error")

  expect_rush_reset(rush, type = "terminate")
})

test_that("evaluating a task works", {
  skip_on_cran()
  skip_if(TRUE) # takes too long

  config = start_flush_redis()
  rush = rsh(network_id = "test-rush", config = config)
  worker_loop = function(rush) {
    while(!rush$terminated && !rush$terminated_on_idle) {
      task = rush$pop_task(fields = c("xs", "seed"))
      if (!is.null(task)) {
        tryCatch({
          # evaluate task with seed
          fun = function(x1, x2, large_vector, ...) list(y = length(large_vector))
          ys = with_rng_state(fun, args = c(task$xs, list(large_vector = large_vector)), seed = task$seed)
          rush$push_results(task$key, yss = list(ys))
        }, error = function(e) {
          condition = list(message = e$message)
          rush$push_failed(task$key, conditions = list(condition))
        })
      }
    }

    return(NULL)
  }

  large_vector = runif(1e8)

  expect_error(rush$start_local_workers(
    worker_loop = worker_loop,
    globals = "large_vector",
    n_workers = 2,
    lgr_thresholds = c(rush = "info")),
    "Worker configuration is larger than 512 MiB.")

  rush_plan(n_workers = 2, large_objects_path = tempdir())

  rush$start_local_workers(
    worker_loop = worker_loop,
    globals = "large_vector",
    lgr_thresholds = c(rush = "info"))
  rush$wait_for_workers(2, timeout = 5)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys)

  expect_equal(rush$fetch_finished_tasks()$y, 1e8)

  expect_rush_reset(rush)
})
