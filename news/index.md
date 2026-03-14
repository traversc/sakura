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
  - Simplified by removing the `vec` argument, as no longer applicable
    due to inline serialization.
- Each custom-serialized object is no longer limited to a raw vector of
  length `INT_MAX`.
- Implements a C level interface by registering C function callables.
- Package is re-licensed under the MIT licence.

## sakura 0.1.0

CRAN release: 2025-03-03

- Initial CRAN release.

## sakura 0.0.1

- Initial release to Github and R-universe.
