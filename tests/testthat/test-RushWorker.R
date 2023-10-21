test_that("constructing a rush worker works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")
  expect_class(rush, "Rush")
  expect_equal(rush$network_id, "test-rush")
  expect_string(rush$worker_id)
  expect_equal(rush$host, "local")
  expect_equal(rush$worker_ids, rush$worker_id)
  expect_equal(rush$running_worker_ids, rush$worker_id)

  expect_rush_reset(rush)

  # pass worker id
  config = start_flush_redis()
  worker_id = uuid::UUIDgenerate()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local", worker_id = worker_id)
  expect_equal(rush$worker_id, worker_id)

  expect_rush_reset(rush)
})

test_that("active bindings work after construction", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")

  expect_equal(rush$n_workers, 1)
  expect_data_table(rush$data, nrows = 0)

  # check task count
  expect_equal(rush$n_queued_tasks, 0)
  expect_equal(rush$n_queued_priority_tasks, 0)
  expect_equal(rush$n_running_tasks, 0)
  expect_equal(rush$n_finished_tasks, 0)
  expect_equal(rush$n_failed_tasks, 0)

  # check keys in sets
  expect_null(rush$queued_tasks)
  expect_null(rush$running_tasks)
  expect_null(rush$finished_tasks)
  expect_null(rush$failed_tasks)

  expect_rush_reset(rush)
})

test_that("a worker is registered", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")

  # check meta data from redis
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 1)
  expect_names(names(worker_info), permutation.of = c("worker_id", "pid", "host", "heartbeat"))
  expect_string(worker_info$heartbeat, na.ok = TRUE)
  expect_equal(worker_info$worker_id, rush$worker_id)
  expect_equal(worker_info$host, "local")
  expect_equal(worker_info$pid, Sys.getpid())
  expect_equal(rush$worker_ids, rush$worker_id)
  expect_equal(rush$worker_states$state, "running")

  expect_rush_reset(rush)
})

test_that("a worker is terminated", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")
  expect_equal(rush$running_worker_ids, rush$worker_id)

  rush$set_terminated()
  expect_null(rush$running_worker_ids)
  expect_equal(rush$terminated_worker_ids, rush$worker_id)

  expect_rush_reset(rush)
})

test_that("a heartbeat is started", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local", heartbeat_period = 3)

  expect_class(rush$heartbeat, "r_process")
  expect_true(rush$heartbeat$is_alive())
  expect_string(rush$worker_info$heartbeat)

  expect_rush_reset(rush)
})

test_that("reading and writing a hash works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")

  # one field
  key = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)))
  expect_equal(rush$read_hashes(key, "xs"), list(list(x1 = 1, x2 = 2)))

  # two fields
  key = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)), ys = list(list(y = 3)))
  expect_equal(rush$read_hashes(key, c("xs", "ys")), list(list(x1 = 1, x2 = 2, y = 3)))

  # two fields, one empty
  key = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)), ys = list())
  expect_equal(rush$read_hashes(key, c("xs", "ys")), list(list(x1 = 1, x2 = 2)))

  # one field with empty list
  key = rush$write_hashes(xs = list(list()))
  expect_equal(rush$read_hashes(key, "xs"), list(list()))

  # one empty field
  expect_error(rush$write_hashes(xs = list()), "Assertion on 'values' failed")
})

test_that("reading and writing hashes works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")

  # one field
  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)))
  expect_equal(rush$read_hashes(keys, "xs"), list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)))

  # two fields
  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)), ys = list(list(y = 3), list(y = 4)))
  expect_equal(rush$read_hashes(keys, c("xs", "ys")), list(list(x1 = 1, x2 = 2, y = 3), list(x1 = 1, x2 = 3, y = 4)))

  # two fields, one empty
  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)), ys = list())
  expect_equal(rush$read_hashes(keys, c("xs", "ys")), list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)))

  # recycle
  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)), ys = list(list(y = 3)))
  expect_equal(rush$read_hashes(keys, c("xs", "ys")), list(list(x1 = 1, x2 = 2, y = 3), list(x1 = 1, x2 = 3, y = 3)))
})

