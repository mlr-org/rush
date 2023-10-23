library(batchtools)

# reg = makeRegistry(file.dir = "/gscratch/mbecke16/benchmark-rush", conf.file = "benchmark/batchtools.conf.R", packages = "renv", seed = 1)
# reg = loadRegistry(file.dir = "/gscratch/mbecke16/benchmark-rush", writeable = TRUE)
# unlink("/gscratch/mbecke16/benchmark-rush", recursive = TRUE)

source("benchmark/runner.R")

batchMap(
  fun = runner,
  renv_project = list("benchmark/snapshot-2023-10-22"),
  times = list(100)
)

submitJobs(resources = list(walltime = 60 * 60 * 24))

getStatus()
