skip_on_cran()

test_that("sakura torch refhooks work", {
  skip_if_not_installed("torch")
  sakura_state <- getFromNamespace(".sakura_state", "sakura")
  old_registry <- sakura_state$registry
  on.exit(sakura_state$registry <- old_registry, add = TRUE)
  sakura_state$registry <- list()

  obj <- list(a = torch::torch_rand(1e3L), b = new.env(), vector = runif(1000L))
  register_serial(
    class = "torch_tensor",
    package = "torch",
    sfunc = torch::torch_serialize,
    ufunc = torch::torch_load
  )
  vec <- serialize(obj)
  expect_type(vec, "raw")
  expect_true(all.equal(unserialize(vec), obj))
})

test_that("sakura arrow refhooks work", {
  skip_if_not_installed("arrow")
  sakura_state <- getFromNamespace(".sakura_state", "sakura")
  old_registry <- sakura_state$registry
  on.exit(sakura_state$registry <- old_registry, add = TRUE)
  sakura_state$registry <- list()

  obj <- list(
    a = arrow::as_arrow_table(iris),
    b = arrow::as_arrow_table(mtcars)
  )
  register_serial(
    class = "ArrowTabular",
    package = "arrow",
    sfunc = arrow::write_to_raw,
    ufunc = function(x) arrow::read_ipc_stream(x, as_data_frame = FALSE)
  )
  vec <- serialize(obj)
  expect_type(vec, "raw")
  expect_true(all.equal(unserialize(vec), obj))
})

test_that("sakura multiple refhooks work", {
  skip_if_not_installed("torch")
  skip_if_not_installed("arrow")
  sakura_state <- getFromNamespace(".sakura_state", "sakura")
  old_registry <- sakura_state$registry
  on.exit(sakura_state$registry <- old_registry, add = TRUE)
  sakura_state$registry <- list()

  obj <- list(
    a = arrow::as_arrow_table(iris),
    b = torch::torch_rand(1e3L),
    c = new.env(),
    runif(5L)
  )
  register_serial(
    class = c("torch_tensor", "ArrowTabular"),
    package = c("torch", "arrow"),
    sfunc = list(torch::torch_serialize, arrow::write_to_raw),
    ufunc = list(torch::torch_load, function(x) arrow::read_ipc_stream(x, as_data_frame = FALSE))
  )
  vec <- serialize(obj)
  expect_type(vec, "raw")
  expect_true(all.equal(unserialize(vec), obj))
})
