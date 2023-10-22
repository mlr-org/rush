# start workers with future ----------------------------------------------------

test_that("constructing a rush controller works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  expect_class(rush, "Rush")
  expect_equal(rush$network_id, "test-rush")

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

test_that("workers are started", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  expect_data_table(rush$worker_info, nrows = 0)

  future::plan("multisession", workers = 2)
  worker_ids = rush$start_workers(fun = fun, host = "local", lgr_threshold = c(rush = "debug"), await_workers = TRUE)
  expect_equal(rush$n_workers, 2)

  # check fields
  walk(rush$promises, function(promise) expect_class(promise, "Future"))

  # check meta data from redis
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 2)
  expect_integer(worker_info$pid, unique = TRUE)
  expect_set_equal(worker_info$host, "local")
  expect_set_equal(worker_ids, worker_info$worker_id)
  expect_set_equal(rush$worker_ids, worker_ids)
  expect_set_equal(rush$worker_states$state, "running")

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

test_that("workers are started with a heartbeat", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  future::plan("multisession", workers = 2)
  worker_ids = rush$start_workers(fun = fun, heartbeat_period = 3, heartbeat_expire = 9, await_workers = TRUE)

  # check meta data from redis
  worker_info = rush$worker_info
  expect_character(worker_info$heartbeat, unique = TRUE)

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

test_that("additional workers are started", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  future::plan("multisession", workers = 4)

  worker_ids = rush$start_workers(fun = fun, n_workers = 2)
  rush$await_workers(2)
  expect_equal(rush$n_workers, 2)

  worker_ids_2 = rush$start_workers(fun = fun, n_workers = 2)
  rush$await_workers(4)
  expect_equal(rush$n_workers, 4)

  expect_length(rush$promises, 4)
  walk(rush$promises, function(promise) expect_class(promise, "Future"))
  expect_set_equal(rush$worker_ids, c(worker_ids, worker_ids_2))
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 4)
  expect_integer(worker_info$pid, unique = TRUE)
  expect_set_equal(worker_info$host, "local")
  expect_set_equal(c(worker_ids, worker_ids_2), worker_info$worker_id)
  expect_set_equal(rush$worker_states$state, "running")

  expect_error(rush$start_workers(fun = fun, n_workers = 2), regexp = "No more than 0 rush workers can be started")

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

# start workers with script ----------------------------------------------------

test_that("worker can be started with script", {
  # skip_on_cran()
  skip_on_ci()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  rush$create_worker_script(
    worker_loop = fun_loop,
    globals = NULL,
    packages = NULL,
    host = "local",
    heartbeat_period = NULL,
    heartbeat_expire = NULL,
    lgr_thresholds = c(rush = "debug"),
    fun = fun)

  system2(command = "Rscript", args = "-e 'rush::start_worker(\"test-rush\", url = \"redis://127.0.0.1:6379\")'", wait = FALSE, stdout = NULL, stderr = NULL)
  rush$await_workers(1)
  expect_equal(rush$n_workers, 1)

  system2(command = "Rscript", args = "-e 'rush::start_worker(\"test-rush\", url = \"redis://127.0.0.1:6379\")'", wait = FALSE, stdout = NULL, stderr = NULL)
  rush$await_workers(2)
  expect_equal(rush$n_workers, 2)

  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 2)
  expect_integer(worker_info$pid, unique = TRUE)
  expect_set_equal(worker_info$host, "local")
  expect_set_equal(rush$worker_states$state, "running")

  # rush$stop_workers()
  # Sys.sleep(5)

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

test_that("packages are available on the worker", {
  # skip_on_cran()
  skip_on_ci()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = UUIDgenerate(n = 1))

  rush$create_worker_script(
    worker_loop = fun_loop,
    globals = NULL,
    packages = "uuid",
    host = "local",
    heartbeat_period = NULL,
    heartbeat_expire = NULL,
    lgr_thresholds = c(rush = "debug"),
    fun = fun)

  system2(command = "Rscript", args = "-e 'rush::start_worker(\"test-rush\", url = \"redis://127.0.0.1:6379\")'", wait = FALSE, stdout = NULL, stderr = NULL)
  rush$await_workers(1)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$await_tasks(keys)

  expect_equal(rush$n_finished_tasks, 1)

  # rush$stop_workers()
  # Sys.sleep(5)

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

test_that("globals are available on the worker", {
  # skip_on_cran()
  skip_on_ci()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x)
  x <<- 33

  rush$create_worker_script(
    worker_loop = fun_loop,
    globals = "x",
    packages = NULL,
    host = "local",
    heartbeat_period = NULL,
    heartbeat_expire = NULL,
    lgr_thresholds = c(rush = "debug"),
    fun = fun)

  system2(command = "Rscript", args = "-e 'rush::start_worker(\"test-rush\", url = \"redis://127.0.0.1:6379\")'", wait = FALSE, stdout = NULL, stderr = NULL)
  rush$await_workers(1)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$await_tasks(keys)

  expect_equal(rush$n_finished_tasks, 1)
  expect_equal(rush$fetch_finished_tasks()$y, 33)

  # rush$stop_workers()
  # Sys.sleep(5)

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

# stop workers -----------------------------------------------------------------

test_that("a worker is terminated", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, host = "local", await_workers = TRUE, lgr_thresholds = c(rush = "debug"))
  worker_id_1 = rush$running_worker_ids[1]
  worker_id_2 = rush$running_worker_ids[2]

  # worker 1
  rush$stop_workers(worker_ids = worker_id_1, type = "terminate")
  Sys.sleep(3)
  expect_true(future::resolved(rush$promises[[worker_id_1]]))
  expect_equal(rush$terminated_worker_ids, worker_id_1)
  expect_equal(rush$running_worker_ids, worker_id_2)

  # worker 2
  rush$stop_workers(worker_ids = worker_id_2, type = "terminate")
  Sys.sleep(3)
  expect_true(future::resolved(rush$promises[[worker_id_2]]))
  expect_set_equal(rush$terminated_worker_ids, c(worker_id_1, worker_id_2))
  expect_null(rush$running_worker_ids, worker_id_2)

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

test_that("a local worker is killed", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, host = "local", await_workers = TRUE)
  worker_id_1 = rush$running_worker_ids[1]
  worker_id_2 = rush$running_worker_ids[2]

  # worker 1
  rush$stop_workers(worker_ids = worker_id_1, type = "kill")
  expect_equal(rush$killed_worker_ids, worker_id_1)
  expect_equal(rush$running_worker_ids, worker_id_2)
  expect_error(future::resolved(rush$promises[[worker_id_1]]), class = "FutureError")
  expect_false(future::resolved(rush$promises[[worker_id_2]]))

  # worker 2
  rush$stop_workers(worker_ids = worker_id_2, type = "kill")
  expect_set_equal(rush$killed_worker_ids, c(worker_id_1, worker_id_2))
  expect_true(future::resolved(rush$promises[[worker_id_1]]))
  expect_error(future::resolved(rush$promises[[worker_id_2]]), class = "FutureError")

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

test_that("a remote worker is killed via the heartbeat", {
  # skip_on_cran()
  skip_on_os("windows")

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, host = "remote", heartbeat_period = 1, heartbeat_expire = 2)
  rush$await_workers(2)
  worker_id_1 = rush$running_worker_ids[1]
  worker_id_2 = rush$running_worker_ids[2]
  worker_info = rush$worker_info
  expect_true(all(tools::pskill(worker_info$pid, signal = 0L)))

  # worker 1
  rush$stop_workers(worker_ids = worker_id_1, type = "kill")
  Sys.sleep(15)
  expect_equal(rush$killed_worker_ids, worker_id_1)
  expect_equal(rush$running_worker_ids, worker_id_2)
  expect_false(tools::pskill(worker_info[worker_id == worker_id[1], pid], signal = 0L))

  # worker 2
  rush$stop_workers(worker_ids = worker_id_2, type = "kill")
  Sys.sleep(15)
  expect_set_equal(rush$killed_worker_ids, c(worker_id_1, worker_id_2))
  expect_false(tools::pskill( worker_info[worker_id == worker_id[2], pid], signal = 0L))

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

# task evaluation --------------------------------------------------------------

test_that("evaluating a task works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  future::plan("multisession", workers = 4)
  rush$start_workers(fun = fun, n_workers = 2, await_workers = TRUE)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$await_tasks(keys)

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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "y", "state", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$state, "finished")
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

test_that("evaluating tasks works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  future::plan("multisession", workers = 4)
  rush$start_workers(fun = fun, n_workers = 2, await_workers = TRUE)

  xss = replicate(10, list(list(x1 = 1, x2 = 2)))
  keys = rush$push_tasks(xss)
  rush$await_tasks(keys)

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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "y", "state", "keys"))
  expect_data_table(data, nrows = 10)
  expect_set_equal(data$state, "finished")
  expect_data_table(rush$fetch_tasks(), nrows = 10)

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

# segfault detection -----------------------------------------------------------

test_that("a segfault on a local worker is detected", {
  # skip_on_cran()
  # skip_on_ci()
  skip_on_os("windows")

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) {
    get("attach")(structure(list(), class = "UserDefinedDatabase"))
  }
  future::plan("cluster", workers = 1)
  worker_ids = rush$start_workers(fun = fun, host = "local", await_workers = TRUE)

  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss)
  Sys.sleep(5)

  expect_null(rush$lost_worker_ids)
  rush$detect_lost_workers()
  expect_equal(rush$lost_worker_ids, worker_ids)

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

test_that("a segfault on a worker is detected via the heartbeat", {
  # skip_on_cran()
  skip_on_os("windows")

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) {
    get("attach")(structure(list(), class = "UserDefinedDatabase"))
  }
  future::plan("cluster", workers = 1)
  worker_ids = rush$start_workers(fun = fun, host = "remote", heartbeat_period = 1, heartbeat_expire = 2, await_workers = TRUE)

  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss)
  Sys.sleep(15)

  expect_null(rush$lost_worker_ids)
  rush$detect_lost_workers()
  expect_equal(rush$lost_worker_ids, worker_ids)

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

# fault detection --------------------------------------------------------------

test_that("a simple error is catched", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) {
    if (x1 < 1) stop("Test error")
    list(y = x1 + x2)
  }
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, n_workers = 2, await_workers = TRUE)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$await_tasks(keys)
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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "y", "state", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$state, "finished")

  data = rush$fetch_failed_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "message", "state", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$state, "failed")

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

test_that("a lost task is detected", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)

  # no task is running
  expect_class(rush$detect_lost_tasks(), "Rush")

  fun = function(x1, x2, ...) {
    get("attach")(structure(list(), class = "UserDefinedDatabase"))
  }
  future::plan("cluster", workers = 1)
  rush$start_workers(fun = fun, await_workers = TRUE)
  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  Sys.sleep(2)

  rush$detect_lost_tasks()

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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "state", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$state, "lost")

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

test_that("a lost task is detected when waiting", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)

  # no task is running
  expect_class(rush$detect_lost_tasks(), "Rush")

  fun = function(x1, x2, ...) {
    get("attach")(structure(list(), class = "UserDefinedDatabase"))
  }
  future::plan("cluster", workers = 1)
  rush$start_workers(fun = fun, await_workers = TRUE)
  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  Sys.sleep(2)

  rush$await_tasks(keys, detect_lost_tasks = TRUE)

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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "state", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$state, "lost")

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})


