#' @title Syntactic Sugar for Rush Manager Construction
#'
#' @description
#' Function to construct a [Rush] manager.
#'
#' @template param_network_id
#' @template param_config
#' @param ... (ignored).
#'
#' @return [Rush] manager.
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
