test_that("constructing a rush worker works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  expect_class(rush, "Rush")
  expect_equal(rush$network_id, "test-rush")
  expect_string(rush$worker_id)
  expect_false(rush$remote)
  expect_equal(rush$worker_ids, rush$worker_id)
  expect_equal(rush$running_worker_ids, rush$worker_id)

  expect_rush_reset(rush, type = "terminate")

  # pass worker id
  config = start_flush_redis()
  worker_id = uuid::UUIDgenerate()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE, worker_id = worker_id)
  expect_equal(rush$worker_id, worker_id)

  expect_rush_reset(rush, type = "terminate")
})

test_that("active bindings work after construction", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

  expect_equal(rush$n_workers, 1)

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

  expect_rush_reset(rush, type = "terminate")
})

test_that("a worker is registered", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

  # check meta data from redis
  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 1)
  expect_names(names(worker_info), permutation.of = c("worker_id", "pid", "remote", "hostname", "heartbeat", "state"))
  expect_equal(worker_info$worker_id, rush$worker_id)
  expect_false(worker_info$remote)
  expect_equal(worker_info$pid, Sys.getpid())
  expect_equal(rush$worker_ids, rush$worker_id)
  expect_equal(rush$worker_info$state, "running")

  expect_rush_reset(rush, type = "terminate")
})

test_that("a worker is terminated", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  expect_equal(rush$running_worker_ids, rush$worker_id)

  rush$set_terminated()
  expect_null(rush$running_worker_ids)
  expect_equal(rush$terminated_worker_ids, rush$worker_id)

  expect_rush_reset(rush, type = "terminate")
})

test_that("pushing a task to the queue works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

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
  expect_names(names(data), must.include = c("x1", "x2", "keys"))
  expect_data_table(data, nrows = 1)
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  # status checks
  expect_false(rush$is_running_task(keys))
  expect_false(rush$is_failed_task(keys))

  expect_rush_reset(rush, type = "terminate")
})

test_that("pushing a task with extras to the queue works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

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
  expect_names(names(data), must.include = c("x1", "x2", "timestamp", "keys"))
  expect_data_table(data, nrows = 1)
  expect_equal(data$timestamp, timestamp)
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  # status checks
  expect_false(rush$is_running_task(keys))
  expect_false(rush$is_failed_task(keys))

  expect_rush_reset(rush, type = "terminate")
})

test_that("pushing tasks to the queue works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

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
  expect_names(names(data), must.include = c("x1", "x2", "keys"))
  expect_data_table(data, nrows = 2)
  expect_character(data$keys, unique = TRUE, len = 2)
  expect_data_table(rush$fetch_tasks(), nrows = 2)

  # status checks
  expect_false(any(rush$is_running_task(keys)))
  expect_false(any(rush$is_failed_task(keys)))

  expect_rush_reset(rush, type = "terminate")
})

test_that("pushing tasks with extras to the queue works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

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
  expect_names(names(data), must.include = c("x1", "x2", "timestamp", "keys"))
  expect_data_table(data, nrows = 2)
  expect_character(data$keys, unique = TRUE, len = 2)
  expect_equal(data$timestamp, c(timestamp, timestamp))
  expect_data_table(rush$fetch_tasks(), nrows = 2)

  # status checks
  expect_false(any(rush$is_running_task(keys)))
  expect_false(any(rush$is_failed_task(keys)))

  expect_rush_reset(rush, type = "terminate")
})

test_that("popping a task from the queue works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "keys"))
  expect_data_table(data, nrows = 1)
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  # status checks
  expect_true(rush$is_running_task(task$key))
  expect_false(rush$is_failed_task(task$key))

  expect_rush_reset(rush, type = "terminate")
})

test_that("popping a task with max_retries and timeout works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  xss = list(list(x1 = 1, x2 = 2))
  max_retries = 2
  timeout = 1
  rush$push_tasks(xss, max_retries = max_retries, timeouts = timeout)

  # check task
  task = rush$pop_task(fields = c("xs", "max_retries", "timeout"))
  expect_equal(task$max_retries, max_retries)
  expect_equal(task$timeout, timeout)
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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "keys"))
  expect_data_table(data, nrows = 1)
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  # status checks
  expect_true(rush$is_running_task(task$key))
  expect_false(rush$is_failed_task(task$key))

  expect_rush_reset(rush, type = "terminate")
})

test_that("pushing a finished task works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "y", "keys"))
  expect_data_table(data, nrows = 1)
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  # status checks
  expect_false(rush$is_running_task(task$key))
  expect_false(rush$is_failed_task(task$key))

  expect_rush_reset(rush, type = "terminate")
})

test_that("pushing a failed tasks works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss)
  task = rush$pop_task()

  rush$push_failed(task$key, conditions = list(list(message = "error")))

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
  expect_names(names(data), must.include = c("x1", "x2", "worker_id", "message", "keys"))
  expect_data_table(data, nrows = 1)
  expect_data_table(rush$fetch_tasks(), nrows = 1)

  # status checks
  expect_false(rush$is_running_task(task$key))
  expect_true(rush$is_failed_task(task$key))

  expect_rush_reset(rush, type = "terminate")
})