# receiving results ------------------------------------------------------------

test_that("blocking on new results works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
    fun = function(x1, x2, ...) {
    Sys.sleep(5)
    list(y = x1 + x2)
  }
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, await_workers = TRUE)
  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)

  expect_data_table(rush$block_latest_results(timeout = 1), nrows = 0)
  expect_data_table(rush$block_latest_results(timeout = 10), nrows = 1)
  expect_data_table(rush$block_latest_results(timeout = 1), nrows = 0)

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

test_that("wait for tasks works when a task gets lost", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) {
    if (x1 < 1) get("attach")(structure(list(), class = "UserDefinedDatabase"))
    list(y = x1 + x2)
  }
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, n_workers = 2)
  rush$await_workers(2)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2))
  keys = rush$push_tasks(xss)

  expect_class(rush$await_tasks(keys, detect_lost_tasks = TRUE), "Rush")

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

# misc--------------------------------------------------------------------------

test_that("saving lgr logs works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, n_workers = 2, lgr_thresholds = c(rush = "debug"), await_workers = TRUE)
  Sys.sleep(5)

  xss = list(list(x1 = 2, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$await_tasks(keys)
  Sys.sleep(5)

  log = rush$read_log()
  expect_data_table(log, nrows = 6)
  expect_names(names(log), must.include = c("worker_id", "timestamp", "logger", "msg"))

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2), list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$await_tasks(keys)
  Sys.sleep(5)

  log = rush$read_log()
  expect_data_table(log, nrows = 18)
  expect_names(names(log), must.include = c("worker_id", "timestamp", "logger", "msg"))

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

test_that("snapshot option works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, n_workers = 2, lgr_thresholds = c(rush = "debug"))

  rush$snapshot_schedule = c(1, 1)
  expect_equal(rush$connector$CONFIG_GET("save")[[2]], "1 1")
  expect_equal(rush$snapshot_schedule, c(1, 1))

  rush$snapshot_schedule = NULL
  expect_equal(rush$connector$CONFIG_GET("save")[[2]], "")
  expect_equal(rush$snapshot_schedule, "")

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

test_that("terminating workers on idle works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  future::plan("multisession", workers = 2)
  worker_ids = rush$start_workers(fun = fun, n_workers = 2, await_workers = TRUE)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss, terminate_workers = TRUE)
  rush$await_tasks(keys)
  Sys.sleep(5)

  expect_set_equal(rush$worker_states$state, "terminated")

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})

# # rush network without controller ----------------------------------------------

test_that("network without controller works", {
  # skip_on_cran()
  skip_on_ci()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)

  fun = function(rush) {
    while (rush$n_finished_tasks < 100) {
      # ask
      xs = list(
        x1 = sample(seq(1000), 1),
        x2 = sample(seq(1000), 1)
      )
      keys = rush$push_running_task(list(xs))

      # evaluate
      ys = list(y = xs$x1 + xs$x2)

      # tell
      rush$push_results(keys, list(ys))
    }

    return(NULL)
  }

  future::plan("multisession", workers = 2)
  rush$start_workers(worker_loop = fun, n_workers = 2, await_workers = TRUE)

  Sys.sleep(10)
  expect_equal(rush$n_finished_tasks, 100)

  pids = rush$worker_info$pid
  expect_rush_reset(rush)
  clean_test_env(pids)
})
