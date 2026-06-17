skip_if_no_redis()

# start workers ----------------------------------------------------------------

test_that("constructing a rush manager works", {
  config = redux::redis_config()
  r = redux::hiredis(config)
  r$FLUSHDB()
  on.exit({
    rush$reset()
  })

  rush = rsh(network_id = "test-rush", config = config)
  expect_class(rush, "Rush")
  expect_equal(rush$network_id, "test-rush")
  expect_class(rush$config, "redis_config")
  expect_class(rush$connector, "redis_api")
})

test_that("workers are started", {
  rush = start_rush()
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  expect_data_table(rush$worker_info, nrows = 0)

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 2
  )
  rush$wait_for_workers(2, timeout = 5)

  walk(rush$processes_mirai, function(process) expect_class(process, "mirai"))
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 2)
  expect_integer(worker_info$pid, unique = TRUE)
  expect_set_equal(worker_ids, worker_info$worker_id)
  expect_set_equal(rush$worker_ids, worker_ids)
  expect_set_equal(rush$worker_info$state, "running")
})

test_that("packages are available on the worker", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 1,
    packages = "uuid"
  )
  rush$wait_for_workers(1, timeout = 5)
  expect_equal(rush$n_workers, 1)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys, detect_lost_workers = TRUE)

  expect_equal(rush$n_finished_tasks, 1)
})

test_that("wait for workers works with worker ids", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 1
  )

  expect_error(rush$wait_for_workers(timeout = 1), class = "Mlr3ErrorConfig", regexp = "Either")

  rush$wait_for_workers(worker_ids = worker_ids, timeout = 5)
  expect_equal(rush$n_running_workers, 1)

  # worker id does not exist so we expect a timeout
  expect_error(rush$wait_for_workers(worker_ids = "x", timeout = 1), class = "Mlr3ErrorTimeout")
})

test_that("wait for workers works with n", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 1
  )
  rush$wait_for_workers(n = 1, timeout = 5)
  expect_equal(rush$n_running_workers, 1)

  expect_error(rush$wait_for_workers(n = 2, timeout = 1), class = "Mlr3ErrorTimeout")
})

test_that("wait for workers works with both n and worker ids", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 1
  )
  rush$wait_for_workers(n = 1, worker_ids = worker_ids, timeout = 5)
  expect_equal(rush$n_running_workers, 1)

  expect_error(
    rush$wait_for_workers(n = 2, worker_ids = worker_ids, timeout = 1),
    class = "Mlr3ErrorConfig",
    regexp = "Number of workers to wait for"
  )

  expect_error(rush$wait_for_workers(n = 1, worker_ids = "x", timeout = 1), class = "Mlr3ErrorTimeout")

  rush$wait_for_workers(n = 1, worker_ids = c(worker_ids, "x"), timeout = 1)
  expect_equal(rush$n_running_workers, 1)
})

test_that("wait for workers with timeout zero checks once before failing", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 1
  )
  rush$wait_for_workers(n = 1, timeout = 5)

  # already registered workers succeed even with a zero timeout
  rush$wait_for_workers(n = 1, timeout = 0)
  expect_equal(rush$n_running_workers, 1)

  # missing workers error immediately
  expect_error(rush$wait_for_workers(n = 2, timeout = 0), class = "Mlr3ErrorTimeout")
})

# local workers ----------------------------------------------------------------

test_that("local workers are started", {
  config = redis_configuration()
  rush = rsh(config = config)
  on.exit({
    rush$reset()
    walk(rush$processes_processx, function(process) process$kill())
  })

  expect_data_table(rush$worker_info, nrows = 0)

  worker_ids = rush$start_local_workers(
    worker_loop = wl_queue,
    n_workers = 1
  )
  rush$wait_for_workers(1, timeout = 5)

  walk(rush$processes_processx, function(process) expect_class(process, "process"))
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 1)
  expect_names(names(worker_info), must.include = c("worker_id", "pid", "hostname", "heartbeat", "state"))
  expect_integer(worker_info$pid, unique = TRUE)

  expect_set_equal(worker_ids, worker_info$worker_id)
  expect_set_equal(rush$worker_ids, worker_ids)
  expect_set_equal(rush$worker_info$state, "running")
})

