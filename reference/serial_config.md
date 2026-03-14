# Create Serialization Configuration

Returns a serialization configuration for custom serialization and
unserialization of non-system reference objects, using the 'refhook'
system of R native serialization. This allows their use across different
R sessions.

## Usage

``` r
serial_config(class, sfunc, ufunc)
```

## Arguments

- class:

  a character string (or vector) of the class of object custom
  serialization functions are applied to, e.g. `'ArrowTabular'` or
  `c('torch_tensor', 'ArrowTabular')`.

- sfunc:

  a function (or list of functions) that accepts a reference object
  inheriting from `class` and returns a raw vector.

- ufunc:

  a function (or list of functions) that accepts a raw vector and
  returns a reference object.

## Value

A list comprising the configuration. This may be provided to the `hook`
argument of
[`serialize()`](https://shikokuchuo.net/sakura/reference/serialize.md)
and
[`unserialize()`](https://shikokuchuo.net/sakura/reference/serialize.md).

## Examples

``` r
serial_config("test_class", base::serialize, base::unserialize)
#> [[1]]
#> [1] "test_class"
#> 
#> [[2]]
#> [[2]][[1]]
#> function (object, connection, ascii = FALSE, xdr = TRUE, version = NULL, 
#>     refhook = NULL) 
#> {
#>     if (!is.null(connection)) {
#>         if (!inherits(connection, "connection")) 
#>             stop("'connection' must be a connection")
#>         if (missing(ascii)) 
#>             ascii <- summary(connection)$text == "text"
#>     }
#>     if (!ascii && inherits(connection, "sockconn")) 
#>         .Internal(serializeb(object, connection, xdr, version, 
#>             refhook))
#>     else {
#>         type <- if (is.na(ascii)) 
#>             2L
#>         else if (ascii) 
#>             1L
#>         else if (!xdr) 
#>             3L
#>         else 0L
#>         .Internal(serialize(object, connection, type, version, 
#>             refhook))
#>     }
#> }
#> <bytecode: 0x560fa6f99780>
#> <environment: namespace:base>
#> 
#> 
#> [[3]]
#> [[3]][[1]]
#> function (connection, refhook = NULL) 
#> {
#>     if (typeof(connection) != "raw" && !is.character(connection) && 
#>         !inherits(connection, "connection")) 
#>         stop("'connection' must be a connection")
#>     .Internal(unserialize(connection, refhook))
#> }
#> <bytecode: 0x560fa9c5f830>
#> <environment: namespace:base>
#> 
#> 

serial_config(
  c("class_one", "class_two"),
  list(base::serialize, base::serialize),
  list(base::unserialize, base::unserialize)
)
#> [[1]]
#> [1] "class_one" "class_two"
#> 
#> [[2]]
#> [[2]][[1]]
#> function (object, connection, ascii = FALSE, xdr = TRUE, version = NULL, 
#>     refhook = NULL) 
#> {
#>     if (!is.null(connection)) {
#>         if (!inherits(connection, "connection")) 
#>             stop("'connection' must be a connection")
#>         if (missing(ascii)) 
#>             ascii <- summary(connection)$text == "text"
#>     }
#>     if (!ascii && inherits(connection, "sockconn")) 
#>         .Internal(serializeb(object, connection, xdr, version, 
#>             refhook))
#>     else {
#>         type <- if (is.na(ascii)) 
#>             2L
#>         else if (ascii) 
#>             1L
#>         else if (!xdr) 
#>             3L
#>         else 0L
#>         .Internal(serialize(object, connection, type, version, 
#>             refhook))
#>     }
#> }
#> <bytecode: 0x560fa6f99780>
#> <environment: namespace:base>
#> 
#> [[2]][[2]]
#> function (object, connection, ascii = FALSE, xdr = TRUE, version = NULL, 
#>     refhook = NULL) 
#> {
#>     if (!is.null(connection)) {
#>         if (!inherits(connection, "connection")) 
#>             stop("'connection' must be a connection")
#>         if (missing(ascii)) 
#>             ascii <- summary(connection)$text == "text"
#>     }
#>     if (!ascii && inherits(connection, "sockconn")) 
#>         .Internal(serializeb(object, connection, xdr, version, 
#>             refhook))
#>     else {
#>         type <- if (is.na(ascii)) 
#>             2L
#>         else if (ascii) 
#>             1L
#>         else if (!xdr) 
#>             3L
#>         else 0L
#>         .Internal(serialize(object, connection, type, version, 
#>             refhook))
#>     }
#> }
#> <bytecode: 0x560fa6f99780>
#> <environment: namespace:base>
#> 
#> 
#> [[3]]
#> [[3]][[1]]
#> function (connection, refhook = NULL) 
#> {
#>     if (typeof(connection) != "raw" && !is.character(connection) && 
#>         !inherits(connection, "connection")) 
#>         stop("'connection' must be a connection")
#>     .Internal(unserialize(connection, refhook))
#> }
#> <bytecode: 0x560fa9c5f830>
#> <environment: namespace:base>
#> 
#> [[3]][[2]]
#> function (connection, refhook = NULL) 
#> {
#>     if (typeof(connection) != "raw" && !is.character(connection) && 
#>         !inherits(connection, "connection")) 
#>         stop("'connection' must be a connection")
#>     .Internal(unserialize(connection, refhook))
#> }
#> <bytecode: 0x560fa9c5f830>
#> <environment: namespace:base>
#> 
#> 
```