test_that("moving and fetching tasks works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

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
  rush$push_failed(task$key, conditions = list(list(message = "error")))
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

  expect_rush_reset(rush, type = "terminate")
})

test_that("moving a queued task to failed works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss)
  queued_tasks = rush$queued_tasks
  rush$push_failed(queued_tasks, conditions = list(list(message = "error")))
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 1)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3))
  rush$push_tasks(xss)
  task = rush$pop_task()

  rush$push_failed(task$key, conditions = list(list(message = "error")))

  expect_data_table(rush$fetch_queued_tasks(), nrows = 1)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 2)
  expect_set_equal(rush$failed_tasks, c(task$key, queued_tasks))

  queued_tasks = rush$queued_tasks
  rush$push_failed(queued_tasks, conditions = list(list(message = "error")))
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 3)

  xss = list(list(x1 = 1, x2 = 4), list(x1 = 1, x2 = 5))
  rush$push_tasks(xss)
  queued_tasks = rush$queued_tasks
  rush$push_failed(queued_tasks, conditions = replicate(2, list(message = "error"), simplify = FALSE))

  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 5)

  expect_rush_reset(rush, type = "terminate")
})

test_that("fetch task with states works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)

  # queued
  expect_equal(rush$n_queued_tasks, 1)
  expect_data_table(rush$fetch_tasks_with_state(states = "finished"), nrows = 0)
  expect_data_table(rush$fetch_tasks_with_state(states = c("running", "finished")), nrows = 0)
  tab = rush$fetch_tasks_with_state(states = "queued")
  expect_data_table(tab, nrows = 1)
  expect_names(names(tab), must.include = "state")

  # running
  task = rush$pop_task(fields = c("xs"))
  tab = rush$fetch_tasks_with_state()
  expect_data_table(tab, nrows = 1)
  expect_equal(tab$state, "running")

  # finished
  rush$push_results(task$key, list(list(y = 3)))
  tab = rush$fetch_tasks_with_state()
  expect_data_table(tab, nrows = 1)
  expect_equal(tab$state, "finished")

  # failed
  xss = list(list(x1 = 2, x2 = 2))
  rush$push_tasks(xss)
  task_2 = rush$pop_task()
  rush$push_failed(task_2$key, conditions = list(list(message = "error")))
  tab = rush$fetch_tasks_with_state()
  expect_data_table(tab, nrows = 2)
  expect_equal(tab$state, c("finished", "failed"))
})

test_that("latest results are fetched", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

  # add 1 task
  rush$push_tasks(list(list(x1 = 1, x2 = 2)))
  task = rush$pop_task()
  rush$push_results(task$key, list(list(y = 3)))

  latest_results = rush$fetch_new_tasks()
  expect_data_table(latest_results, nrows = 1)
  expect_set_equal(latest_results$y, 3)
  expect_data_table(rush$fetch_new_tasks(), nrows = 0)

  # add 1 task
  keys = rush$push_tasks(list(list(x1 = 1, x2 = 3)))
  task = rush$pop_task()
  rush$push_results(task$key, list(list(y = 4)))

  latest_results = rush$fetch_new_tasks()
  expect_data_table(latest_results, nrows = 1)
  expect_set_equal(latest_results$y, 4)
  expect_data_table(rush$fetch_new_tasks(), nrows = 0)

  # add 2 tasks
  keys = rush$push_tasks(list(list(x1 = 1, x2 = 4)))
  task = rush$pop_task()
  rush$push_results(task$key, list(list(y = 5)))
  keys = rush$push_tasks(list(list(x1 = 1, x2 = 5)))
  task = rush$pop_task()
  rush$push_results(task$key, list(list(y = 6)))

  latest_results = rush$fetch_new_tasks()
  expect_data_table(latest_results, nrows = 2)
  expect_set_equal(latest_results$y, c(5, 6))
  expect_data_table(rush$fetch_new_tasks(), nrows = 0)

  expect_rush_reset(rush, type = "terminate")
})

test_that("priority queues work", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)

  expect_equal(rush$n_queued_priority_tasks, 0)
  expect_data_table(rush$fetch_priority_tasks(), nrows = 0)
  expect_data_table(rush$priority_info, nrows = 0)

  rush_1 = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  rush_2 = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

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

  expect_rush_reset(rush, type = "terminate")
})

