# start workers ----------------------------------------------------------------

test_that("constructing a rush manager works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(network_id = "test-rush", config = config)
  expect_class(rush, "Rush")
  expect_equal(rush$network_id, "test-rush")
  expect_class(rush$config, "redis_config")
  expect_class(rush$connector, "redis_api")

  expect_rush_reset(rush)
})

test_that("workers are started", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  expect_data_table(rush$worker_info, nrows = 0)

  mirai::daemons(2)

  worker_ids = rush$start_workers(
    worker_loop = queue_worker_loop,
    n_workers = 2)
  rush$wait_for_workers(2, timeout = 5)

  walk(rush$processes_mirai, function(process) expect_class(process, "mirai"))
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 2)
  expect_integer(worker_info$pid, unique = TRUE)
  expect_set_equal(worker_ids, worker_info$worker_id)
  expect_set_equal(rush$worker_ids, worker_ids)
  expect_set_equal(rush$worker_info$state, "running")

  expect_rush_reset(rush)
})

test_that("packages are available on the worker", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)

  mirai::daemons(1)

  rush$start_workers(
    worker_loop = queue_worker_loop,
    n_workers = 1,
    packages = "uuid")
  rush$wait_for_workers(1, timeout = 5)
  expect_equal(rush$n_workers, 1)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys, detect_lost_workers = TRUE)

  expect_equal(rush$n_finished_tasks, 1)

  expect_rush_reset(rush)
})

test_that("new workers can be started on used daemons", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  expect_data_table(rush$worker_info, nrows = 0)

  mirai::daemons(2)

  worker_loop = function(rush) {
    xs = list(x1 = 1, x2 = 2)
    key = rush$push_running_tasks(list(xs))
    ys = list(y = xs$x1 + xs$x2)
    rush$finish_tasks(key, yss = list(ys))
  }

  worker_ids = rush$start_workers(
    worker_loop = worker_loop,
    n_workers = 2)
  rush$wait_for_workers(2, timeout = 5)

  rush$reset()

  Sys.sleep(2)

  walk(rush$processes_mirai, function(process) expect_class(process, "mirai"))
  expect_equal(mirai::status()$mirai["completed"], c(completed = 2))

  rush = rsh(network_id = "test-rush-2", config = config)
  worker_ids = rush$start_workers(
    worker_loop = worker_loop,
    n_workers = 2)
  rush$wait_for_workers(2, timeout = 5)

  expect_data_table(rush$fetch_finished_tasks(), nrows = 2)

  expect_equal(mirai::status()$mirai["completed"], c(completed = 4))

  expect_rush_reset(rush)
})

test_that("wait for workers works with worker ids", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  mirai::daemons(1)

  worker_ids = rush$start_workers(
    worker_loop = queue_worker_loop,
    n_workers = 1)

  expect_error(rush$wait_for_workers(timeout = 1), class = "Mlr3ErrorConfig", regexp = "Either")

  rush$wait_for_workers(worker_ids = worker_ids, timeout = 5)
  expect_equal(rush$n_running_workers, 1)

  # worker id does not exist so we expect a timeout
  expect_error(rush$wait_for_workers(worker_ids = "x", timeout = 1), class = "Mlr3ErrorTimeout")

  expect_rush_reset(rush)
})

test_that("wait for workers works with n", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  mirai::daemons(1)

  worker_ids = rush$start_workers(
    worker_loop = queue_worker_loop,
    n_workers = 1)
  rush$wait_for_workers(n = 1, timeout = 5)
  expect_equal(rush$n_running_workers, 1)

  expect_error(rush$wait_for_workers(n = 2, timeout = 1), class = "Mlr3ErrorTimeout")

  expect_rush_reset(rush)
})

