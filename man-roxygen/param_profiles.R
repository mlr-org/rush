#' @param profiles (named `integer()`)\cr
#' Number of workers to be started on each `mirai` compute profile, e.g. `c(cpu = 2, gpu = 2)`.
#' The names are the compute profiles created with [mirai::daemons()] and the values are the number of workers
#' started on the daemons of the respective profile.
#' Cannot be combined with `n_workers`.
