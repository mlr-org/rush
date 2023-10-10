# main instance ----------------------------------------------------------------

test_that("constructing a rush controller works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
  expect_class(rush, "Rush")
  expect_equal(rush$instance_id, "test-rush")

  expect_reset_rush(rush)
})

test_that("constructing a rush worker works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")
  expect_class(rush, "Rush")
  expect_equal(rush$instance_id, "test-rush")
  expect_string(rush$worker_id)
  expect_equal(rush$host, "local")

  expect_reset_rush(rush)

  # pass worker id
  config = start_flush_redis()
  worker_id = uuid::UUIDgenerate()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local", worker_id = worker_id)
  expect_equal(rush$worker_id, worker_id)

  expect_reset_rush(rush)
})

test_that("active bindings work after construction", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")

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

  expect_reset_rush(rush)
})

test_that("a worker is registered", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")

  # check meta data from redis
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 1)
  expect_names(names(worker_info), permutation.of = c("worker_id", "pid", "status", "host", "heartbeat"))
  expect_false(worker_info$heartbeat)
  expect_equal(worker_info$worker_id, rush$worker_id)
  expect_equal(worker_info$status, "running")
  expect_equal(worker_info$host, "local")
  expect_equal(worker_info$pid, Sys.getpid())
  expect_equal(rush$worker_ids, rush$worker_id)

  expect_reset_rush(rush)
})

test_that("a heartbeat is started", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local", heartbeat_period = 3)

  expect_class(rush$heartbeat, "r_process")
  expect_true(rush$heartbeat$is_alive())
  expect_true(rush$worker_info$heartbeat)

  expect_reset_rush(rush)
})

test_that("reading and writing a hash works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")

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
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")

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
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")

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

test_that("writting a hash with a status works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")

  # one element
  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)), status = "queued")
  expect_equal(rush$read_hashes(keys, c("xs", "status")), list(list(x1 = 1, x2 = 2, status = "queued")))

  # two elements
  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3)), status = "queued")
  expect_equal(rush$read_hashes(keys, c("xs", "status")), list(list(x1 = 1, x2 = 2, status = "queued"), list(x1 = 1, x2 = 3, status = "queued")))
})

test_that("pushing a task to the queue works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)

  Sys.sleep(1)

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
  expect_names(names(data), must.include = c("x1", "x2", "status", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$status, "queued")
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  expect_reset_rush(rush)
})

test_that("pushing a task with extras to the queue works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")

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
  expect_names(names(data), must.include = c("x1", "x2", "timestamp", "status", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$status, "queued")
  expect_equal(data$timestamp, timestamp)
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  expect_reset_rush(rush)
})

test_that("pushing tasks to the queue works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")

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
  expect_names(names(data), must.include = c("x1", "x2", "status", "keys"))
  expect_data_table(data, nrows = 2)
  expect_character(data$keys, unique = TRUE, len = 2)
  expect_set_equal(data$status, "queued")
  expect_data_table(rush$fetch_tasks(), nrows = 2)

  expect_reset_rush(rush)
})

test_that("pushing tasks with extras to the queue works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")

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
  expect_names(names(data), must.include = c("x1", "x2", "timestamp", "status", "keys"))
  expect_data_table(data, nrows = 2)
  expect_character(data$keys, unique = TRUE, len = 2)
  expect_set_equal(data$status, "queued")
  expect_equal(data$timestamp, c(timestamp, timestamp))
  expect_data_table(rush$fetch_tasks(), nrows = 2)

  expect_reset_rush(rush)
})

test_that("popping a task from the queue works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss)

  # check task
  task = rush$pop_task()
  expect_task(task)

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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "status", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$status, "running")
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  expect_reset_rush(rush)
})

test_that("pushing a finished task works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")
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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "y", "status", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$status, "finished")
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  expect_reset_rush(rush)
})

test_that("pushing a failed tasks works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss)
  task = rush$pop_task()

  rush$push_results(task$key, condition = list(list(message = "error")), status = "failed")

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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "message", "status", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$status, "failed")
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  expect_reset_rush(rush)
})

test_that("moving and fetching tasks works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")

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
  rush$push_results(task$key, condition = list(list(message = "error")), status = "failed")
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

  expect_reset_rush(rush)
})

test_that("latest results are fetched", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local")

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

  expect_reset_rush(rush)
})

