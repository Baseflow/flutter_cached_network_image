
# Cached network image

[![pub package](https://img.shields.io/pub/v/cached_network_image.svg)](https://pub.dartlang.org/packages/cached_network_image)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.me/renefloor)

A flutter library to show images from the internet and keep them in the cache directory.

## How to add

Add this to your package's pubspec.yaml file:
```
dependencies:
  cached_network_image: "^0.3.0"

```
Add it to your dart file:
```
import 'package:cached_network_image/cached_network_image.dart';
```

## How to use
The CachedNetworkImage can be used directly or through the ImageProvider.

```
new CachedNetworkImage(
       imageUrl: "http://via.placeholder.com/350x150",
       placeholder: new CircularProgressIndicator(),
       errorWidget: new Icon(Icons.error),
     ),
 ```


````
new Image(image: new CachedNetworkImageProvider(url))
````

## How it works
The cached network images stores and retrieves files using the [flutter_cache_manager](https://pub.dartlang.org/packages/flutter_cache_manager). 