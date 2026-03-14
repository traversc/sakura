# Create Serialization Configuration

Returns a serialization configuration for custom serialization and
unserialization of non-system reference objects, using the 'refhook'
system of R native serialization. This allows their use across different
R sessions. Each entry records both the class name and the package name
to load during deserialization. The package may be inferred from `sfunc`
and `ufunc` when those functions come from the same package namespace,
otherwise it must be supplied explicitly.

## Usage

``` r
serial_config(class, package = NULL, sfunc = NULL, ufunc = NULL)
```

## Arguments

- class:

  a character string (or vector) of the class of object custom
  serialization functions are applied to, e.g. `'ArrowTabular'` or
  `c("torch_tensor", "ArrowTabular")`.

- package:

  a character string (or vector) naming the package that should be
  loaded before deserializing objects for each class. May be inferred
  when `sfunc` and `ufunc` both come from the same package namespace.

- sfunc:

  a function (or list of functions) that accepts a reference object
  inheriting from `class` and returns a raw vector.

- ufunc:

  a function (or list of functions) that accepts a raw vector and
  returns a reference object.

## Value

A list comprising the configuration.

## Examples

``` r
serial_config(
  class = "test_class",
  package = "base",
  sfunc = function(x) base::serialize(x, NULL),
  ufunc = base::unserialize
)
#> $class
#> [1] "test_class"
#> 
#> $package
#> [1] "base"
#> 
#> $sfunc
#> $sfunc[[1]]
#> function (x) 
#> base::serialize(x, NULL)
#> <environment: 0x563eed9fffe8>
#> 
#> 
#> $ufunc
#> $ufunc[[1]]
#> function (connection, refhook = NULL) 
#> {
#>     if (typeof(connection) != "raw" && !is.character(connection) && 
#>         !inherits(connection, "connection")) 
#>         stop("'connection' must be a connection")
#>     .Internal(unserialize(connection, refhook))
#> }
#> <bytecode: 0x563ee67c7060>
#> <environment: namespace:base>
#> 
#> 
#> attr(,"class")
#> [1] "sakura_serial_config"

serial_config(
  class = c("class_one", "class_two"),
  package = c("base", "base"),
  sfunc = list(
    function(x) base::serialize(x, NULL),
    function(x) base::serialize(x, NULL)
  ),
  ufunc = list(base::unserialize, base::unserialize)
)
#> $class
#> [1] "class_one" "class_two"
#> 
#> $package
#> [1] "base" "base"
#> 
#> $sfunc
#> $sfunc[[1]]
#> function (x) 
#> base::serialize(x, NULL)
#> <environment: 0x563eed9fffe8>
#> 
#> $sfunc[[2]]
#> function (x) 
#> base::serialize(x, NULL)
#> <environment: 0x563eed9fffe8>
#> 
#> 
#> $ufunc
#> $ufunc[[1]]
#> function (connection, refhook = NULL) 
#> {
#>     if (typeof(connection) != "raw" && !is.character(connection) && 
#>         !inherits(connection, "connection")) 
#>         stop("'connection' must be a connection")
#>     .Internal(unserialize(connection, refhook))
#> }
#> <bytecode: 0x563ee67c7060>
#> <environment: namespace:base>
#> 
#> $ufunc[[2]]
#> function (connection, refhook = NULL) 
#> {
#>     if (typeof(connection) != "raw" && !is.character(connection) && 
#>         !inherits(connection, "connection")) 
#>         stop("'connection' must be a connection")
#>     .Internal(unserialize(connection, refhook))
#> }
#> <bytecode: 0x563ee67c7060>
#> <environment: namespace:base>
#> 
#> 
#> attr(,"class")
#> [1] "sakura_serial_config"
```
