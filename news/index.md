# Changelog

## sakura (development version)

- Optimised internal mechanism using inline serialization
  ([@traversc](https://github.com/traversc) and
  [@shikokuchuo](https://github.com/shikokuchuo),
  [\#8](https://github.com/shikokuchuo/sakura/issues/8)).
- [`serial_config()`](https://shikokuchuo.net/sakura/reference/serial_config.md)
  improvements:
  - Accepts multiple custom serialization functions for different
    classes of object
    ([\#12](https://github.com/shikokuchuo/sakura/issues/12)).
  - Stores package metadata for each entry, inferring it from serializer
    namespaces when possible.
  - Simplified by removing the `vec` argument, as no longer applicable
    due to inline serialization.
- Added
  [`register_serial()`](https://shikokuchuo.net/sakura/reference/register_serial.md)
  for package-level serializer registration.
- [`serialize()`](https://shikokuchuo.net/sakura/reference/serialize.md),
  [`unserialize()`](https://shikokuchuo.net/sakura/reference/serialize.md),
  [`save_rds()`](https://shikokuchuo.net/sakura/reference/serialize.md)
  and
  [`read_rds()`](https://shikokuchuo.net/sakura/reference/serialize.md)
  now use only globally registered serializers.
- Custom-serialized payloads now record the package to load during
  deserialization, and registered packages may be loaded inline as
  needed.
- Added gzip-streamed
  [`save_rds()`](https://shikokuchuo.net/sakura/reference/serialize.md)
  and
  [`read_rds()`](https://shikokuchuo.net/sakura/reference/serialize.md)
  helpers.
- Each custom-serialized object is no longer limited to a raw vector of
  length `INT_MAX`.
- Implements a C level interface by registering C function callables.
- Package is re-licensed under the MIT licence.

## sakura 0.1.0

CRAN release: 2025-03-03

- Initial CRAN release.

## sakura 0.0.1

- Initial release to Github and R-universe.
