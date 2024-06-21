# start workers with processx --------------------------------------------------

test_that("constructing a rush controller works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  expect_class(rush, "Rush")
  expect_equal(rush$network_id, "test-rush")

  expect_rush_reset(rush)
})

test_that("local workers are started", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  expect_data_table(rush$worker_info, nrows = 0)

  worker_ids = rush$start_local_workers(
    fun = fun,
    n_workers = 2,
    lgr_thresholds = c(rush = "debug"),
    wait_for_workers = TRUE)
  expect_equal(rush$n_workers, 2)

  # check fields
  walk(rush$processes, function(process) expect_class(process, "process"))

  # check meta data from redis
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 2)
  expect_integer(worker_info$pid, unique = TRUE)
  expect_false(any(worker_info$remote))
  expect_set_equal(worker_ids, worker_info$worker_id)
  expect_set_equal(rush$worker_ids, worker_ids)
  expect_set_equal(rush$worker_states$state, "running")

  expect_rush_reset(rush)
})

test_that("local workers are started with Redis on unix socket", {
  skip_if(TRUE)

  system(sprintf("redis-server --port 0 --unixsocket /tmp/redis.sock --daemonize yes --pidfile /tmp/redis.pid --dir %s", tempdir()))
  Sys.sleep(5)

  config = redux::redis_config(path = "/tmp/redis.sock")
  r = redux::hiredis(config)

  on.exit({
    try({r$SHUTDOWN()}, silent = TRUE)
  })

  r$FLUSHDB()

  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  worker_ids = rush$start_local_workers(fun = fun, n_workers = 2, wait_for_workers = TRUE)
  expect_equal(rush$n_workers, 2)

  # check fields
  walk(rush$processes, function(process) expect_class(process, "process"))

  # check meta data from redis
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 2)
  expect_integer(worker_info$pid, unique = TRUE)
  expect_false(any(worker_info$remote))
  expect_set_equal(worker_ids, worker_info$worker_id)
  expect_set_equal(rush$worker_ids, worker_ids)
  expect_set_equal(rush$worker_states$state, "running")
})

test_that("workers are started with a heartbeat", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  rush$start_local_workers(fun = fun, n_workers = 2, heartbeat_period = 3, heartbeat_expire = 9, wait_for_workers = TRUE)

  # check meta data from redis
  worker_info = rush$worker_info
  expect_character(worker_info$heartbeat, unique = TRUE)

  expect_rush_reset(rush)
})

test_that("additional workers are started", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  worker_ids = rush$start_local_workers(fun = fun, n_workers = 2, wait_for_workers = TRUE)
  expect_equal(rush$n_workers, 2)

  worker_ids_2 = rush$start_local_workers(fun = fun, n_workers = 2, wait_for_workers = TRUE)
  rush$wait_for_workers(4)
  expect_equal(rush$n_workers, 4)

  expect_length(rush$processes, 4)
  walk(rush$processes, function(process) expect_class(process, "process"))
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 4)
  expect_set_equal(c(worker_ids, worker_ids_2), worker_info$worker_id)
  expect_integer(worker_info$pid, unique = TRUE)
  expect_false(any(worker_info$remote))
  expect_set_equal(rush$worker_states$state, "running")

  expect_rush_reset(rush)
})

test_that("packages are available on the worker", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = UUIDgenerate(n = 1))

  rush$start_local_workers(fun = fun, n_workers = 2, packages = "uuid", wait_for_workers = TRUE)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys, detect_lost_workers = TRUE)

  expect_equal(rush$n_finished_tasks, 1)

  expect_rush_reset(rush)
})

test_that("globals are available on the worker", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x)
  x <<- 33

  rush$start_local_workers(fun = fun, n_workers = 2, globals = "x", wait_for_workers = TRUE)

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
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = z)
  x <<- 33

  rush$start_local_workers(fun = fun, n_workers = 2, globals = c(z = "x"), wait_for_workers = TRUE)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys, detect_lost_workers = TRUE)

  expect_equal(rush$n_finished_tasks, 1)
  expect_equal(rush$fetch_finished_tasks()$y, 33)

  expect_rush_reset(rush)
})

# start workers with script ----------------------------------------------------