test_that("additional local workers are started", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    walk(rush$processes_processx, function(process) process$kill())
  })

  worker_ids = rush$start_local_workers(
    worker_loop = wl_queue,
    n_workers = 1
  )
  rush$wait_for_workers(1, timeout = 5)

  expect_equal(rush$n_workers, 1)

  worker_ids_2 = rush$start_local_workers(
    worker_loop = wl_queue,
    n_workers = 1
  )
  rush$wait_for_workers(2, timeout = 5)

  expect_length(rush$processes_processx, 2)
  walk(rush$processes_processx, function(process) expect_class(process, "process"))
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 2)
  expect_set_equal(c(worker_ids, worker_ids_2), worker_info$worker_id)
  expect_integer(worker_info$pid, unique = TRUE)

  expect_set_equal(rush$worker_info$state, "running")
})

test_that("local workers remove the arguments file after start", {
  config = redis_configuration()
  rush = rsh(config = config)
  on.exit({
    rush$reset()
    walk(rush$processes_processx, function(process) process$kill())
  })

  rds_files = list.files(tempdir(), pattern = "\\.rds$")

  rush$start_local_workers(
    worker_loop = wl_queue,
    n_workers = 1
  )
  rush$wait_for_workers(1, timeout = 5)

  expect_set_equal(list.files(tempdir(), pattern = "\\.rds$"), rds_files)
})

# start workers with script ----------------------------------------------------

test_that("worker script contains the password but the log redacts it", {
  config = redis_configuration()
  rush = rsh(config = config)
  on.exit({
    rush$reset()
  })

  rush$config = redux::redis_config(password = "test-secret")

  lg_rush = lgr::get_logger("mlr3/rush")
  old_threshold_rush = lg_rush$threshold
  on.exit(lg_rush$set_threshold(old_threshold_rush), add = TRUE)
  lg_rush$set_threshold("info")

  log = capture.output({
    script = rush$worker_script(worker_loop = wl_queue)
  })
  log = paste(log, collapse = "\n")

  expect_match(script, "test-secret", fixed = TRUE)
  expect_match(log, "<redacted>", fixed = TRUE)
  expect_false(grepl("test-secret", log, fixed = TRUE))
})

test_that("heartbeat process is started", {
  skip_if_not_installed("callr")
  config = redis_configuration()
  rush = rsh(config = config)
  on.exit({
    rush$reset()
  })

  expect_data_table(rush$worker_info, nrows = 0)

  script = rush$worker_script(
    worker_loop = wl_queue,
    heartbeat_period = 3,
    heartbeat_expire = 9
  )

  px = start_script_worker(script)

  on.exit(
    {
      px$kill()
    },
    add = TRUE
  )

  rush$wait_for_workers(1, timeout = 5)
  worker_info = rush$worker_info
  expect_logical(worker_info$heartbeat)
})

# terminate workers ------------------------------------------------------------

test_that("a worker is terminated", {
  rush = start_rush(n_workers = 2)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 2
  )
  rush$wait_for_workers(2, timeout = 5)

  worker_id_1 = rush$running_worker_ids[1]
  worker_id_2 = rush$running_worker_ids[2]

  # worker 1
  rush$stop_workers(worker_ids = worker_id_1, type = "terminate")
  wait_until(!unresolved(rush$processes_mirai[[worker_id_1]]) && worker_id_1 %in% rush$terminated_worker_ids)
  expect_false(unresolved(rush$processes_mirai[[worker_id_1]]))
  expect_true(unresolved(rush$processes_mirai[[worker_id_2]]))
  expect_equal(rush$running_worker_ids, worker_id_2)
  expect_equal(worker_id_1, rush$terminated_worker_ids)

  # worker 2
  rush$stop_workers(worker_ids = worker_id_2, type = "terminate")
  wait_until(!unresolved(rush$processes_mirai[[worker_id_2]]) && worker_id_2 %in% rush$terminated_worker_ids)
  expect_false(unresolved(rush$processes_mirai[[worker_id_2]]))
  expect_false(unresolved(rush$processes_mirai[[worker_id_1]]))
  expect_set_equal(c(worker_id_1, worker_id_2), rush$terminated_worker_ids)
  expect_null(rush$running_worker_ids)
})

