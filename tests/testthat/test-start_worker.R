skip_if_no_redis()

test_that("start_worker errors informatively when start arguments are missing", {
  config = redis_configuration()

  expect_error(
    start_worker(network_id = "test-rush", config = config),
    "No start arguments found for network 'test-rush'"
  )
})