test_that("worker can be started with script", {
  skip_on_cran()
  set.seed(1) # make log messages reproducible

  root_logger = lgr::get_logger("root")
  old_fmt = root_logger$appenders$console$layout$fmt
  root_logger$appenders$console$layout$set_fmt("%L (%n): %m")

  on.exit({
    root_logger$appenders$console$layout$set_fmt(old_fmt)
  }, add = TRUE)

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)

  expect_snapshot(rush$create_worker_script())

  px = processx::process$new("Rscript",
    args = c("-e", sprintf("rush::start_worker(network_id = 'test-rush', remote = TRUE, url = 'redis://127.0.0.1:6379', scheme = 'redis', host = '127.0.0.1', port = '6379')")),
    supervise = TRUE,
    stderr = "|", stdout = "|")

  Sys.sleep(5)

  expect_string(rush$pre_worker_ids)

  on.exit({
    px$kill()
  }, add = TRUE)

  fun = function(x1, x2, ...) list(y = x1 + x2)
  rush$start_remote_workers(fun = fun, lgr_thresholds = c(rush = "debug"))

  Sys.sleep(5)

  expect_true(px$is_alive())
  expect_equal(rush$n_running_workers, 1)
  expect_true(all(rush$worker_info$remote))
  expect_null(rush$pre_worker_ids)

  expect_rush_reset(rush, type = "terminate")
  px$kill()
})

# stop workers -----------------------------------------------------------------

test_that("a worker is terminated", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  expect_class(rush$stop_workers(), "Rush")

  rush$start_local_workers(fun = fun, n_workers = 2, wait_for_workers = TRUE)
  worker_id_1 = rush$running_worker_ids[1]
  worker_id_2 = rush$running_worker_ids[2]

  # worker 1
  rush$stop_workers(worker_ids = worker_id_1, type = "terminate")
  Sys.sleep(3)
  expect_false(rush$processes[[worker_id_1]]$is_alive())
  expect_equal(rush$running_worker_ids, worker_id_2)
  expect_equal(worker_id_1, rush$terminated_worker_ids)

  # worker 2
  rush$stop_workers(worker_ids = worker_id_2, type = "terminate")
  Sys.sleep(3)
  expect_false(rush$processes[[worker_id_2]]$is_alive())
  expect_set_equal(c(worker_id_1, worker_id_2), rush$terminated_worker_ids)
  expect_null(rush$running_worker_ids)

  expect_rush_reset(rush, type = "terminate")
})

test_that("a local worker is killed", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  expect_class(rush$stop_workers(type = "kill"), "Rush")

  rush$start_local_workers(fun = fun, n_workers = 2, wait_for_workers = TRUE)
  worker_id_1 = rush$running_worker_ids[1]
  worker_id_2 = rush$running_worker_ids[2]

  # worker 1
  rush$stop_workers(worker_ids = worker_id_1, type = "kill")
  Sys.sleep(1)
  expect_equal(worker_id_1, rush$killed_worker_ids)
  expect_false(rush$processes[[worker_id_1]]$is_alive())
  expect_true(rush$processes[[worker_id_2]]$is_alive())

  # worker 2
  rush$stop_workers(worker_ids = worker_id_2, type = "kill")
  Sys.sleep(1)
  expect_set_equal(c(worker_id_1, worker_id_2), rush$killed_worker_ids)
  expect_false(rush$processes[[worker_id_1]]$is_alive())
  expect_false(rush$processes[[worker_id_2]]$is_alive())

  expect_rush_reset(rush)
})

test_that("a remote worker is killed via the heartbeat", {
  skip_on_cran()
  skip_on_os("windows")

  config = start_flush_redis()
  fun = function(x1, x2, ...) list(y = x1 + x2)
  rush = Rush$new(network_id = "test-rush", config = config)

  rush$start_local_workers(fun = fun, n_workers = 2, heartbeat_period = 1, heartbeat_expire = 2, wait_for_workers = TRUE)

  worker_id_1 = rush$running_worker_ids[1]
  worker_id_2 = rush$running_worker_ids[2]
  worker_info = rush$worker_info
  expect_true(all(tools::pskill(worker_info$pid, signal = 0L)))

  # worker 1
  rush$stop_workers(worker_ids = worker_id_1, type = "kill")
  Sys.sleep(1)
  expect_equal(worker_id_1, rush$killed_worker_ids)
  expect_equal(rush$running_worker_ids, worker_id_2)
  expect_false(tools::pskill(worker_info[worker_id == worker_id_1, pid], signal = 0L))

  # worker 2
  rush$stop_workers(worker_ids = worker_id_2, type = "kill")
  Sys.sleep(1)
  expect_set_equal(c(worker_id_1, worker_id_2), rush$killed_worker_ids)
  expect_false(tools::pskill(worker_info[worker_id == worker_id_2, pid], signal = 0L))

  expect_rush_reset(rush)
})