test_that("wait for workers works with both n and worker ids", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  mirai::daemons(1)

  worker_ids = rush$start_workers(
    worker_loop = queue_worker_loop,
    n_workers = 1)
  rush$wait_for_workers(n = 1, worker_ids = worker_ids, timeout = 5)
  expect_equal(rush$n_running_workers, 1)

  expect_error(rush$wait_for_workers(n = 2, worker_ids = worker_ids, timeout = 1), class = "Mlr3ErrorConfig", regexp = "Number of workers to wait for")

  expect_error(rush$wait_for_workers(n = 1, worker_ids = "x", timeout = 1), class = "Mlr3ErrorTimeout")

  rush$wait_for_workers(n = 1, worker_ids = c(worker_ids, "x"), timeout = 1)
  expect_equal(rush$n_running_workers, 1)

  expect_rush_reset(rush)
})

# special redis configurations -------------------------------------------------

test_that("Redis on unix socket works", {
  skip_on_cran()
  skip_on_ci() # does not work on github actions runner

  system(sprintf("redis-server --port 0 --unixsocket /tmp/redis.sock --daemonize yes --pidfile /tmp/redis.pid --dir %s", tempdir()), intern = TRUE)
  Sys.sleep(5)

  config = redux::redis_config(path = "/tmp/redis.sock")
  r = redux::hiredis(config)
  r$FLUSHDB()

  on.exit({
    try({r$SHUTDOWN()}, silent = TRUE)
  })

  mirai::daemons(2)

  rush = rsh(config = config)
  worker_ids = rush$start_workers(worker_loop = queue_worker_loop, n_workers = 2)
  rush$wait_for_workers(2, timeout = 5)

  walk(rush$processes_mirai, function(process) expect_class(process, "mirai"))
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 2)
  expect_integer(worker_info$pid, unique = TRUE)
  expect_set_equal(worker_ids, worker_info$worker_id)
  expect_set_equal(rush$worker_ids, worker_ids)
  expect_set_equal(rush$worker_info$state, "running")

  expect_rush_reset(rush)
})

test_that("Redis password authentication works", {
  skip_on_cran()
  skip_on_ci() # does not work on github actions runner

  system(sprintf("redis-server --port 6398 --requirepass testpassword --daemonize yes --pidfile /tmp/redis-auth.pid --dir %s", tempdir()), intern = TRUE)
  Sys.sleep(5)

  config = redux::redis_config(port = 6398, password = "testpassword")
  r = redux::hiredis(config)
  r$FLUSHDB()

  on.exit({
    try({r$SHUTDOWN()}, silent = TRUE)
  })

  mirai::daemons(2)

  rush = rsh(config = config)
  worker_ids = rush$start_workers(worker_loop = queue_worker_loop, n_workers = 2)
  rush$wait_for_workers(2, timeout = 5)

  walk(rush$processes_mirai, function(process) expect_class(process, "mirai"))
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 2)
  expect_integer(worker_info$pid, unique = TRUE)
  expect_set_equal(worker_ids, worker_info$worker_id)
  expect_set_equal(rush$worker_ids, worker_ids)
  expect_set_equal(rush$worker_info$state, "running")

  expect_rush_reset(rush)
})

# local workers ----------------------------------------------------------------

test_that("local workers are started", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  expect_data_table(rush$worker_info, nrows = 0)

  worker_ids = rush$start_local_workers(
    worker_loop = queue_worker_loop,
    n_workers = 2)
  rush$wait_for_workers(2, timeout = 5)

  walk(rush$processes_processx, function(process) expect_class(process, "process"))
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 2)
  expect_names(names(worker_info), must.include = c("worker_id", "pid", "hostname", "heartbeat", "state"))
  expect_integer(worker_info$pid, unique = TRUE)

  expect_set_equal(worker_ids, worker_info$worker_id)
  expect_set_equal(rush$worker_ids, worker_ids)
  expect_set_equal(rush$worker_info$state, "running")

  expect_rush_reset(rush)
})

test_that("additional local workers are started", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  worker_ids = rush$start_local_workers(
    worker_loop = queue_worker_loop,
    n_workers = 2)
  rush$wait_for_workers(2, timeout = 5)

  expect_equal(rush$n_workers, 2)

  worker_ids_2 = rush$start_local_workers(
    worker_loop = queue_worker_loop,
    n_workers = 2)
  rush$wait_for_workers(4, timeout = 5)

  expect_length(rush$processes_processx, 4)
  walk(rush$processes_processx, function(process) expect_class(process, "process"))
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 4)
  expect_set_equal(c(worker_ids, worker_ids_2), worker_info$worker_id)
  expect_integer(worker_info$pid, unique = TRUE)

  expect_set_equal(rush$worker_info$state, "running")

  expect_rush_reset(rush)
})