test_that("writing hashes to specific keys works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")

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

test_that("writting a hash with a state works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")

  # one element
  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)), state = "queued")
  expect_equal(rush$read_hashes(keys, c("xs", "state")), list(list(x1 = 1, x2 = 2, state = "queued")))

  # two elements
  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)), state = "queued")
  expect_equal(rush$read_hashes(keys, c("xs", "state")), list(list(x1 = 1, x2 = 2, state = "queued"), list(x1 = 1, x2 = 3, state = "queued")))
})

test_that("pushing a task to the queue works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)

  # check task count
  expect_equal(rush$n_tasks, 1)
  expect_equal(rush$n_queued_tasks, 1)
  expect_equal(rush$n_running_tasks, 0)
  expect_equal(rush$n_finished_tasks, 0)
  expect_equal(rush$n_failed_tasks, 0)

  # check keys in sets
  expect_string(rush$tasks)
  expect_set_equal(rush$queued_tasks, keys)
  expect_null(rush$running_tasks)
  expect_null(rush$finished_tasks)
  expect_null(rush$failed_tasks)

  # check fetching
  expect_data_table(rush$fetch_running_tasks(), nrows = 0)
  expect_data_table(rush$fetch_finished_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 0)
  data = rush$fetch_queued_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "state", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$state, "queued")
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  expect_rush_reset(rush)
})

test_that("pushing a task with extras to the queue works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")

  xss = list(list(x1 = 1, x2 = 2))
  timestamp = Sys.time()
  extra = list(list(timestamp = timestamp))
  keys = rush$push_tasks(xss, extra)

  # check task count
  expect_equal(rush$n_tasks, 1)
  expect_equal(rush$n_queued_tasks, 1)
  expect_equal(rush$n_running_tasks, 0)
  expect_equal(rush$n_finished_tasks, 0)
  expect_equal(rush$n_failed_tasks, 0)

  # check keys in sets
  expect_string(rush$tasks)
  expect_set_equal(rush$queued_tasks, keys)
  expect_null(rush$running_tasks)
  expect_null(rush$finished_tasks)
  expect_null(rush$failed_tasks)

  # check fetching
  expect_data_table(rush$fetch_running_tasks(), nrows = 0)
  expect_data_table(rush$fetch_finished_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 0)
  data = rush$fetch_queued_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "timestamp", "state", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$state, "queued")
  expect_equal(data$timestamp, timestamp)
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  expect_rush_reset(rush)
})

test_that("pushing tasks to the queue works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3))
  keys = rush$push_tasks(xss)

  # check task count
  expect_equal(rush$n_tasks, 2)
  expect_equal(rush$n_queued_tasks, 2)
  expect_equal(rush$n_running_tasks, 0)
  expect_equal(rush$n_finished_tasks, 0)
  expect_equal(rush$n_failed_tasks, 0)

  # check keys in sets
  expect_character(rush$tasks, len = 2)
  expect_set_equal(rush$queued_tasks, keys)
  expect_null(rush$running_tasks)
  expect_null(rush$finished_tasks)
  expect_null(rush$failed_tasks)

  # check fetching
  expect_data_table(rush$fetch_running_tasks(), nrows = 0)
  expect_data_table(rush$fetch_finished_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 0)
  data = rush$fetch_queued_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "state", "keys"))
  expect_data_table(data, nrows = 2)
  expect_character(data$keys, unique = TRUE, len = 2)
  expect_set_equal(data$state, "queued")
  expect_data_table(rush$fetch_tasks(), nrows = 2)

  expect_rush_reset(rush)
})