# low level read and write -----------------------------------------------------

test_that("reading and writing a hash works with flatten", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

  # one field with list
  key = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)))
  expect_equal(rush$read_hashes(key, "xs"), list(list(x1 = 1, x2 = 2)))

  # one field with atomic
  key = rush$write_hashes(timeout = 1)
  expect_equal(rush$read_hashes(key, "timeout"), list(list(timeout = 1)))

  # two fields with lists
  key = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)), ys = list(list(y = 3)))
  expect_equal(rush$read_hashes(key, c("xs", "ys")), list(list(x1 = 1, x2 = 2, y = 3)))

  # two fields with list and empty list
  key = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)), ys = list())
  expect_equal(rush$read_hashes(key, c("xs", "ys")), list(list(x1 = 1, x2 = 2)))

  # two fields with list and atomic
  key = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)), timeout = 1)
  expect_equal(rush$read_hashes(key, c("xs", "timeout")), list(list(x1 = 1, x2 = 2, timeout = 1)))
})

test_that("reading and writing a hash works without flatten", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)

  # one field with list
  key = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)))
  expect_equal(rush$read_hashes(key, "xs", flatten = FALSE), list(list(xs = list(x1 = 1, x2 = 2))))

  # one field with atomic
  key = rush$write_hashes(timeout = 1)
  expect_equal(rush$read_hashes(key, "timeout", flatten = FALSE), list(list(timeout = 1)))

  # two fields with lists
  key = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)), ys = list(list(y = 3)))
  expect_equal(rush$read_hashes(key, c("xs", "ys"), flatten = FALSE), list(list(xs = list(x1 = 1, x2 = 2), ys = list(y = 3))))

  # two fields with list and empty list
  key = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)), ys = list())
  expect_equal(rush$read_hashes(key, c("xs", "ys"), flatten = FALSE), list(list(xs = list(x1 = 1, x2 = 2), ys = NULL)))

  # two fields with list and atomic
  key = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)), timeout = 1)
  expect_equal(rush$read_hashes(key, c("xs", "timeout"), flatten = FALSE), list(list(xs = list(x1 = 1, x2 = 2), timeout = 1)))
})

test_that("reading and writing hashes works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

  # one field with list
  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)))
  expect_equal(rush$read_hashes(keys, "xs"), list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)))

  # one field atomic
  keys = rush$write_hashes(timeout = c(1, 1))
  expect_equal(rush$read_hashes(keys, "timeout"), list(list(timeout = 1), list(timeout = 1)))

  # two fields with list and recycled atomic
  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)), timeout = 1)
  expect_equal(rush$read_hashes(keys, c("xs", "timeout")), list(list(x1 = 1, x2 = 2, timeout = 1), list(x1 = 1, x2 = 3, timeout = 1)))

  # two fields
  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)), ys = list(list(y = 3), list(y = 4)))
  expect_equal(rush$read_hashes(keys, c("xs", "ys")), list(list(x1 = 1, x2 = 2, y = 3), list(x1 = 1, x2 = 3, y = 4)))

  # two fields with list and atomic
  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)), timeout = c(1, 1))
  expect_equal(rush$read_hashes(keys, c("xs", "timeout")), list(list(x1 = 1, x2 = 2, timeout = 1), list(x1 = 1, x2 = 3, timeout = 1)))

  # two fields with list and recycled atomic
  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)), timeout = 1)
  expect_equal(rush$read_hashes(keys, c("xs", "timeout")), list(list(x1 = 1, x2 = 2, timeout = 1), list(x1 = 1, x2 = 3, timeout = 1)))

  # two fields, one empty
  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)), ys = list())
  expect_equal(rush$read_hashes(keys, c("xs", "ys")), list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)))

  # recycle
  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)), ys = list(list(y = 3)))
  expect_equal(rush$read_hashes(keys, c("xs", "ys")), list(list(x1 = 1, x2 = 2, y = 3), list(x1 = 1, x2 = 3, y = 3)))
})