# start workers with script ----------------------------------------------------

test_that("heartbeat process is started", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  expect_data_table(rush$worker_info, nrows = 0)

  script = rush$worker_script(
    worker_loop = queue_worker_loop,
    heartbeat_period = 3,
    heartbeat_expire = 9)

  px = start_script_worker(script)

  on.exit({
    px$kill()
  }, add = TRUE)

  Sys.sleep(5)

  worker_info = rush$worker_info
  expect_logical(worker_info$heartbeat)
})

# terminate workers ------------------------------------------------------------

test_that("a worker is terminated", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)

  mirai::daemons(2)

  worker_ids = rush$start_workers(
    worker_loop = queue_worker_loop,
    n_workers = 2)
  rush$wait_for_workers(2, timeout = 5)

  worker_id_1 = rush$running_worker_ids[1]
  worker_id_2 = rush$running_worker_ids[2]

  # worker 1
  rush$stop_workers(worker_ids = worker_id_1, type = "terminate")
  Sys.sleep(3)
  expect_false(unresolved(rush$processes_mirai[[worker_id_1]]))
  expect_true(unresolved(rush$processes_mirai[[worker_id_2]]))
  expect_equal(rush$running_worker_ids, worker_id_2)
  expect_equal(worker_id_1, rush$terminated_worker_ids)

  # worker 2
  rush$stop_workers(worker_ids = worker_id_2, type = "terminate")
  Sys.sleep(3)
  expect_false(unresolved(rush$processes_mirai[[worker_id_2]]))
  expect_false(unresolved(rush$processes_mirai[[worker_id_1]]))
  expect_set_equal(c(worker_id_1, worker_id_2), rush$terminated_worker_ids)
  expect_null(rush$running_worker_ids)

  expect_rush_reset(rush)
})

test_that("reset data works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)

  mirai::daemons(1)

  worker_ids = rush$start_workers(
    worker_loop = queue_worker_loop,
    n_workers = 1,
    lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(1, timeout = 5)

  rush$push_tasks(list(list(x1 = 1, x2 = 2)))

  Sys.sleep(1)

  expect_string(rush$tasks)
  expect_string(rush$finished_tasks)

  rush$reset(workers = FALSE)

  expect_null(rush$tasks)
  expect_null(rush$finished_tasks)

  expect_rush_reset(rush)
})


# kill workers -----------------------------------------------------------------

