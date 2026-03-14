test_that("sakura without refhooks work", {
  df <- data.frame(a = 1, b = "a")
  expect_type(serialize(df), "raw")
  expect_s3_class(unserialize(serialize(df)), "data.frame")
  expect_identical(unserialize(serialize(df)), df)
  expect_error(unserialize(raw(1)))
})

test_that("serial_config stores package metadata", {
  cfg <- serial_config(
    class = "test_klass",
    package = "base",
    sfunc = function(x) base::serialize(x, NULL),
    ufunc = base::unserialize
  )

  expect_identical(cfg$package, "base")
})

test_that("serial_config infers package metadata when possible", {
  cfg <- serial_config(
    class = "test_klass",
    sfunc = base::serialize,
    ufunc = base::unserialize
  )

  expect_identical(cfg$package, "base")
})

test_that("serial_config requires package metadata when it cannot be inferred", {
  expect_error(
    serial_config(
      class = "test_klass",
      sfunc = function(x) base::serialize(x, NULL),
      ufunc = function(x) base::unserialize(x)
    ),
    "`package` must be supplied"
  )
})

test_that("registered hooks work for serialize and unserialize", {
  sakura_state <- getFromNamespace(".sakura_state", "sakura")
  old_registry <- sakura_state$registry
  on.exit(sakura_state$registry <- old_registry, add = TRUE)
  sakura_state$registry <- list()

  register_serial(
    class = "test_klass",
    package = "base",
    sfunc = function(x) base::serialize(x, NULL),
    ufunc = base::unserialize
  )

  obj <- list(a = new.env(), b = new.env(), vector = runif(10L))
  class(obj$b) <- "test_klass"
  vec <- serialize(obj)

  expect_type(vec, "raw")
  expect_true(all.equal(unserialize(vec), obj))
})

test_that("save_rds and read_rds use gzip streams", {
  sakura_state <- getFromNamespace(".sakura_state", "sakura")
  old_registry <- sakura_state$registry
  on.exit(sakura_state$registry <- old_registry, add = TRUE)
  sakura_state$registry <- list()

  register_serial(
    class = "test_klass",
    package = "base",
    sfunc = function(x) base::serialize(x, NULL),
    ufunc = base::unserialize
  )

  obj <- list(a = new.env(), b = new.env(), vector = runif(10L))
  class(obj$b) <- "test_klass"

  path <- tempfile(fileext = ".RDS")
  on.exit(unlink(path), add = TRUE)

  save_rds(obj, path)

  expect_true(file.exists(path))
  expect_true(all.equal(read_rds(path), obj))
})