test_that("reset workers works", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_default,
    n_workers = 1
  )
  rush$wait_for_workers(1, timeout = 5)

  wait_until(rush$n_finished_tasks > 0)

  rush$reset(workers = TRUE)
  expect_data_table(rush$worker_info, nrows = 0)
  expect_null(rush$running_worker_ids)
  expect_null(rush$terminated_worker_ids)
  expect_null(rush$tasks)
  expect_null(rush$finished_tasks)
})

test_that("reset data works", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_default,
    n_workers = 1
  )
  rush$wait_for_workers(1, timeout = 5)

  wait_until(rush$n_finished_tasks > 0)

  expect_character(rush$finished_tasks)
  keys = rush$finished_tasks

  rush$reset(workers = FALSE)

  expect_true(all(keys %nin% rush$finished_tasks))
  expect_equal(rush$n_running_workers, 1)
  expect_data_table(rush$worker_info, nrows = 1)
})

test_that("reset data clears pending tasks so no phantom failed task is resurrected", {
  config = redis_configuration()
  rush = rsh(config = config)
  on.exit({
    rush$reset()
    walk(rush$processes_processx, function(process) process$kill())
  })

  rush$push_tasks(list(list(x1 = 1, x2 = 2)))
  rush$start_local_workers(worker_loop = wl_nop, n_workers = 1)
  rush$wait_for_workers(1, timeout = 5)

  # simulate a worker that moved a task into pending but has not marked it running
  r = rush$connector
  worker_id = rush$worker_ids[1]
  key = r$command(c(
    "BLMOVE",
    get_private(rush)$.get_key("queued_tasks"),
    get_private(rush)$.get_worker_key("pending_task", worker_id),
    "RIGHT",
    "LEFT",
    1
  ))
  rush$write_hashes(worker_id = list(worker_id), keys = key)

  # a data-only reset clears the pending list along with the task hashes
  rush$reset(workers = FALSE)
  expect_length(r$command(c("LRANGE", get_private(rush)$.get_worker_key("pending_task", worker_id), 0, -1)), 0)
  expect_equal(rush$n_running_workers, 1)

  # a subsequent lost-worker detection must not resurrect the wiped task
  rush$processes_processx[[worker_id]]$kill()
  rush$detect_lost_workers()
  expect_null(rush$failed_tasks)
})

test_that("reset clears the log counter", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 1,
    lgr_thresholds = c("mlr3/rush" = "debug"),
    lgr_buffer_size = 1
  )
  rush$wait_for_workers(1, timeout = 5)

  wait_until(nrow(rush$read_log()) > 0)

  rush$print_log()
  expect_list(get_private(rush)$.log_counter, min.len = 1)

  rush$reset()
  expect_equal(get_private(rush)$.log_counter, list())
})

# kill workers -----------------------------------------------------------------

test_that("a worker is killed", {
  rush = start_rush()
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_default,
    n_workers = 2
  )
  rush$wait_for_workers(2, timeout = 5)

  worker_id_1 = rush$running_worker_ids[1]
  worker_id_2 = rush$running_worker_ids[2]
  worker_info = rush$worker_info
  expect_true(all(tools::pskill(worker_info$pid, signal = 0L)))

  # worker 1
  rush$stop_workers(worker_ids = worker_id_1, type = "kill")
  wait_until(mirai::is_error_value(rush$processes_mirai[[worker_id_1]]$data))
  expect_equal(worker_id_1, rush$terminated_worker_ids)
  expect_equal(rush$running_worker_ids, worker_id_2)

  expect_true(mirai::is_error_value(rush$processes_mirai[[worker_id_1]]$data))
  expect_false(mirai::is_error_value(rush$processes_mirai[[worker_id_2]]$data))

  # worker 2
  rush$stop_workers(worker_ids = worker_id_2, type = "kill")
  wait_until(mirai::is_error_value(rush$processes_mirai[[worker_id_2]]$data))
  expect_set_equal(c(worker_id_1, worker_id_2), rush$terminated_worker_ids)

  expect_true(mirai::is_error_value(rush$processes_mirai[[worker_id_1]]$data))
  expect_true(mirai::is_error_value(rush$processes_mirai[[worker_id_2]]$data))
})

