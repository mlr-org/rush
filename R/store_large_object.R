#' @title Store Large Objects
#'
#' @description
#' Store large objects to disk and return a reference to the object.
#'
#' @param obj (`any`)\cr
#' Object to store.
#' @param path (`character(1)`)\cr
#' Path to store the object.
#'
#' @export
store_large_object = function(obj, path) {
  assert_string(path)

  name = deparse(substitute(obj))
  id = uuid::UUIDgenerate()
  path = file.path(path, paste0(id, ".rds"))
  saveRDS(obj, path)
  res = list(name = name, id = id, path = path)
  set_class(res, "rush_large_object")
}
