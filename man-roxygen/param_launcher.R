#' @param launcher (`function()` | `list()`)\cr
#' Relaunches a daemon when the daemon of a lost worker has died, e.g. because its Slurm job was canceled.
#' Either a launcher configuration of \CRANpkg{mirai} created with [mirai::cluster_config()],
#' [mirai::ssh_config()], or [mirai::remote_config()], which is passed to [mirai::launch_remote()],
#' or a function with the arguments `n` and `profile` that launches `n` daemons on the compute profile `profile`.
#' If `NULL`, the new worker waits until a daemon is available, e.g. because the scheduler requeues the job.
#' Only used if `restart = TRUE`.