test_that("writing hashes to specific keys works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

  # one element
  keys = uuid::UUIDgenerate()
  rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)), keys = keys)
  expect_equal(rush$read_hashes(keys, "xs"), list(list(x1 = 1, x2 = 2)))

  # two elements
  keys = uuid::UUIDgenerate(n = 2)
  rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)), keys = keys)
  expect_equal(rush$read_hashes(keys, "xs"), list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)))

  # wrong number of keys
  keys = uuid::UUIDgenerate()
  expect_error(rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)), keys = keys), "Assertion on 'keys' failed")
})


test_that("writing list columns works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)), xs_extra = list(list(extra = list("A"))))
  rush$connector$command(c("LPUSH", "test-rush:finished_tasks", keys))

  expect_list(rush$fetch_finished_tasks()$extra, len = 1)

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)), xs_extra = list(list(extra = list(letters[1:3]))))
  rush$connector$command(c("LPUSH", "test-rush:finished_tasks", keys))

  expect_list(rush$fetch_finished_tasks()$extra, len = 1)

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 2, x2 = 2)), xs_extra = list(list(extra = list("A")), list(extra = list("B"))))
  rush$connector$command(c("LPUSH", "test-rush:finished_tasks", keys))
  rush$read_hashes(keys, c("xs", "xs_extra"))

  expect_list(rush$fetch_finished_tasks()$extra, len = 2)
})

# task evaluation --------------------------------------------------------------

test_that("evaluating a task works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  rush$start_local_workers(fun = fun, n_workers = 4, wait_for_workers = TRUE)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
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

test_that("evaluating tasks works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  rush$start_local_workers(fun = fun, n_workers = 4, wait_for_workers = TRUE)

  xss = replicate(10, list(list(x1 = 1, x2 = 2)))
  keys = rush$push_tasks(xss)
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

test_that("caching results works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  rush$start_local_workers(fun = fun, n_workers = 2, wait_for_workers = TRUE)

  xss = replicate(10, list(list(x1 = 1, x2 = 2)))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys)

  expect_data_table(rush$fetch_finished_tasks(), nrows = 10)
  expect_list(get_private(rush)$.cached_tasks, len = 10)

  expect_list(rush$fetch_finished_tasks(data_format = "list"), len = 10)
  expect_list(get_private(rush)$.cached_tasks, len = 10)

  expect_data_table(rush$fetch_finished_tasks(), nrows = 10)
  expect_list(get_private(rush)$.cached_tasks, len = 10)

  expect_list(rush$fetch_finished_tasks(data_format = "list"), len = 10)
  expect_list(get_private(rush)$.cached_tasks, len = 10)

  xss = replicate(10, list(list(x1 = 1, x2 = 2)))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys)

  expect_data_table(rush$fetch_finished_tasks(), nrows = 20)
  expect_list(get_private(rush)$.cached_tasks, len = 20)

  expect_list(rush$fetch_finished_tasks(data_format = "list"), len = 20)
  expect_list(get_private(rush)$.cached_tasks, len = 20)
})

# segfault detection -----------------------------------------------------------

test_that("a segfault on a local worker is detected", {

  skip_if(TRUE) # does not work in testthat on environment

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) get("attach")(structure(list(), class = "UserDefinedDatabase"))
  worker_ids = rush$start_local_workers(fun = fun, n_workers = 1, wait_for_workers = TRUE)

  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss)
  Sys.sleep(3)

  expect_null(rush$lost_worker_ids)
  rush$detect_lost_workers()
  expect_equal(rush$lost_worker_ids, worker_ids)
  rush$fetch_failed_tasks()

  expect_rush_reset(rush)
})

