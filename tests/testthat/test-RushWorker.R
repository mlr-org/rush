skip_if_no_redis()

# starting worker and terminating ----------------------------------------------

test_that("constructing a rush worker works", {
  config = redux::redis_config()
  r = redux::hiredis(config)
  r$FLUSHDB()

  rush = RushWorker$new(network_id = "test-rush", config = config)

  expect_class(rush, "RushWorker")
  expect_equal(rush$network_id, "test-rush")
  expect_string(rush$worker_id)
  expect_equal(rush$worker_ids, rush$worker_id)
  expect_equal(rush$running_worker_ids, rush$worker_id)
})

test_that("active bindings work after construction", {
  rush = start_rush_worker()

  expect_equal(rush$n_workers, 1)
  expect_equal(rush$n_queued_tasks, 0)
  expect_equal(rush$n_running_tasks, 0)
  expect_equal(rush$n_finished_tasks, 0)
  expect_equal(rush$n_failed_tasks, 0)
  expect_null(rush$queued_tasks)
  expect_null(rush$running_tasks)
  expect_null(rush$finished_tasks)
  expect_null(rush$failed_tasks)
})

test_that("a worker is registered", {
  rush = start_rush_worker()

  worker_info = rush$worker_info
  expect_data_table(worker_info, nrows = 1)
  expect_names(names(worker_info), permutation.of = c("worker_id", "pid", "hostname", "heartbeat", "state"))
  expect_equal(worker_info$worker_id, rush$worker_id)
  expect_equal(worker_info$pid, Sys.getpid())
  expect_equal(rush$worker_ids, rush$worker_id)
  expect_equal(rush$worker_info$state, "running")
})

test_that("a worker is terminated", {
  rush = start_rush_worker()

  expect_equal(rush$running_worker_ids, rush$worker_id)
  rush$set_terminated()
  expect_null(rush$running_worker_ids)
  expect_equal(rush$terminated_worker_ids, rush$worker_id)
})

# low level read and write -----------------------------------------------------

test_that("reading and writing a hash works with flatten", {
  rush = start_rush_worker()

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
  rush = start_rush_worker()

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
  rush = start_rush_worker()

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
  rush = start_rush_worker()

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
  rush = start_rush_worker()

  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)), xs_extra = list(list(extra = list("A"))))
  rush$finish_tasks(keys, yss = list(list(y = 3)))

  expect_list(rush$fetch_finished_tasks()$extra, len = 1)
  rush$reset(workers = FALSE)

  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2)), xs_extra = list(list(extra = list(letters[1:3]))))
  rush$finish_tasks(keys, yss = list(list(y = 3)))

  expect_list(rush$fetch_finished_tasks()$extra, len = 1)
  rush$reset(workers = FALSE)

  keys = rush$write_hashes(xs = list(list(x1 = 1, x2 = 2), list(x1 = 2, x2 = 2)), xs_extra = list(list(extra = list("A")), list(extra = list("B"))))
  rush$finish_tasks(keys, yss = list(list(y = 3), list(y = 4)))

  expect_list(rush$fetch_finished_tasks()$extra, len = 2)
})


# moving tasks between states --------------------------------------------------

test_that("popping a task works", {
  rush = start_rush_worker()

  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss)

  # check task
  task = rush$pop_task()
  expect_list(task)
  expect_names(names(task), must.include = c("key", "xs"))
  expect_list(task, names = "unique")

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

  expect_rush_reset(rush)
})

test_that("finishing a task works", {
  rush = start_rush_worker()

  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss)
  task = rush$pop_task()

  rush$finish_tasks(task$key, list(list(y = 3)))

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

  expect_rush_reset(rush)
})

test_that("failing a tasks works", {
  rush = start_rush_worker()
  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss)
  task = rush$pop_task()

  rush$fail_tasks(task$key, conditions = list(list(message = "error")))

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

  expect_rush_reset(rush)
})

