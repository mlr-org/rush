#' @title Synctatic Sugar for Rush Controller Construction
#'
#' @description
#' Function to construct a [Rush] controller.
#'
#' @template param_network_id
#' @template param_config
#' @param ... (ignored).
#'
#' @return [Rush] controller.
#' @export
#' @examples
#' # This example is not executed since Redis must be installed
#' \donttest{
#'    config_local = redux::redis_config()
#'    rush = rsh(network_id = "test_network", config = config_local)
#'    rush
#' }
rsh = function(network_id = NULL, config = NULL, ...) {
  Rush$new(network_id, config)
}