test_that("pushing tasks with extras to the queue works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3))
  timestamp = Sys.time()
  extra = list(list(timestamp = timestamp), list(timestamp = timestamp))
  keys = rush$push_tasks(xss, extra)

  # check task count
  expect_equal(rush$n_tasks, 2)
  expect_equal(rush$n_queued_tasks, 2)
  expect_equal(rush$n_running_tasks, 0)
  expect_equal(rush$n_finished_tasks, 0)
  expect_equal(rush$n_failed_tasks, 0)

  # check keys in sets
  expect_character(rush$tasks, len = 2)
  expect_set_equal(rush$queued_tasks, keys)
  expect_null(rush$running_tasks)
  expect_null(rush$finished_tasks)
  expect_null(rush$failed_tasks)

  # check fetching
  expect_data_table(rush$fetch_running_tasks(), nrows = 0)
  expect_data_table(rush$fetch_finished_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 0)
  data = rush$fetch_queued_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "timestamp", "state", "keys"))
  expect_data_table(data, nrows = 2)
  expect_character(data$keys, unique = TRUE, len = 2)
  expect_set_equal(data$state, "queued")
  expect_equal(data$timestamp, c(timestamp, timestamp))
  expect_data_table(rush$fetch_tasks(), nrows = 2)

  expect_rush_reset(rush)
})

test_that("popping a task from the queue works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss)

  # check task
  task = rush$pop_task()
  expect_rush_task(task)

  # check task count
  expect_equal(rush$n_tasks, 1)
  expect_equal(rush$n_queued_tasks, 0)
  expect_equal(rush$n_running_tasks, 1)
  expect_equal(rush$n_finished_tasks, 0)
  expect_equal(rush$n_failed_tasks, 0)

  # check keys in sets
  expect_string(rush$tasks)
  expect_null(rush$queued_tasks)
  expect_string(rush$running_tasks)
  expect_null(rush$finished_tasks)
  expect_null(rush$failed_tasks)

  # check fetching
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_finished_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 0)
  data = rush$fetch_running_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "state", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$state, "running")
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  expect_rush_reset(rush)
})

test_that("pushing a finished task works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss)
  task = rush$pop_task()

  rush$push_results(task$key, list(list(y = 3)))

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

  expect_rush_reset(rush)
})

test_that("pushing a failed tasks works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss)
  task = rush$pop_task()

  rush$push_results(task$key, condition = list(list(message = "error")), state = "failed")

  # check task count
  expect_equal(rush$n_tasks, 1)
  expect_equal(rush$n_queued_tasks, 0)
  expect_equal(rush$n_running_tasks, 0)
  expect_equal(rush$n_finished_tasks, 0)
  expect_equal(rush$n_failed_tasks, 1)

  # check keys in sets
  expect_string(rush$tasks)
  expect_null(rush$queued_tasks)
  expect_null(rush$running_tasks)
  expect_null(rush$finished_tasks)
  expect_string(rush$failed_tasks)

  # check fetching
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_running_tasks(), nrows = 0)
  expect_data_table(rush$fetch_finished_tasks(), nrows = 0)
  data = rush$fetch_failed_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "message", "state", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$state, "failed")
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  expect_rush_reset(rush)
})

