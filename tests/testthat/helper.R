skip_if_no_redis = function() {
  testthat::skip_on_cran()

  if (identical(Sys.getenv("RUSH_TEST_USE_REDIS"), "true") && redux::redis_available()) {
    return(invisible())
  }

  testthat::skip("Redis is not available")
}

redis_configuration = function() {
  config = redux::redis_config()
  r = redux::hiredis(config)
  r$FLUSHDB()
  config
}

start_rush = function(n_workers = 2) {
  config = redis_configuration()

  rush_plan(n_workers = n_workers)
  rush = rsh(config = config)

  mirai::daemons(n_workers)

  rush
}

start_rush_worker = function(n_workers = 2) {
  config = redis_configuration()

  network_id = uuid::UUIDgenerate()
  rush::RushWorker$new(network_id = network_id, config = config)
}

# parses the string returned by rush$worker_script() and starts a processx process
start_script_worker = function(script) {
  script = sub('^Rscript\\s+-e\\s+\\"(.*)\\"$', '\\1', script, perl = TRUE)

  px = processx::process$new("Rscript",
    args = c("-e", script),
    supervise = TRUE,
    stderr = "|", stdout = "|")
  px
}

queue_worker_loop = function(rush) {
  while(!rush$terminated) {
    task = rush$pop_task(fields = c("xs"))
    if (!is.null(task)) {
      tryCatch({
        fun = function(x1, x2) list(y = x1 + x2)
        ys = mlr3misc::invoke(fun, .args = task$xs)
        rush$finish_tasks(task$key, yss = list(ys))
      }, error = function(e) {
        condition = list(message = e$message)
        rush$fail_tasks(task$key, conditions = list(condition))
      })
    }
  }

  NULL
}

fail_worker_loop = function(rush) {
  while(!rush$terminated) {
    task = rush$pop_task(fields = c("xs"))

    if (!is.null(task)) {
      if (task$xs$x1 < 1) {
        condition = list(message = "Test error")
        rush$fail_tasks(task$key, conditions = list(condition))
      } else {
        fun = function(x1, x2, ...) {
          list(y = x1 + x2)
        }
        ys = mlr3misc::invoke(fun, .args = task$xs)
        rush$finish_tasks(task$key, yss = list(ys))
      }
    }
  }

  return(NULL)
}

segfault_worker_loop = function(rush) {
  xs = list(x1 = 1, x2 = 2)
  rush$push_running_tasks(list(xs))
  Sys.sleep(1)
  get("attach")(structure(list(), class = "UserDefinedDatabase"))
}
