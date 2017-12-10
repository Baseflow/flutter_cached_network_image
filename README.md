# Cached network image

A flutter library to show images from the internet and keep them in the cache directory.

## How to add

Add this to your package's pubspec.yaml file:
```
dependencies:
  cached_network_image: "^0.0.2"

```
Add it to your dart file:
```
import 'package:cached_network_image/cached_network_image.dart';
```

## How to use
The CachedNetworkImage can be used in two ways.

You can use the CachedNetworkImage directly: 
````
new CachedNetworkImage(url)
````

or using an imageprovider:
````
new Image(image: new CachedNetworkImageProvider(url))
````

The ImageProvider gives the option to use this with for example a DecorationImage, while the CachedNetworkImage gives you the option to show a placeholder will the image is loading.

## How it works
The cached network images are stored in the temporary directory of the app. This means the OS can delete the images any time.

Information about the files is stored in the shared preferences with the key "lib_cached_image_data". 
This information contains the end date till when the cache is valid and the eTag to use with the http cache-control.