test_that("a worker is killed", {
  skip_on_cran()

  config = start_flush_redis()

  on.exit({
    mirai::daemons(0)
  }, add = TRUE)

  mirai::daemons(2)
  rush = rsh(config = config)
  worker_ids = rush$start_workers(
      worker_loop = queue_worker_loop,
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
  expect_equal(worker_id_1, rush$terminated_worker_ids)
  expect_equal(rush$running_worker_ids, worker_id_2)

  expect_true(mirai::is_error_value(rush$processes_mirai[[worker_id_1]]$data))
  expect_false(mirai::is_error_value(rush$processes_mirai[[worker_id_2]]$data))

  # worker 2
  rush$stop_workers(worker_ids = worker_id_2, type = "kill")
  Sys.sleep(1)
  expect_set_equal(c(worker_id_1, worker_id_2), rush$terminated_worker_ids)

  expect_true(mirai::is_error_value(rush$processes_mirai[[worker_id_1]]$data))
  expect_true(mirai::is_error_value(rush$processes_mirai[[worker_id_2]]$data))

  expect_rush_reset(rush)
})

test_that("a local worker is killed", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  worker_ids = rush$start_local_workers(
      worker_loop = queue_worker_loop,
      n_workers = 2,
      lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(2, timeout = 5)

  worker_id_1 = rush$running_worker_ids[1]
  worker_id_2 = rush$running_worker_ids[2]

  rush$worker_info

  # worker 1
  rush$stop_workers(worker_ids = worker_id_1, type = "kill")
  Sys.sleep(1)
  expect_equal(worker_id_1, rush$terminated_worker_ids)
  expect_false(rush$processes_processx[[worker_id_1]]$is_alive())
  expect_true(rush$processes_processx[[worker_id_2]]$is_alive())

  # worker 2
  rush$stop_workers(worker_ids = worker_id_2, type = "kill")
  Sys.sleep(1)
  expect_set_equal(c(worker_id_1, worker_id_2), rush$terminated_worker_ids)
  expect_false(rush$processes_processx[[worker_id_1]]$is_alive())
  expect_false(rush$processes_processx[[worker_id_2]]$is_alive())

  expect_rush_reset(rush)
})

test_that("worker is killed with a heartbeat process", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  expect_data_table(rush$worker_info, nrows = 0)

  script = rush$worker_script(
    worker_loop = queue_worker_loop,
    heartbeat_period = 3,
    heartbeat_expire = 9)
  px = start_script_worker(script)

  on.exit({
    px$kill()
  }, add = TRUE)

  Sys.sleep(5)

  worker_info = rush$worker_info
  expect_logical(worker_info$heartbeat)

  # signal 0L returns TRUE if the process is still alive
  expect_true(tools::pskill(worker_info$pid, signal = 0L))

  rush$stop_workers(type = "kill")

  Sys.sleep(1)

  expect_false(tools::pskill(worker_info$pid, signal = 0L))
  expect_true(rush$worker_info$state == "terminated")
  expect_equal(rush$terminated_worker_ids, worker_info$worker_id)

  expect_rush_reset(rush)
})

# pushing tasks to the queue ---------------------------------------------------

test_that("pushing a task to the queue works", {
  skip_on_cran()

  config = start_flush_redis()
  mirai::daemons(2)

  rush = rsh(config = config)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)

  expect_equal(rush$n_queued_tasks, 1)

  worker_ids = rush$start_workers(
    worker_loop = queue_worker_loop,
    n_workers = 2)
  rush$wait_for_workers(2, timeout = 5)
  rush$wait_for_tasks(keys)

  # check task count
  expect_equal(rush$n_tasks, 1)
  expect_equal(rush$n_queued_tasks, 0)
  expect_equal(rush$n_running_tasks, 0)
  expect_equal(rush$n_finished_tasks, 1)
  expect_equal(rush$n_failed_tasks, 0)

  # check keys in sets
  expect_string(rush$tasks)
  expect_null(rush$queued_tasks)
  expect_null(rush$running_tasks)
  expect_string(rush$finished_tasks)
  expect_null(rush$failed_tasks)

  # check fetching
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_running_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 0)
  data = rush$fetch_finished_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "y", "keys"))
  expect_data_table(data, nrows = 1)
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  expect_rush_reset(rush)
})

test_that("pushing multiple tasks to the queue works", {
  skip_on_cran()

  config = start_flush_redis()
  mirai::daemons(2)

  rush = rsh(config = config)

  xss = replicate(10, list(list(x1 = 1, x2 = 2)))
  keys = rush$push_tasks(xss)

  expect_equal(rush$n_queued_tasks, 10)


  worker_ids = rush$start_workers(
    worker_loop = queue_worker_loop,
    n_workers = 2)
  rush$wait_for_workers(2, timeout = 5)
  rush$wait_for_tasks(keys)

  # check task count
  expect_equal(rush$n_tasks, 10)
  expect_equal(rush$n_queued_tasks, 0)
  expect_equal(rush$n_running_tasks, 0)
  expect_equal(rush$n_finished_tasks, 10)
  expect_equal(rush$n_failed_tasks, 0)

  # check keys in sets
  expect_character(rush$tasks, len = 10)
  expect_null(rush$queued_tasks)
  expect_null(rush$running_tasks)
  expect_character(rush$finished_tasks, len = 10)
  expect_null(rush$failed_tasks)

  # check fetching
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_running_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 0)
  data = rush$fetch_finished_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "y", "keys"))
  expect_data_table(data, nrows = 10)
  expect_data_table(rush$fetch_tasks(), nrows = 10)

  expect_rush_reset(rush)
})