test_that("moving and fetching tasks works", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")

  # queue tasks
  xss = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3), list(x1 = 1, x2 = 4), list(x1 = 1, x2 = 5))
  rush$push_tasks(xss)
  queued_tasks = rush$fetch_queued_tasks()
  expect_data_table(queued_tasks, nrows = 4)
  expect_character(queued_tasks$keys, unique = TRUE)
  all_tasks = rush$fetch_tasks()
  expect_data_table(all_tasks, nrows = 4)
  expect_character(all_tasks$keys, unique = TRUE)

  # pop task
  task = rush$pop_task()
  queued_tasks = rush$fetch_queued_tasks()
  expect_data_table(queued_tasks, nrows = 3)
  expect_character(queued_tasks$keys, unique = TRUE)
  running_tasks = rush$fetch_running_tasks()
  expect_data_table(running_tasks, nrows = 1)
  expect_character(running_tasks$keys, unique = TRUE)
  expect_disjunct(queued_tasks$keys, running_tasks$keys)
  all_tasks = rush$fetch_tasks()
  expect_data_table(all_tasks, nrows = 4)
  expect_character(all_tasks$keys, unique = TRUE)

  # push result
  rush$pop_task()
  rush$push_results(task$key, list(list(y = 3)))
  queued_tasks = rush$fetch_queued_tasks()
  expect_data_table(queued_tasks, nrows = 2)
  expect_character(queued_tasks$keys, unique = TRUE)
  running_tasks = rush$fetch_running_tasks()
  expect_data_table(running_tasks, nrows = 1)
  expect_character(running_tasks$keys, unique = TRUE)
  expect_disjunct(queued_tasks$keys, running_tasks$keys)
  finished_tasks = rush$fetch_finished_tasks()
  expect_data_table(finished_tasks, nrows = 1)
  expect_character(finished_tasks$keys, unique = TRUE)
  expect_disjunct(queued_tasks$keys, finished_tasks$keys)
  expect_disjunct(running_tasks$keys, finished_tasks$keys)
  all_tasks = rush$fetch_tasks()
  expect_data_table(all_tasks, nrows = 4)
  expect_character(all_tasks$keys, unique = TRUE)

  # push failed task
  task = rush$pop_task()
  rush$push_results(task$key, condition = list(list(message = "error")), state = "failed")
  queued_tasks = rush$fetch_queued_tasks()
  expect_data_table(queued_tasks, nrows = 1)
  expect_character(queued_tasks$keys, unique = TRUE)
  running_tasks = rush$fetch_running_tasks()
  expect_data_table(running_tasks, nrows = 1)
  expect_character(running_tasks$keys, unique = TRUE)
  expect_disjunct(queued_tasks$keys, running_tasks$keys)
  finished_tasks = rush$fetch_finished_tasks()
  expect_data_table(finished_tasks, nrows = 1)
  expect_character(finished_tasks$keys, unique = TRUE)
  expect_disjunct(queued_tasks$keys, finished_tasks$keys)
  expect_disjunct(running_tasks$keys, finished_tasks$keys)
  failed_tasks = rush$fetch_failed_tasks()
  expect_data_table(failed_tasks, nrows = 1)
  expect_character(failed_tasks$keys, unique = TRUE)
  expect_disjunct(queued_tasks$keys, failed_tasks$keys)
  expect_disjunct(running_tasks$keys, failed_tasks$keys)
  all_tasks = rush$fetch_tasks()
  expect_data_table(all_tasks, nrows = 4)
  expect_character(all_tasks$keys, unique = TRUE)

  expect_rush_reset(rush)
})

test_that("latest results are fetched", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")

  # add 1 task
  rush$push_tasks(list(list(x1 = 1, x2 = 2)))
  task = rush$pop_task()
  rush$push_results(task$key, list(list(y = 3)))

  latest_results = rush$fetch_latest_results()
  expect_data_table(latest_results, nrows = 1)
  expect_set_equal(latest_results$y, 3)
  expect_data_table(rush$fetch_latest_results(), nrows = 0)

  # add 1 task
  keys = rush$push_tasks(list(list(x1 = 1, x2 = 3)))
  task = rush$pop_task()
  rush$push_results(task$key, list(list(y = 4)))

  latest_results = rush$fetch_latest_results()
  expect_data_table(latest_results, nrows = 1)
  expect_set_equal(latest_results$y, 4)
  expect_data_table(rush$fetch_latest_results(), nrows = 0)

  # add 2 tasks
  keys = rush$push_tasks(list(list(x1 = 1, x2 = 4)))
  task = rush$pop_task()
  rush$push_results(task$key, list(list(y = 5)))
  keys = rush$push_tasks(list(list(x1 = 1, x2 = 5)))
  task = rush$pop_task()
  rush$push_results(task$key, list(list(y = 6)))

  latest_results = rush$fetch_latest_results()
  expect_data_table(latest_results, nrows = 2)
  expect_set_equal(latest_results$y, c(5, 6))
  expect_data_table(rush$fetch_latest_results(), nrows = 0)

  expect_rush_reset(rush)
})

