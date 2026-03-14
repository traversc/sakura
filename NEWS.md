# sakura (development version)

* Optimised internal mechanism using inline serialization (@traversc and @shikokuchuo, #8).
* `serial_config()` improvements:
  + Accepts multiple custom serialization functions for different classes of object (#12).
  + Stores package metadata for each entry, inferring it from serializer namespaces when possible.
  + Simplified by removing the `vec` argument, as no longer applicable due to inline serialization.
* Added `register_serial()` for package-level serializer registration.
* `serialize()`, `unserialize()`, `save_rds()` and `read_rds()` now use only globally registered serializers.
* Custom-serialized payloads now record the package to load during deserialization, and registered packages may be loaded inline as needed.
* Added gzip-streamed `save_rds()` and `read_rds()` helpers.
* Each custom-serialized object is no longer limited to a raw vector of length `INT_MAX`.
* Implements a C level interface by registering C function callables.
* Package is re-licensed under the MIT licence.

# sakura 0.1.0

* Initial CRAN release.

# sakura 0.0.1

* Initial release to Github and R-universe.
