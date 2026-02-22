mlr3misc::walk(list.files(system.file("testthat", package = "rush"), pattern = "^helper.*\\.[rR]", full.names = TRUE), source)


wl_default = function(rush) {
  while (TRUE) {
    xs = list(x1 = runif(1, 0, 10), x2 = runif(1, 0, 10))
    keys = rush$push_running_tasks(list(xs))
    ys = list(y = xs$x1 + xs$x2)
    rush$finish_tasks(keys, yss = list(ys))
    Sys.sleep(1)
  }

  NULL
}

wl_finished = function(rush) {
  xss = list(list(x1 = 1, x2 = 2))
  keys = rush$push_running_tasks(xss)
  rush$finish_tasks(keys, yss = list(list(y = 3)))
  NULL
}

# pops tasks from the queue and finishes them
wl_queue = function(rush) {
  while (!rush$terminated) {
    task = rush$pop_task(fields = c("xs"))
    if (!is.null(task)) {
      fun = function(x1, x2) list(y = x1 + x2)
      ys = mlr3misc::invoke(fun, .args = task$xs)
      rush$finish_tasks(task$key, yss = list(ys))
    }
  }

  NULL
}

# fails a task with an R error if x1 < 1
wl_fail = function(rush) {
  while (!rush$terminated) {
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

  NULL
}

# simulates a segfault by killing the worker process after adding a running task
wl_segfault = function(rush) {
  xs = list(x1 = 1, x2 = 2)
  rush$push_running_tasks(list(xs))
  Sys.sleep(1)
  tools::pskill(Sys.getpid(), tools::SIGKILL)
}