test_that("redirecting to shared queue works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)

  rush_1 = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  rush_2 = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

  keys = rush$push_priority_tasks(list(list(x1 = 1, x2 = 2)), priority = rush_1$worker_id)

  expect_equal(rush$n_queued_tasks, 0)
  expect_equal(rush$n_queued_priority_tasks, 1)
  expect_data_table(rush$fetch_priority_tasks(), nrows = 1)
  expect_null(rush_2$pop_task())
  expect_rush_task(rush_1$pop_task())

  keys = rush$push_priority_tasks(list(list(x1 = 2, x2 = 2)), priority = uuid::UUIDgenerate())
  expect_equal(rush$n_queued_tasks, 1)
  expect_equal(rush$n_queued_priority_tasks, 0)
  expect_rush_task(rush_1$pop_task())

  rush_1$set_terminated()
  keys = rush$push_priority_tasks(list(list(x1 = 1, x2 = 2)), priority = rush_1$worker_id)
  expect_equal(rush$n_queued_tasks, 1)
  expect_equal(rush$n_queued_priority_tasks, 0)

  expect_rush_reset(rush, type = "terminate")
})

test_that("mixing priority queue and shared queue works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = Rush$new(network_id = "test-rush", config = config)

  rush_1 = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  rush_2 = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

  keys = rush$push_priority_tasks(list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 2)), priority = c(rush_1$worker_id, NA_character_))

  expect_equal(rush$n_queued_tasks, 1)
  expect_equal(rush$n_queued_priority_tasks, 1)
  expect_data_table(rush$fetch_priority_tasks(), nrows = 1)
  expect_rush_task(rush_2$pop_task())
  expect_null(rush_2$pop_task())
  expect_rush_task(rush_1$pop_task())

  expect_rush_reset(rush, type = "terminate")
})

test_that("pushing tasks and terminating worker works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  expect_false(rush$terminated)
  expect_false(rush$terminated_on_idle)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss, terminate_workers = TRUE)
  expect_false(rush$terminated)
  expect_false(rush$terminated_on_idle)

  rush$pop_task()
  expect_false(rush$terminated)
  expect_true(rush$terminated_on_idle)

  expect_rush_reset(rush, type = "terminate")
})

test_that("terminate on idle works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)

  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss, terminate_workers = TRUE)
  expect_false(rush$terminated_on_idle)

  rush$pop_task()
  expect_true(rush$terminated_on_idle)

  expect_rush_reset(rush, type = "terminate")
})


# atomic operations -----------------------------------------------------------

test_that("task in states works", {
  skip_on_cran()

  config = start_flush_redis()
  rush = RushWorker$new(network_id = "test-rush", config = config, remote = FALSE)
  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_tasks(xss)

  keys_list = rush$tasks_with_state(c("queued", "running", "finished", "failed"))
  expect_list(keys_list, len = 4)
  expect_names(names(keys_list), identical.to = c("queued", "running", "finished", "failed"))
  expect_equal(keys_list$queued, keys)
  expect_null(keys_list$running)
  expect_null(keys_list$finished)
  expect_null(keys_list$failed)
  # switch order
  keys_list = rush$tasks_with_state(c("running", "queued", "finished", "failed"))
  expect_equal(keys_list$queued, keys)


  task = rush$pop_task()
  keys_list = rush$tasks_with_state(c("queued", "running", "finished", "failed"))
  expect_list(keys_list, len = 4)
  expect_names(names(keys_list), identical.to = c("queued", "running", "finished", "failed"))
  expect_equal(keys_list$running, keys)
  expect_null(keys_list$queued)
  expect_null(keys_list$finished)
  expect_null(keys_list$failed)

  rush$push_results(task$key, list(list(y = 3)))
  keys_list = rush$tasks_with_state(c("queued", "running", "finished", "failed"))
  expect_list(keys_list, len = 4)
  expect_names(names(keys_list), identical.to = c("queued", "running", "finished", "failed"))
  expect_null(keys_list$queued)
  expect_null(keys_list$running)
  expect_equal(keys_list$finished, task$key)
  expect_null(keys_list$failed)

  xss = list(list(x1 = 2, x2 = 2))
  keys = rush$push_tasks(xss)
  task_2 = rush$pop_task()
  rush$push_failed(task_2$key, conditions = list(list(message = "error")))
  keys_list = rush$tasks_with_state(c("queued", "running", "finished", "failed"))
  expect_list(keys_list, len = 4)
  expect_names(names(keys_list), identical.to = c("queued", "running", "finished", "failed"))
  expect_null(keys_list$queued)
  expect_null(keys_list$running)
  expect_equal(keys_list$finished, task$key)
  expect_equal(keys_list$failed, task_2$key)

  keys_list = rush$tasks_with_state(c("queued"))
  expect_list(keys_list, len = 1)
  expect_names(names(keys_list), identical.to = c("queued"))
  expect_null(keys_list$queued)

  keys_list = rush$tasks_with_state(c("queued", "running"))
  expect_list(keys_list, len = 2)
  expect_names(names(keys_list), identical.to = c("queued", "running"))
  expect_null(keys_list$queued)
  expect_null(keys_list$running)

  keys_list = rush$tasks_with_state(c("queued", "running", "finished"))
  expect_list(keys_list, len = 3)
  expect_names(names(keys_list), identical.to = c("queued", "running", "finished"))
  expect_null(keys_list$queued)
  expect_null(keys_list$running)
  expect_equal(keys_list$finished, task$key)
})
