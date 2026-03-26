VERSION = commandArgs(TRUE)
if (!nchar(VERSION)) VERSION = "1.2.0"
if (!file.exists(sprintf("../windows/hiredis/lib/libhiredis.a", VERSION))) {
  download.file(sprintf("https://github.com/rwinlib/hiredis/archive/v%s.zip", VERSION),
    "lib.zip", quiet = TRUE)
  dir.create("../windows", showWarnings = FALSE)
  unzip("lib.zip", exdir = "../windows")
  file.rename(sprintf("../windows/hiredis-%s", VERSION), "../windows/hiredis")
  unlink("lib.zip")
}
