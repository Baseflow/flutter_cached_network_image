
# Cached network image

[![pub package](https://img.shields.io/pub/v/cached_network_image.svg)](https://pub.dartlang.org/packages/cached_network_image)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.me/renefloor)

A flutter library to show images from the internet and keep them in the cache directory.

## How to add

Add this to your package's pubspec.yaml file:
```
dependencies:
  cached_network_image: "^0.2.1"

```
Add it to your dart file:
```
import 'package:cached_network_image/cached_network_image.dart';
```

## How to use
The CachedNetworkImage can be used through the ImageProvider.

````
new Image(image: new CachedNetworkImageProvider(url))
````

The old CachedNetworkImage is removed, for a placeholder image use a [FadeInImage](https://docs.flutter.io/flutter/widgets/FadeInImage-class.html).

## How it works
The cached network images stores and retrieves files using the [flutter_cache_manager](https://pub.dartlang.org/packages/flutter_cache_manager). 