test_that("priority queues work", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)

  expect_equal(rush$n_queued_priority_tasks, 0)
  expect_data_table(rush$fetch_priority_tasks(), nrows = 0)
  expect_data_table(rush$priority_info, nrows = 0)

  rush_1 = RushWorker$new(instance_id = "test-rush", config = config, host = "local")
  rush_2 = RushWorker$new(instance_id = "test-rush", config = config, host = "local")

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

  expect_task(rush_2$pop_task())

  expect_equal(rush$n_queued_priority_tasks, 2)
  expect_data_table(rush$fetch_priority_tasks(), nrows = 2)
  priority_info = rush$priority_info
  expect_data_table(priority_info, nrows = 2)
  expect_equal(priority_info[list(rush_1$worker_id), n_tasks, on = "worker_id"], 2)
  expect_equal(priority_info[list(rush_2$worker_id), n_tasks, on = "worker_id"], 0)

  expect_null(rush_2$pop_task())
  expect_task(rush_1$pop_task())
  expect_equal(rush$n_queued_priority_tasks, 1)
  priority_info = rush$priority_info
  expect_data_table(priority_info, nrows = 2)
  expect_equal(priority_info[list(rush_1$worker_id), n_tasks, on = "worker_id"], 1)
  expect_equal(priority_info[list(rush_2$worker_id), n_tasks, on = "worker_id"], 0)

  expect_task(rush_1$pop_task())
  expect_equal(rush$n_queued_priority_tasks, 0)
  expect_set_equal(rush$priority_info$n_tasks, 0)

  expect_reset_rush(rush)
})

test_that("mixing priority queues and default queue work", {

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
  rush_1 = RushWorker$new(instance_id = "test-rush", config = config, host = "local")
  rush_2 = RushWorker$new(instance_id = "test-rush", config = config, host = "local")

  keys = rush$push_priority_tasks(list(list(x1 = 1, x2 = 2), list(x1 = 2, x2 = 2), list(x1 = 3, x2 = 5)), priority = c(rep(rush_1$worker_id, 2), NA_character_))

})

test_that("saving lgr logs works", {
  skip_on_cran()

  config = start_flush_redis()

  lg = lgr::get_logger("rush")

  rush = RushWorker$new(instance_id = "test-rush", config = config, host = "local", lgr_thresholds = c(rush = "debug"))

  lg$info("test")
  expect_data_table(rush$lgr_buffer$dt, nrows = 1)

  rush$write_log()
  expect_data_table(rush$lgr_buffer$dt, nrows = 0)
  expect_data_table(rush$read_log(rush$worker_id), nrows = 1)

  lg$info("test2")
  rush$write_log()
  expect_data_table(rush$read_log(rush$worker_id), nrows = 2)
})

# main instance and future workers ---------------------------------------------

test_that("workers are started", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  expect_data_table(rush$worker_info, nrows = 0)

  future::plan("multisession", workers = 2)
  worker_ids = rush$start_workers(fun = fun, host = "local", await_workers = TRUE)
  expect_equal(rush$n_workers, 2)

  # check fields
  walk(rush$promises, function(promise) expect_class(promise, "Future"))

  # check meta data from redis
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 2)
  expect_integer(worker_info$pid, unique = TRUE)
  expect_set_equal(worker_info$host, "local")
  expect_set_equal(worker_info$status, "running")
  expect_set_equal(worker_ids, worker_info$worker_id)
  expect_set_equal(rush$worker_ids, worker_ids)

  expect_reset_rush(rush)
})

test_that("workers are started with a heartbeat", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  future::plan("multisession", workers = 2)
  worker_ids = rush$start_workers(fun = fun, heartbeat_period = 3, heartbeat_expire = 9)
  rush$await_workers(2)

  # check meta data from redis
  worker_info = rush$worker_info
  expect_true(all(worker_info$heartbeat))

  expect_reset_rush(rush)
})

test_that("additional workers are started", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
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
  expect_set_equal(worker_info$status, "running")
  expect_set_equal(c(worker_ids, worker_ids_2), worker_info$worker_id)

  expect_error(rush$start_workers(fun = fun, n_workers = 2), regexp = "No more than 0 rush workers can be started")

  expect_reset_rush(rush)
})

test_that("a worker is terminated", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, host = "local")
  rush$await_workers(2)
  worker_info = rush$worker_info

  # worker 1
  rush$stop_workers(worker_ids = worker_info$worker_id[1], type = "terminate")
  Sys.sleep(3)
  expect_true(future::resolved(rush$promises[[worker_info$worker_id[1]]]))
  worker_info = rush$worker_info
  expect_equal(worker_info$status[1], "terminated")
  expect_equal(worker_info$status[2], "running")

  # woker 2
  rush$stop_workers(worker_ids = worker_info$worker_id[2], type = "terminate")
  Sys.sleep(3)
  expect_true(future::resolved(rush$promises[[worker_info$worker_id[2]]]))
  worker_info = rush$worker_info
  expect_set_equal(worker_info$status, "terminated")

  expect_reset_rush(rush)
})