test_that("moving and fetching tasks works", {
  rush = start_rush_worker()

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

  # finish task
  rush$pop_task()
  rush$finish_tasks(task$key, list(list(y = 3)))
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

  # fail task
  task = rush$pop_task()
  rush$fail_tasks(task$key, conditions = list(list(message = "error")))
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

test_that("moving a queued task to failed works", {
  rush = start_rush_worker()

  xss = list(list(x1 = 1, x2 = 2))
  rush$push_tasks(xss)
  queued_tasks = rush$queued_tasks
  rush$fail_tasks(queued_tasks, conditions = list(list(message = "error")))
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 1)

  xss = list(list(x1 = 1, x2 = 2), list(x1 = 1, x2 = 3))
  rush$push_tasks(xss)
  task = rush$pop_task()

  rush$fail_tasks(task$key, conditions = list(list(message = "error")))

  expect_data_table(rush$fetch_queued_tasks(), nrows = 1)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 2)
  expect_set_equal(rush$failed_tasks, c(task$key, queued_tasks))

  queued_tasks = rush$queued_tasks
  rush$fail_tasks(queued_tasks, conditions = list(list(message = "error")))
  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 3)

  xss = list(list(x1 = 1, x2 = 4), list(x1 = 1, x2 = 5))
  rush$push_tasks(xss)
  queued_tasks = rush$queued_tasks
  rush$fail_tasks(queued_tasks, conditions = replicate(2, list(message = "error"), simplify = FALSE))

  expect_data_table(rush$fetch_queued_tasks(), nrows = 0)
  expect_data_table(rush$fetch_failed_tasks(), nrows = 5)

  expect_rush_reset(rush)
})

test_that("fetch task with states works", {
  rush = start_rush_worker()

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
  rush$finish_tasks(task$key, list(list(y = 3)))
  tab = rush$fetch_tasks_with_state()
  expect_data_table(tab, nrows = 1)
  expect_equal(tab$state, "finished")

  # failed
  xss = list(list(x1 = 2, x2 = 2))
  rush$push_tasks(xss)
  task_2 = rush$pop_task()
  rush$fail_tasks(task_2$key, conditions = list(list(message = "error")))
  tab = rush$fetch_tasks_with_state()
  expect_data_table(tab, nrows = 2)
  expect_equal(tab$state, c("finished", "failed"))
})

test_that("latest results are fetched", {
  rush = start_rush_worker()

  # add 1 task
  rush$push_tasks(list(list(x1 = 1, x2 = 2)))
  task = rush$pop_task()
  rush$finish_tasks(task$key, list(list(y = 3)))

  latest_results = rush$fetch_new_tasks()
  expect_data_table(latest_results, nrows = 1)
  expect_set_equal(latest_results$y, 3)
  expect_data_table(rush$fetch_new_tasks(), nrows = 0)

  # add 1 task
  keys = rush$push_tasks(list(list(x1 = 1, x2 = 3)))
  task = rush$pop_task()
  rush$finish_tasks(task$key, list(list(y = 4)))

  latest_results = rush$fetch_new_tasks()
  expect_data_table(latest_results, nrows = 1)
  expect_set_equal(latest_results$y, 4)
  expect_data_table(rush$fetch_new_tasks(), nrows = 0)

  # add 2 tasks
  keys = rush$push_tasks(list(list(x1 = 1, x2 = 4)))
  task = rush$pop_task()
  rush$finish_tasks(task$key, list(list(y = 5)))
  keys = rush$push_tasks(list(list(x1 = 1, x2 = 5)))
  task = rush$pop_task()
  rush$finish_tasks(task$key, list(list(y = 6)))

  latest_results = rush$fetch_new_tasks()
  expect_data_table(latest_results, nrows = 2)
  expect_set_equal(latest_results$y, c(5, 6))
  expect_data_table(rush$fetch_new_tasks(), nrows = 0)

  expect_rush_reset(rush)
})

test_that("pushing finished tasks works", {
  rush = start_rush_worker()

  rush$push_finished_tasks(list(list(x1 = 1, x2 = 2)), list(list(y = 3)), xss_extra = list(list(extra_input = "A")), yss_extra = list(list(extra_output = "B")))
  expect_equal(rush$n_finished_tasks, 1)
  expect_equal(rush$n_tasks, 1)
  expect_equal(rush$fetch_finished_tasks()$extra_input, "A")
  expect_equal(rush$fetch_finished_tasks()$extra_output, "B")
})

test_that("pushing failed tasks works", {
  rush = start_rush_worker()

  rush$push_failed_tasks(list(list(x1 = 1, x2 = 2)), conditions = list(list(message = "error")))
  expect_equal(rush$n_failed_tasks, 1)
  expect_equal(rush$n_tasks, 1)
})

# atomic operations -----------------------------------------------------------

test_that("task in states works", {
  rush = start_rush_worker()

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

  rush$finish_tasks(task$key, list(list(y = 3)))
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
  rush$fail_tasks(task_2$key, conditions = list(list(message = "error")))
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
