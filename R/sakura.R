# sakura -----------------------------------------------------------------------

#' sakura: Extension to R Serialization
#'
#' Extends the functionality of R serialization by augmenting the built-in
#' reference hook system. This enhanced implementation allows an integrated
#' single-pass operation that combines R serialization with third-party
#' serialization methods. Facilitates the serialization of even complex R
#' objects, which contain non-system reference objects, such as those accessed
#' via external pointers, to enable their use in parallel and distributed
#' computing.
#'
#' @useDynLib sakura, .registration = TRUE
#'
"_PACKAGE"

#' Serialize
#'
#' An extension of R native serialization using the 'refhook' system for custom
#' serialization and unserialization of non-system reference objects.
#' Registered configurations from [register_serial()] are applied automatically,
#' and each custom-serialized object records both its class and package name so
#' the package can be loaded during deserialization before dispatching to the
#' matching unserializer.
#'
#' @param x an object.
#'
#' @return For serialize: a raw vector. For unserialize: the unserialized object.
#'
#' @examples
#' vec <- serialize(data.frame())
#' vec
#' unserialize(vec)
#'
#' @examplesIf requireNamespace("arrow", quietly = TRUE)
#' obj <- list(arrow::as_arrow_table(iris), arrow::as_arrow_table(mtcars))
#' register_serial(
#'   class = "ArrowTabular",
#'   package = "arrow",
#'   sfunc = arrow::write_to_raw,
#'   ufunc = function(x) arrow::read_ipc_stream(x, as_data_frame = FALSE)
#' )
#' raw <- serialize(obj)
#' unserialize(raw)
#'
#' @examplesIf requireNamespace("torch", quietly = TRUE)
#' x <- list(torch::torch_rand(5L), runif(5L))
#' register_serial(
#'   class = "torch_tensor",
#'   package = "torch",
#'   sfunc = torch::torch_serialize,
#'   ufunc = torch::torch_load
#' )
#' unserialize(serialize(x))
#'
#' @export
#'
serialize <- function(x) {
  .Call(sakura_r_serialize, x, .sakura_registered_config())
}

#' @examplesIf requireNamespace("arrow", quietly = TRUE) && requireNamespace("torch", quietly = TRUE)
#' register_serial(
#'   class = c("torch_tensor", "ArrowTabular"),
#'   package = c("torch", "arrow"),
#'   sfunc = list(torch::torch_serialize, arrow::write_to_raw),
#'   ufunc = list(torch::torch_load, function(x) arrow::read_ipc_stream(x, as_data_frame = FALSE))
#' )
#' y <- list(torch::torch_rand(5L), runif(5L), arrow::as_arrow_table(iris))
#' unserialize(serialize(y))
#'
#' @rdname serialize
#' @export
#'
unserialize <- function(x) {
  .Call(sakura_r_unserialize, x)
}

#' @param file a file path.
#'
#' @return `save_rds()` returns invisible `NULL`. `read_rds()` returns the
#'   unserialized object.
#'
#' @examplesIf requireNamespace("torch", quietly = TRUE)
#' path <- tempfile(fileext = ".RDS")
#' x <- list(torch::torch_rand(5L), runif(5L))
#' register_serial(
#'   class = "torch_tensor",
#'   package = "torch",
#'   sfunc = torch::torch_serialize,
#'   ufunc = torch::torch_load
#' )
#' save_rds(x, path)
#' read_rds(path)
#'
#' @rdname serialize
#' @export
#'
save_rds <- function(x, file) {
  invisible(.Call(sakura_r_save_rds, x, file, .sakura_registered_config()))
}

#' @rdname serialize
#' @export
#'
read_rds <- function(file) {
  .Call(sakura_r_read_rds, file)
}
