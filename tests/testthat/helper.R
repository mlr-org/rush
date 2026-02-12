start_flush_redis = function() {
  config = redux::redis_config()
  r = redux::hiredis(config)
  r$FLUSHDB()
  config
}

expect_rush_task = function(task) {
  expect_list(task)
  expect_names(names(task), must.include = c("key", "xs"))
  expect_list(task, names = "unique")
}

expect_rush_reset = function(rush, type = "kill") {
  remove_rush_plan()
  processes_processx = rush$processes_processx
  processes_mirai = rush$processes_mirai
  rush$reset(type = type)
  Sys.sleep(1)
  remaining_keys = rush$connector$command(c("KEYS", "*"))
  if (length(remaining_keys)) {
    print(remaining_keys)
  }
  expect_list(rush$connector$command(c("KEYS", "*")), len = 0)
  walk(processes_processx, function(p) p$kill())
  walk(processes_mirai, function(p) stop_mirai(p))
  mirai::daemons(0)
}

test_worker_loop = function(rush) {
  while(!rush$terminated && !rush$terminated_on_idle) {
    task = rush$pop_task(fields = c("xs"))
    if (!is.null(task)) {
      tryCatch({
        fun = function(x1, x2) list(y = x1 + x2)
        ys = mlr3misc::invoke(fun, .args = task$xs)
        rush$push_results(task$key, yss = list(ys))
      }, error = function(e) {
        condition = list(message = e$message)
        rush$push_failed(task$key, conditions = list(condition))
      })
    }
  }

  return(NULL)
}

segfault_worker_loop = function(rush) {
  while(!rush$terminated && !rush$terminated_on_idle) {
    task = rush$pop_task(fields = c("xs"))
    if (!is.null(task)) {
      tryCatch({
        get("attach")(structure(list(), class = "UserDefinedDatabase"))
        fun = function(x1, x2) list(y = x1 + x2)
        ys = mlr3misc::invoke(fun, .args = task$xs)
        rush$push_results(task$key, yss = list(ys))
      }, error = function(e) {
        condition = list(message = e$message)
        rush$push_failed(task$key, conditions = list(condition))
      })
    }
  }

  return(NULL)
}

