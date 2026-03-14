.sakura_state <- new.env(parent = emptyenv())
.sakura_serial_fields <- c("class", "package", "sfunc", "ufunc")
.sakura_state$registry <- list()

.sakura_registry_key <- function(package, class) {
  paste(package, class, sep = "::")
}

.sakura_function_list <- function(x, arg) {
  if (is.function(x)) {
    return(list(x))
  }

  is.list(x) || stop(sprintf("`%s` must be a function or list of functions", arg), call. = FALSE)
  all(vapply(x, is.function, logical(1))) ||
    stop(sprintf("`%s` must be a function or list of functions", arg), call. = FALSE)

  x
}

.sakura_function_package <- function(fun) {
  env <- environment(fun)

  if (is.null(env)) {
    return(NA_character_)
  }

  if (isNamespace(env)) {
    return(getNamespaceName(env))
  }

  env_name <- environmentName(env)
  if (startsWith(env_name, "namespace:")) {
    return(sub("^namespace:", "", env_name))
  }
  if (startsWith(env_name, "package:")) {
    return(sub("^package:", "", env_name))
  }

  NA_character_
}

.sakura_registered_config <- function() {
  registry <- unname(.sakura_state$registry)

  if (!length(registry)) {
    return(NULL)
  }

  structure(
    list(
      class = vapply(registry, `[[`, character(1), "class"),
      package = vapply(registry, `[[`, character(1), "package"),
      sfunc = lapply(registry, `[[`, "sfunc"),
      ufunc = lapply(registry, `[[`, "ufunc")
    ),
    class = "sakura_serial_config"
  )
}

.sakura_dispatch_unserialize <- function(x, class, package) {
  if (!package %in% loadedNamespaces()) {
    tryCatch(
      loadNamespace(package),
      error = function(cnd) {
        stop(
          sprintf(
            "failed to load package '%s' while deserializing objects of class '%s': %s",
            package,
            class,
            conditionMessage(cnd)
          ),
          call. = FALSE
        )
      }
    )
  }

  entry <- .sakura_state$registry[[.sakura_registry_key(package, class)]]

  is.null(entry) && stop(
    sprintf(
      "no serialization configuration is registered for class '%s' in package '%s'",
      class,
      package
    ),
    call. = FALSE
  )

  entry[["ufunc"]](x)
}

#' Create Serialization Configuration
#'
#' Returns a serialization configuration for custom serialization and
#' unserialization of non-system reference objects, using the 'refhook' system
#' of R native serialization. This allows their use across different R sessions.
#' Each entry records both the class name and the package name to load during
#' deserialization. The package may be inferred from `sfunc` and `ufunc` when
#' those functions come from the same package namespace, otherwise it must be
#' supplied explicitly.
#'
#' @param class a character string (or vector) of the class of object custom
#'   serialization functions are applied to, e.g. `'ArrowTabular'` or
#'   `c("torch_tensor", "ArrowTabular")`.
#' @param package a character string (or vector) naming the package that should
#'   be loaded before deserializing objects for each class. May be inferred when
#'   `sfunc` and `ufunc` both come from the same package namespace.
#' @param sfunc a function (or list of functions) that accepts a reference
#'   object inheriting from `class` and returns a raw vector.
#' @param ufunc a function (or list of functions) that accepts a raw vector and
#'   returns a reference object.
#'
#' @return A list comprising the configuration.
#'
#' @examples
#' serial_config(
#'   class = "test_class",
#'   package = "base",
#'   sfunc = function(x) base::serialize(x, NULL),
#'   ufunc = base::unserialize
#' )
#'
#' serial_config(
#'   class = c("class_one", "class_two"),
#'   package = c("base", "base"),
#'   sfunc = list(
#'     function(x) base::serialize(x, NULL),
#'     function(x) base::serialize(x, NULL)
#'   ),
#'   ufunc = list(base::unserialize, base::unserialize)
#' )
#'
#' @export
#'
serial_config <- function(class, package = NULL, sfunc = NULL, ufunc = NULL) {
  if (missing(ufunc) && !missing(sfunc) && !is.character(package)) {
    ufunc <- sfunc
    sfunc <- package
    package <- NULL
  }

  is.character(class) && length(class) ||
    stop("`class` must be a non-empty character vector", call. = FALSE)

  sfunc <- .sakura_function_list(sfunc, "sfunc")
  ufunc <- .sakura_function_list(ufunc, "ufunc")

  length(class) == length(sfunc) && length(sfunc) == length(ufunc) ||
    stop("`class`, `sfunc` and `ufunc` must be the same length", call. = FALSE)

  if (is.null(package)) {
    package <- rep.int(NA_character_, length(class))
  } else {
    is.character(package) ||
      stop("`package` must be a character vector", call. = FALSE)
    if (length(package) == 1L && length(class) > 1L) {
      package <- rep.int(package, length(class))
    }
    length(package) == length(class) ||
      stop("`class`, `package`, `sfunc` and `ufunc` must be the same length", call. = FALSE)
  }

  for (i in seq_along(class)) {
    inferred <- c(.sakura_function_package(sfunc[[i]]), .sakura_function_package(ufunc[[i]]))
    inferred <- unique(inferred[!is.na(inferred) & nzchar(inferred)])

    if (length(inferred) > 1L) {
      stop(
        sprintf(
          "inferred package names for entry %d do not match between `sfunc` and `ufunc`",
          i
        ),
        call. = FALSE
      )
    }

    if (is.na(package[[i]]) || !nzchar(package[[i]])) {
      length(inferred) ||
        stop(
          sprintf(
            "`package` must be supplied for entry %d when it cannot be inferred from `sfunc`/`ufunc`",
            i
          ),
          call. = FALSE
        )
      package[[i]] <- inferred[[1L]]
    } else if (length(inferred) == 1L && !identical(package[[i]], inferred[[1L]])) {
      stop(
        sprintf(
          "`package` for entry %d must match the namespace of `sfunc`/`ufunc`",
          i
        ),
        call. = FALSE
      )
    }
  }

  structure(
    list(class = class, package = package, sfunc = sfunc, ufunc = ufunc),
    class = "sakura_serial_config"
  )
}

#' Register Serialization Configuration
#'
#' Registers a serialization configuration for custom serialization and
#' unserialization of reference objects. Once registered, the configuration is
#' applied automatically by [serialize()], [unserialize()], [save_rds()] and
#' [read_rds()]. During deserialization, sakura loads the recorded package name
#' inline before dispatching to the registered unserializer, allowing packages
#' to self-register from `.onLoad()` or a package load hook.
#'
#' @inheritParams serial_config
#'
#' @return Invisible `NULL`.
#'
#' @export
#'
register_serial <- function(class, package = NULL, sfunc = NULL, ufunc = NULL) {
  cfg <- serial_config(class = class, package = package, sfunc = sfunc, ufunc = ufunc)
  registry <- .sakura_state$registry

  for (i in seq_along(cfg[["class"]])) {
    registry[[.sakura_registry_key(cfg[["package"]][[i]], cfg[["class"]][[i]])]] <- list(
      class = cfg[["class"]][[i]],
      package = cfg[["package"]][[i]],
      sfunc = cfg[["sfunc"]][[i]],
      ufunc = cfg[["ufunc"]][[i]]
    )
  }

  .sakura_state$registry <- registry
  invisible()
}
