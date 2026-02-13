start_flush_redis = function() {
  config = redux::redis_config()
  r = redux::hiredis(config)
  r$FLUSHDB()
  config
}

expect_rush_reset = function(rush) {
  remove_rush_plan()
  processes_processx = rush$processes_processx
  rush$reset()
  Sys.sleep(1)
  walk(processes_processx, function(p) p$kill())
  mirai::daemons(0)
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
