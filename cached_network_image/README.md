# Cached network image
[![pub package](https://img.shields.io/pub/v/cached_network_image.svg)](https://pub.dartlang.org/packages/cached_network_image)
[![codecov](https://codecov.io/gh/Baseflow/flutter_cached_network_image/branch/main/graph/badge.svg?token=I5qW0RvoXN)](https://codecov.io/gh/Baseflow/flutter_cached_network_image)
[![Build Status](https://github.com/Baseflow/flutter_cached_network_image/workflows/app_facing_package/badge.svg?branch=develop)](https://github.com/Baseflow/flutter_cached_network_image/actions/workflows/app_facing_package.yaml)

A flutter library to show images from the internet and keep them in the cache directory.



## Sponsors

<table>    
    <tbody>
        <tr>
            <td align="center">
                <a href="https://getstream.io/chat/sdk/flutter/?utm_source=ReneFloor&utm_medium=Github_Repo_Content_Ad&utm_content=Developer&utm_campaign=ReneFloor_July2022_FlutterSDK_klmh22" target="_blank"><img width="250px" src="https://stream-blog.s3.amazonaws.com/blog/wp-content/uploads/fc148f0fc75d02841d017bb36e14e388/Stream-logo-with-background-.png"/></a><br/><span><a href="https://getstream.io/chat/sdk/flutter/?utm_source=ReneFloor&utm_medium=Github_Repo_Content_Ad&utm_content=Developer&utm_campaign=ReneFloor_July2022_FlutterSDK_klmh22" target="_blank">Try the Flutter Chat Tutorial 💬</a></span>
            </td>            
        </tr>
    </tbody>
</table>

## How to use
The CachedNetworkImage can be used directly or through the ImageProvider.
Both the CachedNetworkImage as CachedNetworkImageProvider have minimal support for web. It currently doesn't include caching.

With a placeholder:
```dart
CachedNetworkImage(
        imageUrl: "http://via.placeholder.com/350x150",
        placeholder: (context, url) => CircularProgressIndicator(),
        errorWidget: (context, url, error) => Icon(Icons.error),
     ),
 ```
 
 Or with a progress indicator:
 ```dart
CachedNetworkImage(
        imageUrl: "http://via.placeholder.com/350x150",
        progressIndicatorBuilder: (context, url, downloadProgress) => 
                CircularProgressIndicator(value: downloadProgress.progress),
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

### Animated image timing

`minFrameDuration` is an opt-in setting on `CachedNetworkImage` and
`CachedNetworkImageProvider` for animated GIF, WebP and APNG images. The default
`null` preserves the durations reported by the image codec.

Pass `const Duration(milliseconds: 100)` to match browser timing for short frames:

```dart
CachedNetworkImage(
  imageUrl: animationUrl,
  minFrameDuration: const Duration(milliseconds: 100),
)
```

Or use the provider directly:

```dart
Image(
  image: CachedNetworkImageProvider(
    animationUrl,
    minFrameDuration: const Duration(milliseconds: 100),
  ),
)
```

Only frames whose codec duration is **10ms or less** are adjusted, using the
greater of the codec duration and the supplied minimum. Frames longer than 10ms
keep their original duration. For example, a 20ms setting holds 0ms and 10ms
frames for 20ms, while an 11ms frame remains 11ms. Smaller settings (including
zero or negative durations) never shorten a frame.

To evict an animation, pass the same `minFrameDuration` to
`CachedNetworkImage.evictFromCache` (along with any custom `cacheKey` and `scale`).
This removes that memory-cache variant, not every timing variant of the URL.

## How it works
The cached network images stores and retrieves files using the [flutter_cache_manager](https://pub.dartlang.org/packages/flutter_cache_manager). 

## FAQ
### My app crashes when the image loading failed. (I know, this is not really a question.)
Does it really crash though? The debugger might pause, as the Dart VM doesn't recognize it as a caught exception; the console might print errors; even your crash reporting tool might report it (I know, that really sucks). However, does it really crash? Probably everything is just running fine. If you really get an app crashes you are fine to report an issue, but do that with a small example so we can reproduce that crash.

See for example [this](https://github.com/Baseflow/flutter_cached_network_image/issues/336#issuecomment-760769361) or [this](https://github.com/Baseflow/flutter_cached_network_image/issues/536#issuecomment-760857495) answer on previous posted issues.