test_that("a local worker is killed", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, host = "local")
  rush$await_workers(2)
  worker_info = rush$worker_info

  # worker 1
  rush$stop_workers(worker_ids = worker_info$worker_id[1], type = "kill")
  worker_info = rush$worker_info
  expect_equal(worker_info$status[1], "killed")
  expect_equal(worker_info$status[2], "running")
  expect_error(future::resolved(rush$promises[[worker_info$worker_id[1]]]), class = "FutureError")
  expect_false(future::resolved(rush$promises[[worker_info$worker_id[2]]]))

  # worker 2
  rush$stop_workers(worker_ids = worker_info$worker_id[2], type = "kill")
  worker_info = rush$worker_info
  expect_set_equal(worker_info$status, "killed")
  expect_true(future::resolved(rush$promises[[worker_info$worker_id[1]]]))
  expect_error(future::resolved(rush$promises[[worker_info$worker_id[2]]]), class = "FutureError")

  expect_reset_rush(rush)
})

test_that("a remote worker is killed", {
  # FIXME: heartbeat is broken
  skip_on_cran()
  skip_if(TRUE)
  skip_on_os("windows")

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, host = "remote", heartbeat_period = 3, heartbeat_expire = 9)
  rush$await_workers(2)
  worker_info = rush$worker_info
  expect_true(all(tools::pskill(worker_info$pid, signal = 0L)))

  # worker 1
  rush$stop_workers(worker_ids = worker_info$worker_id[1], type = "kill")
  Sys.sleep(10)
  worker_info = rush$worker_info
  expect_equal(worker_info$status[1], "killed")
  expect_equal(worker_info$status[2], "running")
  expect_false(tools::pskill(worker_info$pid[1], signal = 0L))

  # worker 2
  rush$stop_workers(worker_ids = worker_info$worker_id[2], type = "kill")
  Sys.sleep(10)
  worker_info = rush$worker_info
  expect_set_equal(worker_info$status, "killed")
  expect_false(tools::pskill(worker_info$pid[2], signal = 0L))

  expect_reset_rush(rush)
})

test_that("a segault on a local worker is detected", {
  skip_on_cran()
  skip_on_os("windows")

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
  fun = function(x1, x2, ...) {
    if (x1 < 1) get("attach")(structure(list(), class = "UserDefinedDatabase"))
    list(y = x1 + x2)
  }
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, host = "local")
  rush$await_workers(2)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2))
  rush$push_tasks(xss)
  Sys.sleep(4)
  worker_info = rush$worker_info
  expect_set_equal(worker_info$status, "running")
  rush$detect_lost_workers()
  worker_info = rush$worker_info
  expect_set_equal(worker_info$status, c("running", "lost"))

  expect_reset_rush(rush)
})

test_that("a segault on a worker is detected via the heartbeat", {
  # FIXME: heartbeat is broken
  skip_on_cran()
  skip_if(TRUE)
  skip_on_os("windows")

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
  fun = function(x1, x2, ...) {
    if (x1 < 1) get("attach")(structure(list(), class = "UserDefinedDatabase"))
    list(y = x1 + x2)
  }
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, host = "remote", heartbeat_period = 1, heartbeat_expire = 3)
  rush$await_workers(2)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2))
  rush$push_tasks(xss)
  Sys.sleep(15)
  worker_info = rush$worker_info
  expect_set_equal(worker_info$status, "running")
  rush$detect_lost_workers()
  worker_info = rush$worker_info
  expect_set_equal(worker_info$status, c("running", "lost"))

  expect_reset_rush(rush)
})

test_that("evaluating a task works with future", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  future::plan("multisession", workers = 4)
  rush$start_workers(fun = fun, n_workers = 2)
  rush$await_workers(2)

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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "y", "status", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$status, "finished")
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  expect_reset_rush(rush)
})

test_that("evaluating tasks works with future", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  future::plan("multisession", workers = 4)
  worker_ids = rush$start_workers(fun = fun, n_workers = 2)
  rush$await_workers(2)

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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "y", "status", "keys"))
  expect_data_table(data, nrows = 10)
  expect_set_equal(data$status, "finished")
  expect_data_table(rush$fetch_tasks(), nrows = 10)

  expect_reset_rush(rush)
})

test_that("a simple error is catched", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
  fun = function(x1, x2, ...) {
    if (x1 < 1) stop("Test error")
    list(y = x1 + x2)
  }
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, n_workers = 2)
  rush$await_workers(2)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$await_tasks(keys)

  Sys.sleep(3)

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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "y", "status", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$status, "finished")

  data = rush$fetch_failed_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "message", "status", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$status, "failed")

  expect_reset_rush(rush)
})

