runner = function(renv_project, times) {

  system("redis-server --daemonize yes --save \"\" --appendonly no")

  # initialize environment
  res = list()
  renv::load(renv_project)
  res[["project_id"]] = renv::project()

  library(rush)
  library(data.table)
  library(mlr3misc)
  library(microbenchmark)

  start_flush_redis = function() {
    future::plan("sequential")
    config = redux::redis_config()
    r = redux::hiredis(config)
    r$FLUSHDB()
    config
  }

  set.seed(1)
  options(width = 200)
  lgr::get_logger("rush")$set_threshold("warn")

  xdt_1 = data.table(x1 = runif(1), x2 = runif(1))
  xdt_10 = data.table(x1 = runif(10), x2 = runif(10))
  xdt_100 = data.table(x1 = runif(100), x2 = runif(100))
  xdt_1000 = data.table(x1 = runif(1000), x2 = runif(1000))
  xdt_10000 = data.table(x1 = runif(10000), x2 = runif(10000))

  xss_1 = transpose_list(xdt_1)
  xss_10 = transpose_list(xdt_10)
  xss_100 = transpose_list(xdt_100)
  xss_1000 = transpose_list(xdt_1000)
  xss_10000 = transpose_list(xdt_10000)

  extra_1 = list(list(extra1 = runif(1)))
  extra_10 = replicate(10, list(list(extra1 = runif(1))))
  extra_100 = replicate(100, list(list(extra1 = runif(1))))
  extra_1000 = replicate(1000, list(list(extra1 = runif(1))))
  extra_10000 = replicate(10000, list(list(extra1 = runif(1))))



  # Initializing Rush Controller
  config = start_flush_redis()

  res[["bm_init_rush"]] = microbenchmark(
    controller = Rush$new("benchmark", config),
    times = times,
    unit = "ms"
  )

  # Initializing Rush Worker
  config = start_flush_redis()

  res[["bm_init_worker"]] = microbenchmark(
    worker = RushWorker$new("benchmark", config, host = "local"),
    times = times,
    unit = "ms"
  )

  # Starting Worker Loop with Future
  config = start_flush_redis()
  rush = Rush$new("benchmark", config)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  setup = function() {
    start_flush_redis()
    future::plan("cluster", workers = 1)
  }

  res[["bm_init_future"]] = microbenchmark(
    future = rush$start_workers(fun, host = "local", await_workers = TRUE),
    times = times,
    unit = "ms",
    setup = setup()
  )

  # Starting Rush Worker with Heatbeat
  config = start_flush_redis()
  rush = Rush$new("benchmark", config)
  fun = function(x1, x2, ...) list(y = x1 + x2)

  setup = function() {
    start_flush_redis()
    future::plan("cluster", workers = 1)
  }

  res[["bm_init_heartbeat"]] = microbenchmark(
    heartbeat = rush$start_workers(fun, host = "local", heartbeat_period = 3, await_workers = TRUE),
    times = times,
    unit = "ms",
    setup = setup()
  )

  # Push Task
  config = start_flush_redis()
  rush = Rush$new("benchmark", config)

  res[["bm_push_task"]] = microbenchmark(
    push_task_1 = rush$push_tasks(list(xss_1)),
    push_task_10 = rush$push_tasks(xss_10),
    push_task_100 = rush$push_tasks(xss_100),
    push_task_1000 = rush$push_tasks(xss_1000),
    push_task_10000 = rush$push_tasks(xss_10000),
    times = times,
    unit = "ms",
    setup = rush$reset()
  )

  # Push Priority Task
  config = start_flush_redis()
  rush = Rush$new("benchmark", config)
  worker_id = RushWorker$new("benchmark", config, host = "local")$worker_id

  priority_queue_1 = rep(worker_id, 1)
  priority_queue_10 = rep(worker_id, 10)
  priority_queue_100 = rep(worker_id, 100)
  priority_queue_1000 = rep(worker_id, 1000)
  priority_queue_10000 = rep(worker_id, 10000)

  res[["bm_push_priority"]] = microbenchmark(
    push_task_1 = rush$push_priority_tasks(list(xss_1), priority = priority_queue_1),
    push_task_10 = rush$push_priority_tasks(xss_10, priority = priority_queue_10),
    push_task_100 = rush$push_priority_tasks(xss_100, priority = priority_queue_100),
    push_task_1000 = rush$push_priority_tasks(xss_1000, priority = priority_queue_1000),
    push_task_10000 = rush$push_priority_tasks(xss_10000, priority = priority_queue_10000),
    times = times,
    unit = "ms"
  )

  # Push Task with Extra
  config = start_flush_redis()
  rush = Rush$new("benchmark", config)

  res[["bm_push_extra"]] = microbenchmark(
    push_extra_1 = rush$push_tasks(list(xss_1), extra = extra_1),
    push_extra_10 = rush$push_tasks(xss_10, extra = extra_10),
    push_extra_100 = rush$push_tasks(xss_100, extra = extra_100),
    push_extra_1000 = rush$push_tasks(xss_1000, extra = extra_1000),
    push_extra_10000 = rush$push_tasks(xss_10000, extra = extra_10000),
    times = times,
    setup = rush$reset(),
    unit = "ms"
  )

  # Pop Task
  config = start_flush_redis()
  rush_1 = RushWorker$new("benchmark_1", config, host = "local")

  setup = function(rush, xss) {
    rush$reset()
    rush$push_tasks(xss)
  }

  res[["bm_pop_1"]] = microbenchmark(
    pop_1 = rush_1$pop_task(),
    times = times,
    unit = "ms",
    setup = setup(rush_1, list(xss_1))
  )

  config = start_flush_redis()
  rush_10 = RushWorker$new("benchmark_10", config, host = "local")

  setup = function(rush, xss) {
    rush$reset()
    rush$push_tasks(xss)
  }

  res[["bm_pop_10"]] =  microbenchmark(
    pop_10 = rush_10$pop_task(),
    times = times,
    unit = "ms",
    setup = setup(rush_10, xss_10)
  )

  config = start_flush_redis()
  rush_100 = RushWorker$new("benchmark_100", config, host = "local")

  setup = function(rush, xss) {
    rush$reset()
    rush$push_tasks(xss)
  }

  res[["bm_pop_100"]] = microbenchmark(
    pop_100 = rush_100$pop_task(),
    times = times,
    unit = "ms",
    setup = setup(rush_100, xss_100)
  )

  config = start_flush_redis()
  rush_1000 = RushWorker$new("benchmark_1000", config, host = "local")

  setup = function(rush, xss) {
    rush$reset()
    rush$push_tasks(xss)
  }

  res[["bm_pop_1000"]] = microbenchmark(
    pop_1000 = rush_1000$pop_task(),
    times = times,
    unit = "ms",
    setup = setup(rush_1000, xss_1000)
  )

  config = start_flush_redis()
  rush_10000 = RushWorker$new("benchmark_10000", config, host = "local")

  setup = function(rush, xss) {
    rush$reset()
    rush$push_tasks(xss)
  }

  res[["bm_pop_10000"]] = microbenchmark(
    pop_10000 = rush_10000$pop_task(),
    times = times,
    unit = "ms",
    setup = setup(rush_10000, xss_10000)
  )

  # Fetch Queued Tasks
  config = start_flush_redis()
  rush_1 = RushWorker$new("benchmark_1", config, host = "local")
  rush_10 = RushWorker$new("benchmark_10", config, host = "local")
  rush_100 = RushWorker$new("benchmark_100", config, host = "local")
  rush_1000 = RushWorker$new("benchmark_1000", config, host = "local")
  rush_10000 = RushWorker$new("benchmark_10000", config, host = "local")

  setup = function(rush, xss) {
    rush$push_tasks(xss)
  }

  setup(rush_1, list(xss_1))
  setup(rush_10, xss_10)
  setup(rush_100, xss_100)
  setup(rush_1000, xss_1000)
  setup(rush_10000, xss_10000)

  res[["bm_fetch_queued"]] = microbenchmark(
    rush_1 = rush_1$fetch_queued_tasks(),
    rush_10 = rush_10$fetch_queued_tasks(),
    rush_100 = rush_100$fetch_queued_tasks(),
    rush_1000 = rush_1000$fetch_queued_tasks(),
    rush_10000 = rush_10000$fetch_queued_tasks(),
    times = times,
    unit = "ms"
  )

  # Fetch Running Tasks
  config = start_flush_redis()
  rush_1 = RushWorker$new("benchmark_1", config, host = "local")
  rush_10 = RushWorker$new("benchmark_10", config, host = "local")
  rush_100 = RushWorker$new("benchmark_100", config, host = "local")
  rush_1000 = RushWorker$new("benchmark_1000", config, host = "local")
  rush_10000 = RushWorker$new("benchmark_10000", config, host = "local")

  setup = function(rush, xss) {
    keys = rush$push_tasks(xss)
    rush$connector$command(c("SADD", sprintf("%s:running_tasks", rush$instance_id), keys))
  }

  setup(rush_1, list(xss_1))
  setup(rush_10, xss_10)
  setup(rush_100, xss_100)
  setup(rush_1000, xss_1000)
  setup(rush_10000, xss_10000)

  res[["bm_fetch_running"]] = microbenchmark(
    rush_1 = rush_1$fetch_running_tasks(),
    rush_10 = rush_10$fetch_running_tasks(),
    rush_100 = rush_100$fetch_running_tasks(),
    rush_1000 = rush_1000$fetch_running_tasks(),
    rush_10000 = rush_10000$fetch_running_tasks(),
    times = times,
    unit = "ms"
  )

  # Fetch Results
  setup = function(rush, xss) {
    rush$reset()
    keys = rush$push_tasks(xss)
    rush$connector$command(c("SADD", get_private(rush)$.get_key("running_tasks"), keys))
    walk(keys, function(key) rush$push_results(key, list(list(y = 10))))
  }

  config = start_flush_redis()
  rush_1 = RushWorker$new("benchmark_1", config, host = "local")

  res[["bm_results_1"]] = microbenchmark(
    latest_results_1 = rush_1$fetch_latest_results(),
    fetch_results_1 = rush_1$fetch_results(),
    times = times,
    unit = "ms",
    setup = setup(rush_1, list(xss_1))
  )

  config = start_flush_redis()
  rush_10 = RushWorker$new("benchmark_10", config, host = "local")

  res[["bm_results_10"]] = microbenchmark(
    latest_results_10 = rush_10$fetch_latest_results(),
    fetch_results_10 = rush_10$fetch_results(),
    times = times,
    unit = "ms",
    setup = setup(rush_10, xss_10)
  )

  config = start_flush_redis()
  rush_100 = RushWorker$new("benchmark_100", config, host = "local")

  res[["bm_results_100"]] = microbenchmark(
    latest_results_100 = rush_100$fetch_latest_results(),
    fetch_results_100 = rush_100$fetch_results(),
    times = times,
    unit = "ms",
    setup = setup(rush_100, xss_100)
  )

  config = start_flush_redis()
  rush_1000 = RushWorker$new("benchmark_1000", config, host = "local")

  res[["bm_results_1000"]] = microbenchmark(
    latest_results_1000 = rush_1000$fetch_latest_results(),
    fetch_results_1000 = rush_1000$fetch_results(),
    times = times,
    unit = "ms",
    setup = setup(rush_1000, xss_1000)
  )

  config = start_flush_redis()
  rush_10000 = RushWorker$new("benchmark_10000", config, host = "local")

  res[["bm_results_10000"]] = microbenchmark(
    latest_results_10000 = rush_10000$fetch_latest_results(),
    fetch_results_10000 = rush_10000$fetch_results(),
    times = times,
    unit = "ms",
    setup = setup(rush_10000, xss_10000)
  )

  # Fetch Result with Cache
  setup = function(rush, xss) {
    rush$reset()
    keys = rush$push_tasks(xss)
    rush$connector$command(c("SADD", get_private(rush)$.get_key("running_tasks"), keys))
    walk(keys, function(key) rush$push_results(key, list(list(y = 10))))
    rush$fetch_results()
    keys = rush$push_tasks(xss_100)
    rush$connector$command(c("SADD", get_private(rush)$.get_key("running_tasks"), keys))
    walk(keys, function(key) rush$push_results(key, list(list(y = 10))))
  }

  config = start_flush_redis()
  rush_1 = RushWorker$new("benchmark_1", config, host = "local")

  res[["bm_cache_result_1"]] = microbenchmark(
    fetch_cache_1 = rush_1$fetch_results(),
    times = times,
    unit = "ms",
    setup = setup(rush_1, list(xss_1))
  )

  config = start_flush_redis()
  rush_10 = RushWorker$new("benchmark_10", config, host = "local")

  res[["bm_cache_result_10"]] = microbenchmark(
    fetch_cache_10 = rush_10$fetch_results(),
    times = times,
    unit = "ms",
    setup = setup(rush_10, xss_10)
  )


  config = start_flush_redis()
  rush_100 = RushWorker$new("benchmark_100", config, host = "local")

  res[["bm_cache_result_100"]] = microbenchmark(
    fetch_cache_100 = rush_100$fetch_results(),
    times = times,
    unit = "ms",
    setup = setup(rush_100, xss_100)
  )

  config = start_flush_redis()
  rush_1000 = RushWorker$new("benchmark_1000", config, host = "local")

  res[["bm_cache_result_1000"]] = microbenchmark(
    fetch_cache_1000 = rush_1000$fetch_results(),
    times = times,
    unit = "ms",
    setup = setup(rush_1000, xss_1000)
  )

  config = start_flush_redis()
  rush_10000 = RushWorker$new("benchmark_10000", config, host = "local")

  res[["bm_cache_result_10000"]] = microbenchmark(
    fetch_cache_10000 = rush_10000$fetch_results(),
    times = times,
    unit = "ms",
    setup = setup(rush_10000, xss_10000)
  )


  ## Fetch Finished Tasks
  setup = function(rush, xss) {
    rush$reset()
    keys = rush$push_tasks(xss)
    rush$connector$command(c("SADD", get_private(rush)$.get_key("running_tasks"), keys))
    walk(keys, function(key) rush$push_results(key, list(list(y = 10))))
  }

  config = start_flush_redis()
  rush_1 = RushWorker$new("benchmark_1", config, host = "local")

  res[["bm_finished_1"]] = microbenchmark(
    fetch_finished_tasks_1 = rush_1$fetch_finished_tasks(),
    times = times,
    unit = "ms",
    setup = setup(rush_1, list(xss_1))
  )

  config = start_flush_redis()
  rush_10 = RushWorker$new("benchmark_10", config, host = "local")

  res[["bm_finished_10"]] = microbenchmark(
    fetch_finished_tasks_10 = rush_10$fetch_finished_tasks(),
    times = times,
    unit = "ms",
    setup = setup(rush_10, xss_10)
  )

  config = start_flush_redis()
  rush_100 = RushWorker$new("benchmark_100", config, host = "local")

  res[["bm_finished_100"]] = microbenchmark(
    fetch_finished_tasks_100 = rush_100$fetch_finished_tasks(),
    times = times,
    unit = "ms",
    setup = setup(rush_100, xss_100)
  )

  config = start_flush_redis()
  rush_1000 = RushWorker$new("benchmark_1000", config, host = "local")

  res[["bm_finished_1000"]] = microbenchmark(
    fetch_finished_tasks_1000 = rush_1000$fetch_finished_tasks(),
    times = times,
    unit = "ms",
    setup = setup(rush_1000, xss_1000)
  )

  config = start_flush_redis()
  rush_10000 = RushWorker$new("benchmark_10000", config, host = "local")

  res[["bm_finished_10000"]] = microbenchmark(
    fetch_finished_tasks_10000 = rush_10000$fetch_finished_tasks(),
    times = times,
    unit = "ms",
    setup = setup(rush_10000, xss_10000)
  )

  # Write Hashes
  config = start_flush_redis()
  rush= Rush$new("benchmark", config)
  rush$reset()

  res[["bm_write"]] = microbenchmark(
    write_1 = rush$write_hashes(xs = xss_1),
    write_10 = rush$write_hashes(xs = xss_10),
    write_100 = rush$write_hashes(xs = xss_100),
    write_1000 = rush$write_hashes(xs = xss_1000),
    write_10000 = rush$write_hashes(xs = xss_10000),
    times = times,
    unit = "ms"
  )

  config = start_flush_redis()
  rush= Rush$new("benchmark", config)
  rush$reset()

  res[["bm_write_extra"]] =  microbenchmark(
    write_extra_1 = rush$write_hashes(xs = xss_1, xs_extra = extra_1),
    write_extra_10 = rush$write_hashes(xs = xss_10, xs_extra = extra_10),
    write_extra_100 = rush$write_hashes(xs = xss_100, xs_extra = extra_100),
    write_extra_1000 = rush$write_hashes(xs = xss_1000, xs_extra = extra_1000),
    write_extra_10000 = rush$write_hashes(xs = xss_10000, xs_extra = extra_10000),
    times = times,
    unit = "ms"
  )

  # Read Hashes
  config = start_flush_redis()
  rush= Rush$new("benchmark", config)
  rush$reset()

  keys = rush$write_hashes(xs = xss_10000)

  res[["bm_read"]] = microbenchmark(
    read_1 = rush$read_hashes(keys[[1]], "xs"),
    read_10 = rush$read_hashes(keys[seq(10)], "xs"),
    read_100 = rush$read_hashes(keys[seq(100)], "xs"),
    read_1000 = rush$read_hashes(keys[seq(1000)], "xs"),
    read_10000 = rush$read_hashes(keys, "xs"),
    times = times,
    unit = "ms"
  )

  config = start_flush_redis()
  rush= Rush$new("benchmark", config)
  rush$reset()

  keys = rush$write_hashes(xs = xss_10000, xs_extra = extra_10000)

  res[["bm_read_extra"]] = microbenchmark(
    read_extra_1 = rush$read_hashes(keys[[1]], c("xs", "xs_extra")),
    read_extra_10 = rush$read_hashes(keys[seq(10)], c("xs", "xs_extra")),
    read_extra_100 = rush$read_hashes(keys[seq(100)], c("xs", "xs_extra")),
    read_extra_1000 = rush$read_hashes(keys[seq(1000)], c("xs", "xs_extra")),
    read_extra_10000 = rush$read_hashes(keys, c("xs", "xs_extra")),
    times = times,
    unit = "ms"
  )

  # Worker Info
  config = start_flush_redis()
  rush = Rush$new("benchmark", config)

  future::plan("multisession", workers = 10)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  rush$start_workers(fun, n_workers = 10, host = "local", await_workers = TRUE)

  setup = function(rush) {
    rush$worker_info
  }

  res[["bm_worker_info"]] =  microbenchmark(
    worker_info = rush$worker_info,
    times = 100,
    unit = "ms",
    setup = setup(rush)
  )

  # Detect Lost Workers with ps_exists Function
  config = start_flush_redis()
  rush = Rush$new("benchmark", config)

  future::plan("multisession", workers = 10)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  rush$start_workers(fun, n_workers = 10, host = "local", await_workers = TRUE)
  rush$await_workers(10)
  Sys.sleep(10)

  setup = function(rush) rush$detect_lost_workers()

  res[["bm_lost_local"]] = microbenchmark(
    detect_lost_workers = rush$detect_lost_workers(),
    times = times,
    unit = "ms",
    setup = setup(rush)
  )

  # Detect Lost Workers with Heartbeat

  config = start_flush_redis()
  rush = Rush$new("benchmark", config)

  future::plan("multisession", workers = 10)
  fun = function(x1, x2, ...) list(y = x1 + x2)
  rush$start_workers(fun, n_workers = 10, host = "remote", heartbeat_period = 3, await_workers = TRUE)

  res[["bm_lost_heartbeat"]] = microbenchmark(
    detect_lost_workers = rush$detect_lost_workers(),
    times = times,
    unit = "ms"
  )

  res
}
