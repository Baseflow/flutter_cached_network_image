## [5.0.2] - 2026-09-23

* Bump `flutter_lints` to `^6.0.0` and drop the library name, fixing an `unnecessary_library_name` lint

## [5.0.1] - 2026-09-22

* Reformat with the current Dart formatter

## [5.0.0] - 2026-08-25

### Breaking changes

* Requires Flutter `>=3.44.0` and Dart `^3.12.0` (via `material_ui` dependency)
* Replaces `flutter/material.dart` with `material_ui` for Wasm compatibility

### Other changes

* Exclude platform folders from analyzer configuration

## [4.1.1] - 2024-08-13

* Target js_interop for Wasm support

## [4.1.0] - 2024-08-01

* Update dependencies
* Update SDK version to 3.0.0

## [4.0.0] - 2023-12-31

* Removed errorListener from ImageLoader interface

## [3.0.0] - 2023-09-25

* Add error to ErrorListener
* Specify types
* Remove [`load`](https://github.com/flutter/flutter/pull/132679), use `loadImage` instead `loadBuffer`

## [2.0.0] - 2022-08-31

* Added loadBufferAsync for Flutter 3.3

## [1.0.0] - 2021-07-16

* Initial release