test_that("stop_workers warns about and ignores workers that are not running", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 1
  )
  rush$wait_for_workers(1, timeout = 5)

  worker_id = rush$running_worker_ids

  lg_rush = lgr::get_logger("mlr3/rush")
  old_threshold_rush = lg_rush$threshold
  on.exit(lg_rush$set_threshold(old_threshold_rush), add = TRUE)
  lg_rush$set_threshold("warn")

  # a mix of a running and a non-running worker warns but still stops the running one
  log = capture.output(
    rush$stop_workers(worker_ids = c(worker_id, "ghost"), type = "kill"))
  expect_match(paste(log, collapse = "\n"), "ghost", fixed = TRUE)

  wait_until(worker_id %in% rush$terminated_worker_ids)
  expect_equal(rush$terminated_worker_ids, worker_id)

  # stopping only a non-running worker warns and is a no-op without error
  log = capture.output(
    expect_invisible(rush$stop_workers(worker_ids = "ghost", type = "kill")))
  expect_match(paste(log, collapse = "\n"), "ghost", fixed = TRUE)
})

test_that("a local worker is killed", {
  config = redis_configuration()
  rush = rsh(config = config)
  on.exit({
    rush$reset()
    walk(rush$processes_processx, function(process) process$kill())
  })

  worker_ids = rush$start_local_workers(
    worker_loop = wl_queue,
    n_workers = 2
  )
  rush$wait_for_workers(2, timeout = 5)

  worker_id_1 = rush$running_worker_ids[1]
  worker_id_2 = rush$running_worker_ids[2]

  rush$worker_info

  # worker 1
  rush$stop_workers(worker_ids = worker_id_1, type = "kill")
  wait_until(!rush$processes_processx[[worker_id_1]]$is_alive())
  expect_equal(worker_id_1, rush$terminated_worker_ids)
  expect_false(rush$processes_processx[[worker_id_1]]$is_alive())
  expect_true(rush$processes_processx[[worker_id_2]]$is_alive())

  # worker 2
  rush$stop_workers(worker_ids = worker_id_2, type = "kill")
  wait_until(!rush$processes_processx[[worker_id_2]]$is_alive())
  expect_set_equal(c(worker_id_1, worker_id_2), rush$terminated_worker_ids)
  expect_false(rush$processes_processx[[worker_id_1]]$is_alive())
  expect_false(rush$processes_processx[[worker_id_2]]$is_alive())
})

test_that("worker is killed with a heartbeat process", {
  skip_if_not_installed("callr")
  config = redis_configuration()
  rush = rsh(config = config)
  on.exit({
    rush$reset()
  })

  expect_data_table(rush$worker_info, nrows = 0)

  script = rush$worker_script(
    worker_loop = wl_queue,
    heartbeat_period = 3,
    heartbeat_expire = 9
  )
  px = start_script_worker(script)
  rush$wait_for_workers(1, timeout = 5)

  on.exit(
    {
      px$kill()
    },
    add = TRUE
  )

  worker_info = rush$worker_info
  expect_logical(worker_info$heartbeat)

  # signal 0L returns TRUE if the process is still alive
  expect_true(tools::pskill(worker_info$pid, signal = 0L))

  rush$stop_workers(type = "kill")

  wait_until(!tools::pskill(worker_info$pid, signal = 0L))

  expect_false(tools::pskill(worker_info$pid, signal = 0L))
  expect_true(rush$worker_info$state == "terminated")
  expect_equal(rush$terminated_worker_ids, worker_info$worker_id)
})

# pushing tasks to the queue ---------------------------------------------------

test_that("pushing a task to the queue works", {
  rush = start_rush(n_workers = 2)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)

  expect_equal(rush$n_queued_tasks, 1)

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 2
  )
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
})