test_that("priority queues work", {
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)

  expect_equal(rush$n_queued_priority_tasks, 0)
  expect_data_table(rush$fetch_priority_tasks(), nrows = 0)
  expect_data_table(rush$priority_info, nrows = 0)

  rush_1 = RushWorker$new(network_id = "test-rush", config = config, host = "local")
  rush_2 = RushWorker$new(network_id = "test-rush", config = config, host = "local")

  expect_equal(rush$n_queued_priority_tasks, 0)
  expect_data_table(rush$fetch_priority_tasks(), nrows = 0)
  priority_info = rush$priority_info
  expect_data_table(rush$priority_info, nrows = 2)
  expect_equal(priority_info[list(rush_1$worker_id), n_tasks, on = "worker_id"], 0)
  expect_equal(priority_info[list(rush_2$worker_id), n_tasks, on = "worker_id"], 0)

  keys = rush$push_priority_tasks(list(list(x1 = 1, x2 = 2), list(x1 = 2, x2 = 2), list(x1 = 3, x2 = 5)), priority = c(rep(rush_1$worker_id, 2), rush_2$worker_id))

  expect_equal(rush$n_queued_priority_tasks, 3)
  expect_data_table(rush$fetch_priority_tasks(), nrows = 3)
  priority_info = rush$priority_info
  expect_data_table(priority_info, nrows = 2)
  expect_equal(priority_info[list(rush_1$worker_id), n_tasks, on = "worker_id"], 2)
  expect_equal(priority_info[list(rush_2$worker_id), n_tasks, on = "worker_id"], 1)

  expect_rush_task(rush_2$pop_task())

  expect_equal(rush$n_queued_priority_tasks, 2)
  expect_data_table(rush$fetch_priority_tasks(), nrows = 2)
  priority_info = rush$priority_info
  expect_data_table(priority_info, nrows = 2)
  expect_equal(priority_info[list(rush_1$worker_id), n_tasks, on = "worker_id"], 2)
  expect_equal(priority_info[list(rush_2$worker_id), n_tasks, on = "worker_id"], 0)

  expect_null(rush_2$pop_task())
  expect_rush_task(rush_1$pop_task())
  expect_equal(rush$n_queued_priority_tasks, 1)
  priority_info = rush$priority_info
  expect_data_table(priority_info, nrows = 2)
  expect_equal(priority_info[list(rush_1$worker_id), n_tasks, on = "worker_id"], 1)
  expect_equal(priority_info[list(rush_2$worker_id), n_tasks, on = "worker_id"], 0)

  expect_rush_task(rush_1$pop_task())
  expect_equal(rush$n_queued_priority_tasks, 0)
  expect_set_equal(rush$priority_info$n_tasks, 0)

  expect_rush_reset(rush)
})

test_that("mixing priority queues and default queue work", {
  # FIXME: add expect
  skip_if(TRUE)
  # skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)
  rush_1 = RushWorker$new(network_id = "test-rush", config = config, host = "local")
  rush_2 = RushWorker$new(network_id = "test-rush", config = config, host = "local")

  keys = rush$push_priority_tasks(list(list(x1 = 1, x2 = 2), list(x1 = 2, x2 = 2), list(x1 = 3, x2 = 5)), priority = c(rep(rush_1$worker_id, 2), NA_character_))

})

test_that("saving lgr logs works", {
  # skip_on_cran()

  config = start_flush_redis()

  lg = lgr::get_logger("rush")

  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local", lgr_thresholds = c(rush = "info"))

  capture.output({lg$info("test")})
  expect_data_table(rush$lgr_buffer$dt, nrows = 1)

  rush$write_log()
  expect_data_table(rush$lgr_buffer$dt, nrows = 0)
  expect_data_table(rush$read_log(rush$worker_id), nrows = 1)

  capture.output({lg$info("test_2")})
  rush$write_log()
  expect_data_table(rush$read_log(rush$worker_id), nrows = 2)
})

test_that("pushing tasks and terminating worker works", {
  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, host = "local")
  expect_false(rush$terminated)
  expect_false(rush$terminated_on_idle)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss, terminate_workers = TRUE)
  expect_false(rush$terminated)
  expect_false(rush$terminated_on_idle)

  rush$pop_task()
  expect_false(rush$terminated)
  expect_true(rush$terminated_on_idle)
})