test_that("a segfault on a worker is detected via the heartbeat", {

  skip_if(TRUE) # does not work in testthat on environment

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) get("attach")(structure(list(), class = "UserDefinedDatabase"))

  worker_ids = rush$start_local_workers(fun = fun, n_workers = 1, heartbeat_period = 1, heartbeat_expire = 2, wait_for_workers = TRUE)

  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss)
  Sys.sleep(15)

  expect_null(rush$lost_worker_ids)
  rush$detect_lost_workers()
  expect_equal(rush$lost_worker_ids, worker_ids)

  expect_rush_reset(rush)
})

# fault detection --------------------------------------------------------------

test_that("a simple error is catched", {
  skip_on_cran()
  skip_if(TRUE) # does not work in testthat on environment

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) {
    if (x1 < 1) stop("Test error")
    list(y = x1 + x2)
  }
  rush$start_local_workers(fun = fun, n_workers = 2, wait_for_workers = TRUE)

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

test_that("a lost task is detected", {
  skip_on_cran()
  skip_if(TRUE) # does not work in testthat on environment

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)

  # no task is running
  expect_class(rush$detect_lost_workers(), "Rush")

  fun = function(x1, x2, ...) get("attach")(structure(list(), class = "UserDefinedDatabase"))
  rush$start_local_workers(fun = fun, n_workers = 1, wait_for_workers = TRUE)
  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  Sys.sleep(2)

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

test_that("a lost task is detected when waiting", {
  skip_on_cran()
  skip_if(TRUE) # does not work in testthat on environment

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)

  # no task is running
  expect_class(rush$detect_lost_workers(), "Rush")

  fun = function(x1, x2, ...) get("attach")(structure(list(), class = "UserDefinedDatabase"))
  rush$start_local_workers(fun = fun, n_workers = 1, wait_for_workers = TRUE)
  xss = list(list(x1 = 1, x2 = 2), list(x1 = 2, x2 = 2))
  keys = rush$push_tasks(xss)
  Sys.sleep(5)

  rush$wait_for_tasks(keys, detect_lost_workers = TRUE)

  # check task count
  expect_equal(rush$n_tasks, 2)
  expect_equal(rush$n_queued_tasks, 1)
  expect_equal(rush$n_running_tasks, 0)
  expect_equal(rush$n_finished_tasks, 0)
  expect_equal(rush$n_failed_tasks, 1)

  # check keys in sets
  expect_character(rush$tasks, len = 2)
  expect_string(rush$queued_tasks)
  expect_null(rush$running_tasks)
  expect_null(rush$finished_tasks)
  expect_string(rush$failed_tasks)

  # check fetching
  expect_data_table(rush$fetch_queued_tasks(), nrows = 1)
  expect_data_table(rush$fetch_running_tasks(), nrows = 0)
  expect_data_table(rush$fetch_tasks(), nrows = 2)

  data = rush$fetch_failed_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "keys"))
  expect_data_table(data, nrows = 1)

  expect_rush_reset(rush)
})

# restart workers --------------------------------------------------------------

test_that("restarting a worker works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  rush$start_local_workers(fun = fun, n_workers = 2, wait_for_workers = TRUE)
  worker_id_1 = rush$running_worker_ids[1]
  worker_id_2 = rush$running_worker_ids[2]

  tools::pskill(rush$worker_info[worker_id == worker_id_1, pid])
  Sys.sleep(1)
  expect_false(rush$processes[[worker_id_1]]$is_alive())

  rush$detect_lost_workers(restart_local_workers = TRUE)
  expect_true(rush$processes[[worker_id_1]]$is_alive())

  expect_rush_reset(rush)
})

test_that("restarting a worker kills the worker", {
  skip_on_cran()
  skip_on_os("windows")

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  rush$start_local_workers(fun = fun, n_workers = 1, wait_for_workers = TRUE)
  pid = rush$worker_info$pid
  worker_id = rush$running_worker_ids
  expect_true(tools::pskill(pid, signal = 0))

  rush$restart_local_workers(worker_ids = worker_id)

  Sys.sleep(1)

  expect_false(pid == rush$worker_info$pid)
  expect_false(tools::pskill(pid, signal = 0))

  expect_rush_reset(rush)
})

# receiving results ------------------------------------------------------------

