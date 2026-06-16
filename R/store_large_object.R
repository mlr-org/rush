#' @title Store Large Objects
#'
#' @description
#' Store large objects to disk and return a reference to the object.
#' The written `.rds` files are not cleaned up automatically.
#' The caller is responsible for removing them, e.g. by storing them below [tempdir()] or by calling [unlink()] on the
#' returned `path`.
#'
#' @param obj (`any`)\cr
#' Object to store.
#' @param path (`character(1)`)\cr
#' Path to an existing directory to store the object in.
#'
#' @return `list()` of class `"rush_large_object"` with the name and path of the stored object.
#' @export
#' @examples
#' obj = list(a = 1, b = 2)
#' rush_large_object = store_large_object(obj, tempdir())
store_large_object = function(obj, path) {
  assert_directory_exists(path)

  name = deparse(substitute(obj))
  id = uuid::UUIDgenerate()
  path = file.path(path, paste0(id, ".rds"))
  saveRDS(obj, path)
  res = list(name = name, id = id, path = path)
  set_class(res, "rush_large_object")
}
