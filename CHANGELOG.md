## [0.6.0] - WIP
* Adapted for new cache manager library

## [0.5.1] - 2018-11-19
* Fixed error throwing

## [0.5.0] - 2018-10-13
* Updated cache manager for http 0.12.0

## [0.4.2] - 2018-08-30
* Updated cache manager dependency

## [0.4.1] - 2018-04-27
* Improved error handling when a file could not be loaded.

## [0.4.0] - 2018-04-14
* Added optional headers.
* Changed to Dart 2.0
* Fixed bug when updating widget with new url

## [0.3.0] - 2018-02-09
* Added CachedNetworkImage with placeholder and error widgets.

## [0.2.1] - 2018-01-08
* Moved from OneFrameImageStreamCompleter to MultiFrameImageStreamCompleter.
* Updated CacheManager dependency for critical bug fix.

## [0.2.0] - 2017-12-29

* **Breaking change** Removed CachedNetworkImage. From now on only the ImageProvider is supported. For a placeholder use `FadeInImage`. See also ["Fallback for Network Images"](https://github.com/flutter/flutter/issues/6229).
* Moved CacheManager to a separate library for a more generic purpose.

## [0.1.0] - 2017-12-21

* **Breaking change**. Upgraded to Gradle 4.1 and Android Studio Gradle plugin
  3.0.1. Older Flutter projects need to upgrade their Gradle setup as well in
  order to use this version. Instructions can be found
  [here](https://github.com/flutter/flutter/wiki/Updating-Flutter-projects-to-Gradle-4.1-and-Android-Studio-Gradle-plugin-3.0.1).

## [0.0.2] - 10 December 2017
Added an ImageProvider and improved documentation

## [0.0.1] - 2 December 2017
Initial release, should be polished