test_that("blocking on new results works", {
  skip_on_cran()
  skip_if(TRUE) # does not work in testthat on environment

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) {
    Sys.sleep(5)
    list(y = x1 + x2)
  }
  rush$start_local_workers(fun = fun, n_workers = 2, wait_for_workers = TRUE)
  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)

  expect_data_table(rush$wait_for_new_tasks(timeout = 1), nrows = 0)
  expect_data_table(rush$wait_for_new_tasks(timeout = 10), nrows = 1)
  expect_data_table(rush$wait_for_new_tasks(timeout = 1), nrows = 0)

  expect_rush_reset(rush)
})

test_that("wait for tasks works when a task gets lost", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) {
    if (x1 < 1) get("attach")(structure(list(), class = "UserDefinedDatabase"))
    list(y = x1 + x2)
  }
  rush$start_local_workers(fun = fun, n_workers = 2, wait_for_workers = TRUE)
  rush$wait_for_workers(2)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2))
  keys = rush$push_tasks(xss)

  expect_class(rush$wait_for_tasks(keys, detect_lost_workers = TRUE), "Rush")

  expect_rush_reset(rush)
})

# misc--------------------------------------------------------------------------

test_that("saving lgr logs works", {
  skip_on_cran()
  skip_if(TRUE) # does not work in testthat on environment

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  rush$start_local_workers(fun = fun, n_workers = 2, lgr_thresholds = c(rush = "debug"), wait_for_workers = TRUE)
  Sys.sleep(5)

  xss = list(list(x1 = 2, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys)
  Sys.sleep(5)

  log = rush$read_log()
  expect_data_table(log, nrows = 6)
  expect_names(names(log), must.include = c("worker_id", "timestamp", "logger", "caller", "msg"))

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2), list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys)
  Sys.sleep(5)

  log = rush$read_log()
  expect_data_table(log, nrows = 18)
  expect_names(names(log), must.include = c("worker_id", "timestamp", "logger", "caller", "msg"))

  expect_rush_reset(rush)
})

test_that("snapshot option works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  rush$start_local_workers(fun = fun, n_workers = 2, lgr_thresholds = c(rush = "debug"))

  rush$snapshot_schedule = c(1, 1)
  expect_equal(rush$connector$CONFIG_GET("save")[[2]], "1 1")
  expect_equal(rush$snapshot_schedule, c(1, 1))

  rush$snapshot_schedule = NULL
  expect_equal(rush$connector$CONFIG_GET("save")[[2]], "")
  expect_equal(rush$snapshot_schedule, "")

  expect_rush_reset(rush)
})

test_that("terminating workers on idle works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  worker_ids = rush$start_local_workers(fun = fun, n_workers = 2, wait_for_workers = TRUE)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss, terminate_workers = TRUE)
  rush$wait_for_tasks(keys)
  Sys.sleep(5)

  expect_set_equal(rush$worker_states$state, "terminated")

  expect_rush_reset(rush)
})

test_that("constants works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, x3, ...) list(y = x1 + x2 + x3)
  rush$start_local_workers(fun = fun, n_workers = 4, constants = list(x3 = 5), wait_for_workers = TRUE)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys)

  expect_equal(rush$fetch_finished_tasks()$y, 8)

  expect_rush_reset(rush)
})

# rush network without controller ----------------------------------------------

test_that("network without controller works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)

  fun = function(rush) {
    while (rush$n_finished_tasks < 100) {
      # ask
      xs = list(
        x1 = sample(seq(1000), 1),
        x2 = sample(seq(1000), 1)
      )
      keys = rush$push_running_tasks(list(xs))

      # evaluate
      ys = list(y = xs$x1 + xs$x2)

      # tell
      rush$push_results(keys, list(ys))
    }

    return(NULL)
  }

  rush$start_local_workers(worker_loop = fun, n_workers = 2, wait_for_workers = TRUE)

  Sys.sleep(10)
  expect_gte(rush$n_finished_tasks, 100)

  expect_rush_reset(rush)
})

# seed -------------------------------------------------------------------------

test_that("seeds are generated from regular rng seed", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config, seed = 123)
  rush$push_tasks(list(list(x1 = 1, x2 = 2)))
  tab = rush$fetch_tasks(fields = c("xs", "seed"))
  expect_true(is_lecyer_cmrg_seed(tab$seed[[1]]))

  rush$push_tasks(list(list(x1 = 2, x2 = 2), list(x1 = 3, x2 = 2)))
  tab = rush$fetch_tasks(fields = c("xs", "seed"))
  expect_true(tab$seed[[1]][2] != tab$seed[[2]][2])
  expect_true(tab$seed[[2]][2] != tab$seed[[3]][2])
})

