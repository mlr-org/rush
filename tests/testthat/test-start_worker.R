skip_if_no_redis()

test_that("start_worker errors informatively when start arguments are missing", {
  config = redis_configuration()

  expect_error(
    start_worker(network_id = "test-rush", config = config),
    "No start arguments found for network 'test-rush'"
  )
})

test_that("start_worker registers the compute profile and passes it to the worker loop", {
  config = redis_configuration()
  rush = rsh(network_id = "test-rush", config = config)
  on.exit(rush$reset())

  # pushes the worker config to redis without starting a worker
  rush$worker_script(worker_loop = wl_profile)
  start_worker(worker_id = "worker-1", network_id = "test-rush", config = config, profile = "cpu")

  expect_equal(rush$worker_info$profile, "cpu")
  expect_equal(rush$fetch_finished_tasks()$y, "cpu")
})