test_that("pushing an empty list of tasks is a no-op", {
  rush = start_rush(n_workers = 2)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  before = rush$connector$DBSIZE()
  expect_equal(rush$push_tasks(list()), character())
  expect_equal(rush$push_finished_tasks(list(), list()), character())
  expect_equal(rush$push_failed_tasks(list(), conditions = list()), character())

  expect_equal(rush$n_tasks, 0)
  expect_equal(rush$connector$DBSIZE(), before)
})

test_that("pushing multiple tasks to the queue works", {
  rush = start_rush(n_workers = 2)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  xss = replicate(10, list(list(x1 = 1, x2 = 2)))
  keys = rush$push_tasks(xss)

  expect_equal(rush$n_queued_tasks, 10)

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 2
  )
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
})

test_that("pushing a task with extras to the queue works", {
  rush = start_rush(n_workers = 2)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  xss = list(list(x1 = 1, x2 = 2))
  timestamp = Sys.time()
  extra = list(list(timestamp = timestamp))
  keys = rush$push_tasks(xss, extra)

  expect_equal(rush$n_queued_tasks, 1)

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 2
  )
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
  expect_false(rush$is_failed_task(keys))
})

test_that("pushing multiple tasks with extras to the queue works", {
  rush = start_rush(n_workers = 2)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  xss = replicate(10, list(list(x1 = 1, x2 = 2)))
  timestamp = Sys.time()
  extra = list(list(timestamp = timestamp))
  keys = rush$push_tasks(xss, extra)

  expect_equal(rush$n_queued_tasks, 10)

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 2
  )
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
})

test_that("fetching tasks with vector parameters works", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  xss = list(
    list(x1 = c(1, 2, 3), x2 = c(4, 5, 6)),
    list(x1 = c(7, 8, 9), x2 = c(10, 11, 12))
  )
  yss = list(list(y = 1), list(y = 2))
  keys = rush$push_finished_tasks(xss, yss)

  data = rush$fetch_finished_tasks()
  expect_data_table(data, nrows = 2)
  expect_equal(data$x1[[1]], c(1, 2, 3))
  expect_equal(data$x1[[2]], c(7, 8, 9))
  expect_data_table(rush$fetch_tasks(), nrows = 2)
})

test_that("fetching tasks with missing hashes works", {
  config = redis_configuration()
  rush = rsh(network_id = "test-rush", config = config)
  on.exit(rush$reset())

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4), list(x1 = 5, x2 = 6))
  keys = rush$push_tasks(xss)

  rush$connector$DEL(keys[2])
  data = rush$fetch_queued_tasks()
  expect_data_table(data, nrows = 2)
  expect_set_equal(data$keys, keys[-2])
  data = rush$fetch_tasks()
  expect_data_table(data, nrows = 2)
  expect_set_equal(data$keys, keys[-2])

  walk(keys, function(key) rush$connector$DEL(key))
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_tasks(), nrows = 0)
})

test_that("empty queue works", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_loop_sleep = function(rush) {
    while (TRUE) {
      Sys.sleep(1)
    }
  }

  worker_ids = rush$start_workers(
    worker_loop = worker_loop_sleep,
    n_workers = 1
  )

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)

  wait_until(rush$n_queued_tasks == length(keys))

  rush$empty_queue()
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 1)

  xss = list(list(x1 = 2, x2 = 2), list(x1 = 3, x2 = 2))
  keys = rush$push_tasks(xss)

  wait_until(rush$n_queued_tasks == length(keys))

  rush$empty_queue()
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 3)
})

test_that("empty queue on an empty queue does not leak a hash", {
  config = redux::redis_config()
  r = redux::hiredis(config)
  r$FLUSHDB()
  on.exit({
    rush$reset()
  })

  rush = rsh(network_id = "test-rush", config = config)
  rush$empty_queue()

  expect_equal(r$DBSIZE(), 0)
})

# segfault detection -----------------------------------------------------------

test_that("segfaults on mirai workers are detected", {
  rush = start_rush(n_workers = 2)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_segfault,
    n_workers = 2
  )
  rush$wait_for_workers(1, timeout = 5)

  # wait until a lost worker is detected but timeout after 10 seconds
  start_time = Sys.time()
  lost_workers = character()
  while (start_time + 10 > Sys.time()) {
    lost_workers = c(lost_workers, rush$detect_lost_workers())
    if (length(lost_workers) == 2) break
  }

  expect_character(rush$terminated_worker_ids, len = 2)
  expect_set_equal(rush$terminated_worker_ids, lost_workers)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 2)
  data = rush$fetch_failed_tasks()
  expect_set_equal(data$message, "Worker has crashed or was killed")
})

