dir.create("benchmark/snapshot-2023-10-13")

renv::init("benchmark/snapshot-2023-10-13", bare = TRUE)
renv::load("benchmark/snapshot-2023-10-13")
renv::settings$snapshot.type("all")
renv::install(c("microbenchmark", "mlr-org/rush@8cd1635d911f731ee8052c7e29ba4d92cfe7bd78"))
renv::snapshot()
# renv::restore()

dir.create("benchmark/snapshot-2023-10-22")
renv::init("benchmark/snapshot-2023-10-22", bare = TRUE)
renv::load("benchmark/snapshot-2023-10-22")
renv::settings$snapshot.type("all")
renv::install(c("microbenchmark", "mlr-org/rush@99ff9476d03a3d32a5679a53c8303007de707498"))
renv::snapshot()
# renv::restore()




