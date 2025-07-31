test_that("globals are available on the worker", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(network_id = "test-rush", config = config)

  worker_loop = function(rush) {
    while(!rush$terminated && !rush$terminated_on_idle) {
      task = rush$pop_task(fields = c("xs", "seed"))
      if (!is.null(task)) {
        tryCatch({
          # evaluate task with seed
          fun = function(x1, x2, ...) list(y = x)
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
  x <<- 33

  worker_ids = rush$start_local_workers(
    worker_loop = worker_loop,
    n_workers = 2,
    globals = "x",
    lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(2, timeout = 5)
  expect_equal(rush$n_workers, 2)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys, detect_lost_workers = TRUE)

  expect_equal(rush$n_finished_tasks, 1)
  expect_equal(rush$fetch_finished_tasks()$y, 33)

  expect_rush_reset(rush)
})

test_that("named globals are available on the worker", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(network_id = "test-rush", config = config)
  worker_loop = function(rush) {
      while(!rush$terminated && !rush$terminated_on_idle) {
        task = rush$pop_task(fields = c("xs", "seed"))
        if (!is.null(task)) {
          tryCatch({
            # evaluate task with seed
            fun = function(x1, x2, ...) list(y = z)
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
  x <<- 33

  worker_ids = rush$start_local_workers(
    worker_loop = worker_loop,
    n_workers = 2,
    globals = c(z = "x"),
    lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(2, timeout = 5)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys, detect_lost_workers = TRUE)

  expect_equal(rush$n_finished_tasks, 1)
  expect_equal(rush$fetch_finished_tasks()$y, 33)

  expect_rush_reset(rush)
})