test_that("segfaults on processx workers are detected", {
  config = redis_configuration()
  rush = rsh(config = config)
  on.exit({
    rush$reset()
    walk(rush$processes_processx, function(process) process$kill())
  })

  worker_ids = rush$start_local_workers(
    worker_loop = wl_segfault,
    n_workers = 2
  )
  rush$wait_for_workers(2, timeout = 5)

  # wait until a lost worker is detected but timeout after 10 seconds
  start_time = Sys.time()
  lost_workers = character()
  while (start_time + 10 > Sys.time()) {
    lost_workers = c(lost_workers, rush$detect_lost_workers())
    if (length(lost_workers) == 2) break
  }

  expect_character(rush$terminated_worker_ids, len = 2)
  expect_set_equal(rush$terminated_worker_ids, lost_workers)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 2)
  data = rush$fetch_failed_tasks()
  expect_set_equal(data$message, "Worker has crashed or was killed")
})

test_that("a segfault on a single worker is detected via heartbeat", {
  skip_if_not_installed("callr")
  config = redis_configuration()
  rush = rsh(config = config)
  on.exit({
    rush$reset()
  })
  expect_data_table(rush$worker_info, nrows = 0)

  script = rush$worker_script(
    worker_loop = wl_segfault,
    heartbeat_period = 1,
    heartbeat_expire = 2
  )

  px = start_script_worker(script)
  rush$wait_for_workers(1, timeout = 10)

  on.exit(
    {
      px$kill()
    },
    add = TRUE
  )

  expect_null(rush$terminated_worker_ids)

  # wait until a lost worker is detected but timeout after 10 seconds
  start_time = Sys.time()
  while (start_time + 10 > Sys.time()) {
    lost_workers = rush$detect_lost_workers()
    if (length(lost_workers)) break
  }

  expect_character(rush$terminated_worker_ids, len = 1)
  expect_set_equal(rush$terminated_worker_ids, lost_workers)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 1)
  data = rush$fetch_failed_tasks()
  expect_equal(data$message, "Worker has crashed or was killed")
})

test_that("a task lost in the pending state is recovered", {
  config = redis_configuration()
  rush = rsh(config = config)
  on.exit({
    rush$reset()
    walk(rush$processes_processx, function(process) process$kill())
  })

  rush$push_tasks(list(list(x1 = 1, x2 = 2)))
  expect_character(rush$queued_tasks, len = 1)

  worker_ids = rush$start_local_workers(
    worker_loop = wl_nop,
    n_workers = 1
  )
  rush$wait_for_workers(1, timeout = 5)

  # simulate a worker that moved a task into pending but crashed before marking it running
  r = rush$connector
  worker_id = rush$worker_ids[1]
  key = r$command(c(
    "BLMOVE",
    get_private(rush)$.get_key("queued_tasks"),
    get_private(rush)$.get_worker_key("pending_task", worker_id),
    "RIGHT",
    "LEFT",
    1
  ))
  rush$write_hashes(worker_id = list(worker_id), keys = key)
  expect_null(rush$running_tasks)
  expect_null(rush$queued_tasks)
  rush$processes_processx[[worker_id]]$kill()

  rush$detect_lost_workers()

  # task is failed, removed from the pending list, and not in running
  expect_equal(rush$failed_tasks, key)
  expect_null(rush$running_tasks)
  expect_equal(rush$fetch_failed_tasks()$message, "Worker has crashed or was killed")
})