test_that("a lost task is detected", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)

  # no task is running
  expect_class(rush$detect_lost_tasks(), "Rush")

  fun = function(x1, x2, ...) {
    if (x1 < 1) get("attach")(structure(list(), class = "UserDefinedDatabase"))
    list(y = x1 + x2)
  }
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, n_workers = 2)
  rush$await_workers(2)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2))
  keys = rush$push_tasks(xss)
  Sys.sleep(5)
  rush$detect_lost_tasks()

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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "y", "status", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$status, "finished")

  data = rush$fetch_failed_tasks()
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "status", "keys"))
  expect_data_table(data, nrows = 1)
  expect_set_equal(data$status, "lost")

  expect_reset_rush(rush)
})

test_that("blocking on new results works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
    fun = function(x1, x2, ...) {
    Sys.sleep(5)
    list(y = x1 + x2)
  }
  future::plan("multisession", workers = 4)
  rush$start_workers(fun = fun, n_workers = 2)
  rush$await_workers(2)
  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)

  expect_data_table(rush$block_latest_results(timeout = 1), nrows = 0)
  expect_data_table(rush$block_latest_results(timeout = 10), nrows = 1)
  expect_data_table(rush$block_latest_results(timeout = 1), nrows = 0)

  expect_reset_rush(rush)
})

test_that("wait for tasks works when a task gets lost", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
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
})

test_that("saving lgr logs works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  future::plan("multisession", workers = 2)
  rush$start_workers(fun = fun, n_workers = 2, lgr_thresholds = c(rush = "debug"))

  xss = list(list(x1 = 2, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$await_tasks(keys)
  Sys.sleep(2)

  log = rush$read_log()
  expect_data_table(log, nrows = 4)
  expect_names(names(log), must.include = c("worker_id", "timestamp", "logger", "msg"))

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 0, x2 = 2), list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$await_tasks(keys)
  Sys.sleep(2)

  log = rush$read_log()
  expect_data_table(log, nrows = 16)
  expect_names(names(log), must.include = c("worker_id", "timestamp", "logger", "msg"))
})

# main instance and script workers ---------------------------------------------

test_that("worker can be started with script", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
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

  system2(command = "Rscript", args = "-e 'rush::start_worker(\"test-rush\", url = \"redis://127.0.0.1:6379\")'", wait = FALSE)
  rush$await_workers(1)
  expect_equal(rush$n_workers, 1)

  system2(command = "Rscript", args = "-e 'rush::start_worker(\"test-rush\", url = \"redis://127.0.0.1:6379\")'", wait = FALSE)
  rush$await_workers(2)
  expect_equal(rush$n_workers, 2)

  # check meta data from redis
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 2)
  expect_integer(worker_info$pid, unique = TRUE)
  expect_set_equal(worker_info$host, "local")
  expect_set_equal(worker_info$status, "running")

  rush$stop_workers()
  Sys.sleep(5)

  expect_reset_rush(rush)
})

test_that("evaluating tasks works with script", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
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

  system2(command = "Rscript", args = "-e 'rush::start_worker(\"test-rush\", url = \"redis://127.0.0.1:6379\")'", wait = FALSE)
  system2(command = "Rscript", args = "-e 'rush::start_worker(\"test-rush\", url = \"redis://127.0.0.1:6379\")'", wait = FALSE)
  rush$await_workers(2)

  xss = replicate(10, list(list(x1 = 1, x2 = 2)))
  keys = rush$push_tasks(xss)
  rush$await_tasks(keys)

  expect_equal(rush$n_finished_tasks, 10)

  rush$stop_workers()
  Sys.sleep(5)

  expect_reset_rush(rush)
})

test_that("packages are available on the worker", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
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

  system2(command = "Rscript", args = "-e 'rush::start_worker(\"test-rush\", url = \"redis://127.0.0.1:6379\")'", wait = FALSE)
  rush$await_workers(1)

  xss = replicate(10, list(list(x1 = 1, x2 = 2)))
  keys = rush$push_tasks(xss)
  rush$await_tasks(keys)

  expect_equal(rush$n_finished_tasks, 10)

  rush$stop_workers()
  Sys.sleep(5)

  expect_reset_rush(rush)
})

test_that("globals are available on the worker", {
  # FIXME: Not working in testthat env
  skip_if(TRUE)
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(instance_id = "test-rush", config = config)
  fun = function(x1, x2, ...) list(y = x)
  x = 33

  rush$create_worker_script(
    worker_loop = fun_loop,
    globals = "x",
    packages = NULL,
    host = "local",
    heartbeat_period = NULL,
    heartbeat_expire = NULL,
    lgr_thresholds = c(rush = "debug"),
    fun = fun)

  system2(command = "Rscript", args = "-e 'rush::start_worker(\"test-rush\", url = \"redis://127.0.0.1:6379\")'", wait = FALSE)
  rush$await_workers(1)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)
  rush$await_tasks(keys)

  expect_equal(rush$n_finished_tasks, 1)
  expect_equal(rush$fetch_finished_tasks()$y, 33)

  rush$stop_workers()
  Sys.sleep(5)

  expect_reset_rush(rush)
})