test_that("pushing a task with extras to the queue works", {
  skip_on_cran()

  config = start_flush_redis()
  mirai::daemons(2)

  rush = rsh(config = config)

  xss = list(list(x1 = 1, x2 = 2))
  timestamp = Sys.time()
  extra = list(list(timestamp = timestamp))
  keys = rush$push_tasks(xss, extra)

  expect_equal(rush$n_queued_tasks, 1)

  worker_ids = rush$start_workers(
    worker_loop = queue_worker_loop,
    n_workers = 2)
  rush$wait_for_workers(2, timeout = 5)
  rush$wait_for_tasks(keys)

  # check task count
  expect_equal(rush$n_tasks, 1)
  expect_equal(rush$n_queued_tasks, 0)
  expect_equal(rush$n_running_tasks, 0)
  expect_equal(rush$n_finished_tasks, 1)
  expect_equal(rush$n_failed_tasks, 0)

  # check keys in sets
  expect_string(rush$tasks)
  expect_null(rush$queued_tasks)
  expect_null(rush$running_tasks)
  expect_set_equal(rush$finished_tasks, keys)
  expect_null(rush$failed_tasks)

  # check fetching
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_running_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 0)
  data = rush$fetch_finished_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "timestamp", "keys"))
  expect_data_table(data, nrows = 1)
  expect_equal(data$timestamp, timestamp[[1]])
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  # status checks
  expect_false(rush$is_running_task(keys))
  expect_false(rush$is_failed_task(keys))

  expect_rush_reset(rush)
})

test_that("pushing multiple tasks with extras to the queue works", {
  skip_on_cran()

  config = start_flush_redis()
  mirai::daemons(2)
  rush = rsh(config = config)

  xss = replicate(10, list(list(x1 = 1, x2 = 2)))
  timestamp = Sys.time()
  extra = list(list(timestamp = timestamp))
  keys = rush$push_tasks(xss, extra)

  expect_equal(rush$n_queued_tasks, 10)

  worker_ids = rush$start_workers(
    worker_loop = queue_worker_loop,
    n_workers = 2)
  rush$wait_for_workers(2, timeout = 5)
  rush$wait_for_tasks(keys)

  # check task count
  expect_equal(rush$n_tasks, 10)
  expect_equal(rush$n_queued_tasks, 0)
  expect_equal(rush$n_running_tasks, 0)
  expect_equal(rush$n_finished_tasks, 10)
  expect_equal(rush$n_failed_tasks, 0)

  # check keys in sets
  expect_character(rush$tasks, len = 10)
  expect_null(rush$queued_tasks)
  expect_null(rush$running_tasks)
  expect_set_equal(rush$finished_tasks, keys)
  expect_null(rush$failed_tasks)

  # check fetching
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_running_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 0)
  data = rush$fetch_finished_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "timestamp", "keys"))
  expect_data_table(data, nrows = 10)
  expect_equal(data$timestamp[[1]], timestamp[[1]])
  expect_data_table(rush$fetch_tasks(), nrows = 10)

  # status checks
  expect_false(any(rush$is_running_task(keys)))
  expect_false(any(rush$is_failed_task(keys)))

  expect_rush_reset(rush)
})


test_that("empty queue works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  mirai::daemons(1)

  worker_loop_sleep = function(rush) {
    while (TRUE) {
      Sys.sleep(1)
    }
  }

  worker_ids = rush$start_workers(
    worker_loop = worker_loop_sleep,
    n_workers = 1)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)

  Sys.sleep(1)

  rush$empty_queue()
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 1)

  xss = list(list(x1 = 2, x2 = 2), list(x1 = 3, x2 = 2))
  keys = rush$push_tasks(xss)

  Sys.sleep(1)

  rush$empty_queue()
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 3)

  expect_rush_reset(rush)
})

# segfault detection -----------------------------------------------------------