test_that("segfaults on multiple workers are detected via the heartbeat", {
  skip_if_not_installed("callr")
  config = redis_configuration()
  rush = rsh(config = config)
  on.exit({
    rush$reset()
  })

  expect_data_table(rush$worker_info, nrows = 0)

  script = rush$worker_script(
    worker_loop = wl_segfault,
    heartbeat_period = 1,
    heartbeat_expire = 2
  )

  px_1 = start_script_worker(script)
  px_2 = start_script_worker(script)
  rush$wait_for_workers(2, timeout = 10)

  on.exit(
    {
      px_1$kill()
      px_2$kill()
    },
    add = TRUE
  )

  expect_null(rush$terminated_worker_ids)

  # wait until all lost workers are detected but timeout after 10 seconds
  start_time = Sys.time()
  lost_workers = character()
  while (start_time + 10 > Sys.time()) {
    lost_workers = c(lost_workers, rush$detect_lost_workers())
    if (length(lost_workers) == 2) break
  }

  expect_character(rush$terminated_worker_ids, len = 2)
  expect_set_equal(rush$terminated_worker_ids, lost_workers)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 2)
  data = rush$fetch_failed_tasks()
  expect_set_equal(data$message, "Worker has crashed or was killed")
})

test_that("wait for tasks works when a task gets lost", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_segfault,
    n_workers = 1
  )
  rush$wait_for_workers(1, timeout = 5)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2))
  keys = rush$push_tasks(xss)

  expect_class(rush$wait_for_tasks(keys, detect_lost_workers = TRUE), "Rush")
})

# logging ----------------------------------------------------------------------

test_that("saving lgr logs works", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 1,
    lgr_thresholds = c("mlr3/rush" = "debug")
  )
  rush$wait_for_workers(1, timeout = 5)

  xss = list(list(x1 = 2, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys)
  wait_until(nrow(rush$read_log()) >= 1L)

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
  wait_until(nrow(rush$read_log()) >= 2L)

  log = rush$read_log()
  expect_data_table(log, min.rows = 2L)
  expect_names(names(log), must.include = c("worker_id", "timestamp", "logger", "caller", "msg"))
})

test_that("saving logs with redis appender works", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 1,
    lgr_thresholds = c("mlr3/rush" = "debug"),
    lgr_buffer_size = 1
  )
  rush$wait_for_workers(1, timeout = 5)

  log = rush$read_log()
  expect_data_table(log, min.rows = 1)
  expect_names(colnames(log), identical.to = c("worker_id", "level", "timestamp", "logger", "caller", "msg"))
})

test_that("error and output logs work", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  message_log = tempdir()
  output_log = tempdir()

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 1,
    lgr_thresholds = c("mlr3/rush" = "debug"),
    lgr_buffer_size = 1,
    message_log = message_log,
    output_log = output_log
  )
  rush$wait_for_workers(1)

  expect_match(
    readLines(file.path(message_log, sprintf("message_%s.log", worker_ids[1])))[1],
    "Debug message logging on worker"
  )
  expect_match(
    readLines(file.path(output_log, sprintf("output_%s.log", worker_ids[1])))[1],
    "Debug output logging on worker"
  )
})

# misc--------------------------------------------------------------------------

test_that("caching results works", {
  rush = start_rush(n_workers = 2)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_queue,
    n_workers = 2,
    lgr_thresholds = c("mlr3/rush" = "debug")
  )
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

test_that("caching results with missing hashes works", {
  config = redis_configuration()
  rush = rsh(network_id = "test-rush", config = config)
  on.exit(rush$reset())

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 3, x2 = 4), list(x1 = 5, x2 = 6))
  yss = list(list(y = 3), list(y = 7), list(y = 11))
  keys = rush$push_finished_tasks(xss, yss)
  expect_data_table(rush$fetch_finished_tasks(), nrows = 3)

  xss = list(list(x1 = 7, x2 = 8), list(x1 = 9, x2 = 10))
  yss = list(list(y = 15), list(y = 19))
  keys_2 = rush$push_finished_tasks(xss, yss)
  rush$connector$DEL(keys_2[1])

  data = rush$fetch_finished_tasks()
  expect_data_table(data, nrows = 4)
  expect_set_equal(data$keys, c(keys, keys_2[2]))
  expect_equal(get_private(rush)$.n_consumed_tasks, 5)

  # repeated fetch does not re-read or duplicate dropped tasks
  data = rush$fetch_finished_tasks()
  expect_data_table(data, nrows = 4)
  expect_set_equal(data$keys, c(keys, keys_2[2]))

  # new results are still picked up after a drop
  rush$push_finished_tasks(list(list(x1 = 11, x2 = 12)), list(list(y = 23)))
  expect_data_table(rush$fetch_finished_tasks(), nrows = 5)

  # resetting the cache rebuilds it without the dropped task
  rush$reset_cache()
  expect_equal(get_private(rush)$.n_consumed_tasks, 0)
  expect_data_table(rush$fetch_finished_tasks(), nrows = 5)
})