test_that("seed are generated from L'Ecuyer-CMRG seed", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config, seed = c(10407L, 1801422725L, -2057975723L, 1156894209L, 1595475487L, 210384600L, -1655729657L))
  rush$push_tasks(list(list(x1 = 1, x2 = 2)))
  tab = rush$fetch_tasks(fields = c("xs", "seed"))
  expect_true(is_lecyer_cmrg_seed(tab$seed[[1]]))

  rush$push_tasks(list(list(x1 = 2, x2 = 2), list(x1 = 3, x2 = 2)))
  tab = rush$fetch_tasks(fields = c("xs", "seed"))
  expect_true(tab$seed[[1]][2] != tab$seed[[2]][2])
  expect_true(tab$seed[[2]][2] != tab$seed[[3]][2])
})

test_that("seed is set correctly on two workers", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config, seed = 123)
  fun = function(x1, x2, ...) list(y = sample(10000, 1))
  worker_ids = rush$start_local_workers(fun = fun, n_workers = 2, wait_for_workers = TRUE)

  .keys = rush$push_tasks(list(list(x1 = 1, x2 = 2), list(x1 = 2, x2 = 2), list(x1 = 2, x2 = 3), list(x1 = 2, x2 = 4)))
  rush$wait_for_tasks(.keys)

  finished_tasks = rush$fetch_finished_tasks()
  expect_set_equal(finished_tasks$y, c(5971L, 4090L, 1754L, 9794L))

  .keys = rush$push_tasks(list(list(x1 = 5, x2 = 3), list(x1 = 5, x2 = 4)))
  rush$wait_for_tasks(.keys)

  finished_tasks = rush$fetch_finished_tasks()
  expect_set_equal(finished_tasks$y, c(1754L, 9794L, 4090L, 5971L, 8213L, 3865L))

  expect_rush_reset(rush, type = "terminate")
})

# log --------------------------------------------------------------------------

test_that("printing logs with redis appender works", {
  skip_on_cran()
  skip_if(TRUE) # does not work in testthat on environment

  lg_rush = lgr::get_logger("rush")
  old_threshold_rush = lg_rush$threshold
  on.exit(lg_rush$set_threshold(old_threshold_rush))
  lg_rush$set_threshold("info")

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config, seed = 123)
  fun = function(x1, x2, ...) {
    lg = lgr::get_logger("rush")
    lg$info("test-1-info")
    lg$warn("test-1-warn")
    lg$error("test-1-error")
    list(y = x1 + x2)
  }
  worker_ids = rush$start_local_workers(fun = fun, n_workers = 2, wait_for_workers = TRUE, lgr_thresholds = c(rush = "info"))
  xss = list(list(x1 = 1, x2 = 2), list(x1 = 2, x2 = 2))
  keys = rush$push_tasks(xss)

  Sys.sleep(1)

  expect_output(rush$print_log(), ".*test-1-info.*test-1-warn.*test-1-error")
  expect_silent(rush$print_log())

  xss = list(list(x1 = 3, x2 = 2))
  keys = rush$push_tasks(xss)

  expect_output(rush$print_log(), ".*test-1-info.*test-1-warn.*test-1-error")

  expect_rush_reset(rush, type = "terminate")
})

test_that("redis info works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  expect_list(rush$redis_info)
})

# large objects ----------------------------------------------------------------

test_that("evaluating a task works", {
  skip_on_cran()
  skip_if(TRUE) # takes too long

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  fun = function(x1, x2, large_vector, ...) list(y = length(large_vector))

  expect_error(
    rush$start_local_workers(fun = fun, n_workers = 4, constants = list(large_vector = runif(1e8)), wait_for_workers = TRUE),
    "Worker configuration is larger than 512 MiB.")

  rush_plan(n_workers = 4, large_objects_path = tempdir())

  rush$start_local_workers(fun = fun, constants = list(large_vector = runif(1e8)), wait_for_workers = TRUE)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys)

  expect_equal(rush$fetch_finished_tasks()$y, 1e8)

  expect_rush_reset(rush)
})
