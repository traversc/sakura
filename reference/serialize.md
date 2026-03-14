# Serialize

An extension of R native serialization using the 'refhook' system for
custom serialization and unserialization of non-system reference
objects.

## Usage

``` r
serialize(x, hook = NULL)

unserialize(x, hook = NULL)
```

## Arguments

- x:

  an object.

- hook:

  \[default NULL\] optionally, a configuration returned by
  [`serial_config()`](https://shikokuchuo.net/sakura/reference/serial_config.md).

## Value

For serialize: a raw vector. For unserialize: the unserialized object.

## Examples

``` r
vec <- serialize(data.frame())
vec
#>   [1] 42 0a 03 00 00 00 03 05 04 00 00 05 03 00 05 00 00 00 55 54 46 2d 38 13 03
#>  [26] 00 00 00 00 00 00 02 04 00 00 01 00 00 00 09 00 04 00 05 00 00 00 6e 61 6d
#>  [51] 65 73 10 00 00 00 00 00 00 00 02 04 00 00 01 00 00 00 09 00 04 00 09 00 00
#>  [76] 00 72 6f 77 2e 6e 61 6d 65 73 0d 00 00 00 00 00 00 00 02 04 00 00 01 00 00
#> [101] 00 09 00 04 00 05 00 00 00 63 6c 61 73 73 10 00 00 00 01 00 00 00 09 00 04
#> [126] 00 0a 00 00 00 64 61 74 61 2e 66 72 61 6d 65 fe 00 00 00
unserialize(vec)
#> data frame with 0 columns and 0 rows

obj <- list(arrow::as_arrow_table(iris), arrow::as_arrow_table(mtcars))
cfg <- serial_config(
  "ArrowTabular",
  arrow::write_to_raw,
  function(x) arrow::read_ipc_stream(x, as_data_frame = FALSE)
)
raw <- serialize(obj, cfg)
unserialize(raw, cfg)
#> [[1]]
#> Table
#> 150 rows x 5 columns
#> $Sepal.Length <double>
#> $Sepal.Width <double>
#> $Petal.Length <double>
#> $Petal.Width <double>
#> $Species <dictionary<values=string, indices=int8>>
#> 
#> See $metadata for additional Schema metadata
#> 
#> [[2]]
#> Table
#> 32 rows x 11 columns
#> $mpg <double>
#> $cyl <double>
#> $disp <double>
#> $hp <double>
#> $drat <double>
#> $wt <double>
#> $qsec <double>
#> $vs <double>
#> $am <double>
#> $gear <double>
#> $carb <double>
#> 
#> See $metadata for additional Schema metadata
#> 
x <- list(torch::torch_rand(5L), runif(5L))
#> Error: Lantern is not loaded. Please use `install_torch()` to install additional dependencies.
cfg <- serial_config("torch_tensor", torch::torch_serialize, torch::torch_load)
unserialize(serialize(x, cfg), cfg)
#> Error: object 'x' not found
cfg <- serial_config(
  c("torch_tensor", "ArrowTabular"),
  list(torch::torch_serialize, arrow::write_to_raw),
  list(torch::torch_load, function(x) arrow::read_ipc_stream(x, as_data_frame = FALSE))
)
y <- list(torch::torch_rand(5L), runif(5L), arrow::as_arrow_table(iris))
#> Error: Lantern is not loaded. Please use `install_torch()` to install additional dependencies.
unserialize(serialize(y, cfg), cfg)
#> Error: object 'y' not found
```
