# Cached network image

A flutter library to show images from the internet and keep them in the cache directory.

## Getting Started

Add package from github by adding the following to your pubspec.yaml, pub publication is added later.
````
  cached_network_image:
    git:
      url: https://github.com/renefloor/flutter_cached_network_image.git
````
Import the library in your file:
````
import 'package:cached_network_image/cached_network_image.dart';
````
Use the CachedNetworkImage like this: 
````
new CachedNetworkImage(url, fit: BoxFit.cover)
````