test_that("a segfault on a local worker is detected", {
  skip_on_cran()

  config = start_flush_redis()
  mirai::daemons(2)
  rush = rsh(config = config)

  worker_ids = rush$start_local_workers(
    worker_loop = segfault_worker_loop,
    n_workers = 1,
    lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(1, timeout = 5)

  Sys.sleep(3)

  expect_null(rush$terminated_worker_ids)
  rush$detect_lost_workers()
  expect_equal(rush$terminated_worker_ids, worker_ids)
  rush$fetch_failed_tasks()

  expect_rush_reset(rush)
})

test_that("a segfault on a mirai daemon is detected", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)

  mirai::daemons(1)
  worker_ids = rush$start_workers(
    worker_loop = segfault_worker_loop,
    n_workers = 1,
    lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(1, timeout = 5)

  Sys.sleep(3)

  expect_null(rush$terminated_worker_ids)
  rush$detect_lost_workers()
  expect_equal(rush$terminated_worker_ids, worker_ids)
  rush$fetch_failed_tasks()

  expect_rush_reset(rush)
})

test_that("a segfault on a single worker is detected via heartbeat", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  expect_data_table(rush$worker_info, nrows = 0)

  script = rush$worker_script(
    worker_loop = segfault_worker_loop,
    heartbeat_period = 1,
    heartbeat_expire = 2,
    lgr_thresholds = c("mlr3/rush" = "debug"))

  px = start_script_worker(script)

  on.exit({
    px$kill()
  }, add = TRUE)

  Sys.sleep(10)

  expect_null(rush$terminated_worker_ids)
  rush$detect_lost_workers()
  expect_string(rush$terminated_worker_ids)

  expect_rush_reset(rush)
})

test_that("segfaults on multiple workers are detected via the heartbeat", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  expect_data_table(rush$worker_info, nrows = 0)

  script = rush$worker_script(
    worker_loop = segfault_worker_loop,
    heartbeat_period = 1,
    heartbeat_expire = 2,
    lgr_thresholds = c("mlr3/rush" = "debug"))

  px_1 = start_script_worker(script)

  px_2 = start_script_worker(script)

  on.exit({
    px_1$kill()
    px_2$kill()
  }, add = TRUE)

  Sys.sleep(10)

  expect_null(rush$terminated_worker_ids)
  rush$detect_lost_workers()
  expect_character(rush$terminated_worker_ids, len = 2)

  expect_rush_reset(rush)
})

test_that("a lost task is detected", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)

  worker_ids = rush$start_local_workers(
    worker_loop = segfault_worker_loop,
    n_workers = 1,
    lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(1, timeout = 5)

  Sys.sleep(5)

  rush$detect_lost_workers()

  # check task count
  expect_equal(rush$n_tasks, 1)
  expect_equal(rush$n_queued_tasks, 0)
  expect_equal(rush$n_running_tasks, 0)
  expect_equal(rush$n_finished_tasks, 0)
  expect_equal(rush$n_failed_tasks, 1)

  # check keys in sets
  expect_character(rush$tasks, len = 1)
  expect_null(rush$queued_tasks)
  expect_null(rush$running_tasks)
  expect_null(rush$finished_tasks)
  expect_string(rush$failed_tasks)

  # check fetching
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_running_tasks(), nrows = 0)
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  data = rush$fetch_failed_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "message", "keys"))
  expect_data_table(data, nrows = 1)
  expect_equal(data$message, "Worker has crashed or was killed")

  expect_class(rush$detect_lost_workers(), "Rush")

  expect_rush_reset(rush)
})

test_that("wait for tasks works when a task gets lost", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  worker_ids = rush$start_local_workers(
    worker_loop = segfault_worker_loop,
    n_workers = 2,
    lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(2, timeout = 5)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2))
  keys = rush$push_tasks(xss)

  expect_class(rush$wait_for_tasks(keys, detect_lost_workers = TRUE), "Rush")

  expect_rush_reset(rush)
})

# logging ----------------------------------------------------------------------

