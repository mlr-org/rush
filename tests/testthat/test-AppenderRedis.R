test_that("saving logs with redis appender works", {
  skip_on_cran()

  appenders = lgr::get_logger("root")$appenders

  on.exit({
    lgr::get_logger("root")$set_appenders(appenders)
  })

  config = start_flush_redis()

  key = sprintf("%s:%s:%s", "test", "worker_1", "events")

  appender = rush::AppenderRedis$new(
    config = config,
    key = key,
    buffer_size = 0
  )

  root_logger = lgr::get_logger("root")
  root_logger$add_appender(appender)
  root_logger$remove_appender("console")
  lg = lgr::get_logger("mlr3/rush")

  root_logger$info("test-1")

  r = redux::hiredis(config)
  logs = r$command(c("LRANGE", key, 0, -1))
  tab = rbindlist(map(logs, fromJSON))

  expect_data_table(tab, nrows = 1)
  expect_names(colnames(tab), identical.to =  c("level", "timestamp", "logger", "caller", "msg"))
  expect_equal(tab$msg, "test-1")

  root_logger$info("test-2")

  logs = r$command(c("LRANGE", key, 0, -1))
  tab = rbindlist(map(logs, fromJSON))
  expect_data_table(tab, nrows = 2)
  expect_names(colnames(tab), identical.to =  c("level", "timestamp", "logger", "caller", "msg"))
  expect_equal(tab$msg, c("test-1", "test-2"))
  config = start_flush_redis()
})

test_that("settings the buffer size in redis appender works", {
  skip_on_cran()

  appenders = lgr::get_logger("root")$appenders

  on.exit({
    lgr::get_logger("root")$set_appenders(appenders)
  })

  config = start_flush_redis()

  key = sprintf("%s:%s:%s", "test", "worker_1", "events")

  appender = rush::AppenderRedis$new(
    config = config,
    key = key,
    buffer_size = 2
  )

  root_logger = lgr::get_logger("root")
  root_logger$add_appender(appender)
  root_logger$remove_appender("console")
  lg = lgr::get_logger("mlr3/rush")

  r = redux::hiredis(config)

  root_logger$info("test-1")
  logs = r$command(c("LRANGE", key, 0, -1))
  expect_list(logs, len = 0)

  root_logger$info("test-2")
  logs = r$command(c("LRANGE", key, 0, -1))
  expect_list(logs, len = 0)

  root_logger$info("test-3")
  logs = r$command(c("LRANGE", key, 0, -1))
  expect_list(logs, len = 3)
})

test_that("R6 classes can be filtered", {
  skip_on_cran()

  appenders = lgr::get_logger("root")$appenders

  on.exit({
    lgr::get_logger("root")$set_appenders(appenders)
  })

  config = start_flush_redis()

  key = sprintf("%s:%s:%s", "test", "worker_1", "events")

  appender = rush::AppenderRedis$new(
    config = config,
    key = key,
    buffer_size = 0
  )

  appender$add_filter(filter_custom_fields)


  root_logger = lgr::get_logger("root")
  root_logger$add_appender(appender)

  lg = lgr::get_logger("mlr3/rush")
  root_logger$info("test-1", rush = rsh())

  r = redux::hiredis(config)
  logs = r$command(c("LRANGE", key, 0, -1))
  tab = rbindlist(map(logs, fromJSON))
  expect_data_table(tab, nrows = 1)
  expect_names(colnames(tab), identical.to =  c("level", "timestamp", "logger", "caller", "msg"))
  expect_equal(tab$msg, "test-1")
})
