library(batchtools)

# reg = makeRegistry(file.dir = "/gscratch/mbecke16/2023-10-13-rush", conf.file = "benchmark/batchtools.conf.R", packages = "renv", seed = 1)
reg = loadRegistry(file.dir = "/gscratch/mbecke16/2023-10-13-rush", writeable = TRUE)

source("benchmark/runner.R")

batchMap(
  fun = runner,
  renv_project = list("benchmark/snapshot-2023-10-13"),
  times = list(100)
)

submitJobs(resources = list(walltime = 60 * 60 * 24))

getStatus()
