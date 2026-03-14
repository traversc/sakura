# Register Serialization Configuration

Registers a serialization configuration for custom serialization and
unserialization of reference objects. Once registered, the configuration
is applied automatically by
[`serialize()`](https://shikokuchuo.net/sakura/reference/serialize.md),
[`unserialize()`](https://shikokuchuo.net/sakura/reference/serialize.md),
[`save_rds()`](https://shikokuchuo.net/sakura/reference/serialize.md)
and
[`read_rds()`](https://shikokuchuo.net/sakura/reference/serialize.md).
During deserialization, sakura loads the recorded package name inline
before dispatching to the registered unserializer, allowing packages to
self-register from `.onLoad()` or a package load hook.

## Usage

``` r
register_serial(class, package = NULL, sfunc = NULL, ufunc = NULL)
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

Invisible `NULL`.
