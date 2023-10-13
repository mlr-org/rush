library(batchtools)

unlink("benchmark/registry", recursive = TRUE)
reg = makeRegistry(file.dir = "benchmark/registry", conf.file = NA, packages = "renv", seed = 1)

# reg = makeRegistry(file.dir = "/gscratch/mbecke16/2023-10-13-rush", conf.file = "batchtools.conf.R", packages = "renv", seed = 1)
# unlink("/gscratch/mbecke16/2023-10-13-rush", recursive = TRUE)
# reg = loadRegistry(file.dir = "/gscratch/mbecke16/2023-10-13-rush", writeable = TRUE)

source("benchmark/runner.R")

batchMap(
  fun = runner,
  renv_project = list("benchmark/snapshot-2023-10-13"),
  times = list(1)
)

submitJobs()

loadResult(1)

getLog(1)
