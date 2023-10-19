#' @title Synctatic Sugar for Rush Controller Construction
#'
#' @description
#' Function to construct a [Rush] controller.
#'
#' @template param_instance_id
#' @template param_config
#'
#' @export
#' @examples
#' rsh(instance_id = "benchmark")
rsh = function(instance_id = NULL, config = NULL, ....) {
  Rush$new(instance_id, config)
}
