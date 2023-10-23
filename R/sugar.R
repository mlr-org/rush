#' @title Synctatic Sugar for Rush Controller Construction
#'
#' @description
#' Function to construct a [Rush] controller.
#'
#' @template param_network_id
#' @template param_config
#' @param ... (ignored).
#'
#' @export
#' @examples
#' rsh(network_id = "benchmark")
rsh = function(network_id = NULL, config = NULL, ...) {
  Rush$new(network_id, config)
}
