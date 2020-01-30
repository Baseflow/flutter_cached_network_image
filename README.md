# Cached network image
Widget now uses builders for the placeholder and error widget and uses sqflite for cache management. See the [docs](https://pub.dartlang.org/documentation/cached_network_image/latest/cached_network_image/cached_network_image-library.html) for more information.

[![pub package](https://img.shields.io/pub/v/cached_network_image.svg)](https://pub.dartlang.org/packages/cached_network_image)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.me/renefloor)

A flutter library to show images from the internet and keep them in the cache directory.

## How to use
The CachedNetworkImage can be used directly or through the ImageProvider.

```dart
CachedNetworkImage(
        imageUrl: "http://via.placeholder.com/350x150",
        placeholder: (context, url) => CircularProgressIndicator(),
        errorWidget: (context, url, error) => Icon(Icons.error),
     ),
 ```


````dart
Image(image: CachedNetworkImageProvider(url))
````

When you want to have both the placeholder functionality and want to get the imageprovider to use in another widget you can provide an imageBuilder:
```dart
CachedNetworkImage(
  imageUrl: "http://via.placeholder.com/200x150",
  imageBuilder: (context, imageProvider) => Container(
    decoration: BoxDecoration(
      image: DecorationImage(
          image: imageProvider,
          fit: BoxFit.cover,
          colorFilter:
              ColorFilter.mode(Colors.red, BlendMode.colorBurn)),
    ),
  ),
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
),
```

## How it works
The cached network images stores and retrieves files using the [flutter_cache_manager](https://pub.dartlang.org/packages/flutter_cache_manager). 

## Web support
Web support uses standard widget "Image" and standard browser caching. Therefore, some properties are ignored (only in web version). 

I was unable to isolate BaseCacheManager from conditional import so I had to introduce a breaking change. This parameter is not available anymore and you are not capable of use another cache manager instead of the default one

