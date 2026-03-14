# sakura

``` R
  ________  
 /\ sa    \
/  \  ku   \
\  /    ra /
 \/_______/
```

### Extension to R Serialization

Extends the functionality of R serialization by augmenting the built-in
reference hook system. This enhanced implementation allows an integrated
single-pass operation that combines R serialization with third-party
serialization methods.

Facilitates the serialization of even complex R objects, which contain
non-system reference objects, such as those accessed via external
pointers, to enable their use in parallel and distributed computing.

This package was a request from a meeting of the [R
Consortium](https://r-consortium.org/) [Marshalling and Serialization
Working Group](https://github.com/RConsortium/marshalling-wg/) held at
useR!2024 in Salzburg, Austria. It is designed to eventually provide a
common framework for marshalling in R.

It extracts the functionality embedded within the
[mirai](https://github.com/r-lib/mirai) async framework for use in other
contexts.

### Installation

Install the current release from CRAN:

``` r
install.packages("sakura")
```

Or the development version using:

``` r
pak::pak("shikokuchuo/sakura")
```

### Overview

Some R objects by their nature cannot be serialized, such as those
accessed via an external pointer.

Using the [`arrow`](https://arrow.apache.org/docs/r/) package as an
example:

``` r
library(arrow, warn.conflicts = FALSE)
obj <- list(as_arrow_table(iris), as_arrow_table(mtcars))

unserialize(serialize(obj, NULL))
#> [[1]]
#> Table
#> Error: Invalid <Table>, external pointer to null
```

In such cases,
[`sakura::register_serial()`](https://shikokuchuo.net/sakura/reference/register_serial.md)
can be used to register custom serialization functions that hook into
R’s native serialization mechanism for reference objects (‘refhooks’).

``` r
sakura::register_serial(
  class = "ArrowTabular",
  package = "arrow",
  sfunc = arrow::write_to_raw,
  ufunc = function(x) arrow::read_ipc_stream(x, as_data_frame = FALSE)
)
```

Register the serializer once and
[`sakura::serialize()`](https://shikokuchuo.net/sakura/reference/serialize.md)
/
[`sakura::unserialize()`](https://shikokuchuo.net/sakura/reference/serialize.md)
will pick it up automatically. sakura records both the class and package
name in the serialized payload so the package can be loaded inline
during deserialization.

``` r
sakura::unserialize(sakura::serialize(obj))
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
```

This time, the arrow tables are handled seamlessly.

Using `torch` as another example:

``` r
library(torch)
x <- list(torch_rand(5L), runif(5L))

unserialize(serialize(x, NULL))
#> [[1]]
#> torch_tensor
#> Error in (function (self) : external pointer is not valid
```

Base R serialization above fails, but `sakura` serialization succeeds:

``` r
sakura::register_serial(
  class = "torch_tensor",
  package = "torch",
  sfunc = torch::torch_serialize,
  ufunc = torch::torch_load
)

sakura::unserialize(sakura::serialize(x))
#> [[1]]
#> torch_tensor
#>  0.3755
#>  0.0540
#>  0.3365
#>  0.3944
#>  0.5949
#> [ CPUFloatType{5} ]
#> 
#> [[2]]
#> [1] 0.4271107 0.5690996 0.8724742 0.8202838 0.3796990
```

Packages can also self-register on load so that explicit hooks are not
required at the call site:

``` r
sakura::register_serial(
  class = "torch_tensor",
  package = "torch",
  sfunc = torch::torch_serialize,
  ufunc = torch::torch_load
)
```

If another package wants to register before `sakura` is loaded, it can
call `setHook(packageEvent("sakura", "onLoad"), ...)` from its own
`.onLoad()` and register at that point.

For file storage,
[`sakura::save_rds()`](https://shikokuchuo.net/sakura/reference/serialize.md)
and
[`sakura::read_rds()`](https://shikokuchuo.net/sakura/reference/serialize.md)
stream the serialized bytes through gzip-compressed files:

``` r
path <- tempfile(fileext = ".RDS")
sakura::save_rds(x, path)
sakura::read_rds(path)
```

### C Interface

A low-level interface is provided for use by other packages. The
following C callables are registered:

``` c
sakura_serialize_init;
sakura_unserialize_init;

sakura_serialize;
sakura_unserialize;
```

Their function signatures may be inspected in `src/sakura.h`.

### Acknowledgements

We would like to thank in particular:

- [R Core](https://www.r-project.org/contributors.html) for providing
  the interface to the R serialization mechanism.
- [Luke Tierney](https://github.com/ltierney/) and [Mike
  Cheng](https://github.com/coolbutuseless) for their meticulous efforts
  in documenting the serialization interface.
- [Daniel Falbel](https://github.com/dfalbel) for discussion around an
  efficient solution to serialization and transmission of torch tensors.

–

Please note that this project is released with a [Contributor Code of
Conduct](https://shikokuchuo.net/sakura/CODE_OF_CONDUCT.html). By
participating in this project you agree to abide by its terms.