test_that("saving lgr logs works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  worker_ids = rush$start_local_workers(
    worker_loop = queue_worker_loop,
    n_workers = 1,
    lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(1, timeout = 5)

  Sys.sleep(5)

  xss = list(list(x1 = 2, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys)
  Sys.sleep(5)

  log = rush$read_log()
  expect_data_table(log, min.rows = 1L)
  expect_names(names(log), must.include = c("worker_id", "timestamp", "logger", "caller", "msg"))

  log = rush$read_log(time_difference = TRUE)
  expect_data_table(log, min.rows = 1L)
  expect_names(names(log), must.include = c("time_difference"))
  expect_class(log$time_difference, "difftime")

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2), list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys)
  Sys.sleep(5)

  log = rush$read_log()
  expect_data_table(log, min.rows = 2L)
  expect_names(names(log), must.include = c("worker_id", "timestamp", "logger", "caller", "msg"))

  expect_rush_reset(rush)
})

test_that("saving logs with redis appender works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)

  worker_ids = rush$start_local_workers(
      worker_loop = queue_worker_loop,
      n_workers = 1,
      lgr_thresholds = c("mlr3/rush" = "debug"),
      lgr_buffer_size = 1)
  rush$wait_for_workers(1, timeout = 5)

  log = rush$read_log()
  expect_data_table(log, min.rows = 1)
  expect_names(colnames(log), identical.to =  c("worker_id", "level", "timestamp", "logger", "caller", "msg"))

  expect_rush_reset(rush)
})

test_that("error and output logs work", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)

  message_log = tempdir()
  output_log = tempdir()

  worker_ids = rush$start_local_workers(
    worker_loop = queue_worker_loop,
    n_workers = 1,
    lgr_thresholds = c("mlr3/rush" = "debug"),
    lgr_buffer_size = 1,
    message_log = message_log,
    output_log = output_log)
  rush$wait_for_workers(1)

  expect_match(readLines(file.path(message_log, sprintf("message_%s.log", worker_ids[1])))[1], "Debug message logging on worker")
  expect_match(readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))[1], "Debug output logging on worker")

  expect_rush_reset(rush)
})

# misc--------------------------------------------------------------------------

test_that("caching results works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = rsh(config = config)
  worker_ids = rush$start_local_workers(
    worker_loop = queue_worker_loop,
    n_workers = 4,
    lgr_thresholds = c("mlr3/rush" = "debug"))
  rush$wait_for_workers(2, timeout = 5)

  xss = replicate(10, list(list(x1 = 1, x2 = 2)))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys)

  expect_data_table(rush$fetch_finished_tasks(), nrows = 10)
  expect_data_table(get_private(rush)$.cached_tasks, nrows = 10)

  expect_data_table(rush$fetch_finished_tasks(), nrows = 10)
  expect_data_table(get_private(rush)$.cached_tasks, nrows = 10)

  xss = replicate(10, list(list(x1 = 1, x2 = 2)))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys)

  expect_data_table(rush$fetch_finished_tasks(), nrows = 20)
  expect_data_table(get_private(rush)$.cached_tasks, nrows = 20)
})


test_that("reconnecting rush instance works", {
  skip_on_cran()

  on.exit({
    file.remove("rush.rds")
  })

  config = start_flush_redis()
  rush = rsh(config = config)

  saveRDS(rush, file = "rush.rds")
  rush = readRDS("rush.rds")

  expect_error(rush$print(), "Context is not connected")

  rush$reconnect()
  expect_r6(rush, "Rush")

  expect_rush_reset(rush)
})

test_that("large objects limit works", {
  skip_on_cran()

  old_max_object_size = getOption("rush.max_object_size")
  on.exit(options(rush.max_object_size = old_max_object_size))
  options(rush.max_object_size = 1)

  config = start_flush_redis()
  rush = rsh(config = config)
  mirai::daemons(1)

  large_vector = runif(1e6)

  worker_loop = function(rush, large_vector) {
    rush$push_running_tasks(list(list(x1 = 1, x2 = length(large_vector))))
  }

  expect_error(rush$start_workers(
    worker_loop = worker_loop,
    large_vector = large_vector,
    n_workers = 1),
  class = "Mlr3ErrorConfig")

  rush_plan(n_workers = 1, large_objects_path = tempdir())

  rush$start_workers(
    worker_loop = worker_loop,
    large_vector = large_vector,
    n_workers = 1)
  rush$wait_for_workers(1, timeout = 5)

  Sys.sleep(1)

  expect_equal(rush$fetch_tasks()$x2, 1e6)

  expect_rush_reset(rush)
})