test_that("fetching new tasks with missing hashes works", {
  config = redis_configuration()
  rush = rsh(network_id = "test-rush", config = config)
  on.exit(rush$reset())

  rush$push_finished_tasks(list(list(x1 = 1, x2 = 2)), list(list(y = 3)))
  expect_data_table(rush$fetch_new_tasks(), nrows = 1)

  xss = list(list(x1 = 3, x2 = 4), list(x1 = 5, x2 = 6))
  yss = list(list(y = 7), list(y = 11))
  keys_2 = rush$push_finished_tasks(xss, yss)
  rush$connector$DEL(keys_2[1])

  data = rush$fetch_new_tasks()
  expect_data_table(data, nrows = 1)
  expect_equal(data$keys, keys_2[2])

  # blocking fetch is not unblocked by the dropped task
  expect_data_table(rush$fetch_new_tasks(timeout = 0.2), nrows = 0)

  keys_3 = rush$push_finished_tasks(list(list(x1 = 7, x2 = 8)), list(list(y = 15)))
  data = rush$fetch_new_tasks(timeout = 1)
  expect_data_table(data, nrows = 1)
  expect_equal(data$keys, keys_3)
})

test_that("reconnecting rush instance works", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  on.exit({
    file.remove("rush.rds")
  })

  saveRDS(rush, file = "rush.rds")
  rush = readRDS("rush.rds")

  expect_error(rush$print(), "Context is not connected")

  rush$reconnect()
  expect_r6(rush, "Rush")
})

test_that("large objects limit works", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  old_max_object_size = getOption("rush.max_object_size")
  on.exit(options(rush.max_object_size = old_max_object_size))
  options(rush.max_object_size = 1)

  large_vector = runif(1e6)

  worker_loop = function(rush, large_vector) {
    rush$push_running_tasks(list(list(x1 = 1, x2 = length(large_vector))))
  }

  expect_error(
    rush$start_workers(
      worker_loop = worker_loop,
      large_vector = large_vector,
      n_workers = 1
    ),
    class = "Mlr3ErrorConfig"
  )

  rush_plan(n_workers = 1, large_objects_path = tempdir())

  rush$start_workers(
    worker_loop = worker_loop,
    large_vector = large_vector,
    n_workers = 1
  )
  rush$wait_for_workers(1, timeout = 5)

  wait_until(nrow(rush$fetch_tasks()) > 0)

  expect_equal(rush$fetch_tasks()$x2, 1e6)
})

test_that("worker_loop environment is stripped before serialization", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  # large_data (~8 MB) lives in the same local environment as worker_loop.
  # without crate(), R's closure mechanism would serialize it along with the function.
  local({
    large_data = runif(1e6)
    worker_loop = function(rush) {
      rush$push_running_tasks(list(list(x1 = 1, x2 = 2)))
    }

    rush$.__enclos_env__$private$.push_worker_config(worker_loop = worker_loop)

    r = redux::hiredis(rush$config)
    bin = r$GET(sprintf("%s:start_args", rush$network_id))
    expect_lt(as.numeric(object.size(bin)), 1e6)
  })
})

test_that("simple errors are pushed as failed tasks", {
  rush = start_rush(n_workers = 1)
  on.exit({
    rush$reset()
    mirai::daemons(0)
  })

  worker_ids = rush$start_workers(
    worker_loop = wl_fail,
    n_workers = 1
  )
  rush$wait_for_workers(1, timeout = 5)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$wait_for_tasks(keys, detect_lost_workers = TRUE)
  wait_until(rush$n_finished_tasks == 1 && rush$n_failed_tasks == 1)

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
})
