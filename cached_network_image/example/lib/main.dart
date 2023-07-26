import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:baseflow_plugin_template/baseflow_plugin_template.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

void main() {
  CachedNetworkImage.logLevel = CacheManagerLogLevel.debug;

  runApp(BaseflowPluginExample(
    pluginName: 'CachedNetworkImage',
    githubURL: 'https://github.com/Baseflow/flutter_cache_manager',
    pubDevURL: 'https://pub.dev/packages/flutter_cache_manager',
    pages: [
      BasicContent.createPage(),
      ListContent.createPage(),
      GridContent.createPage(),
    ],
  ));
}

/// Demonstrates a [StatelessWidget] containing [CachedNetworkImage]
class BasicContent extends StatelessWidget {
  const BasicContent({Key? key}) : super(key: key);

  static ExamplePage createPage() {
    return ExamplePage(Icons.image, (context) => const BasicContent());
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _blurHashImage(),
            _sizedContainer(
              const Image(
                image: CachedNetworkImageProvider(
                  'https://via.placeholder.com/350x150',
                ),
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                progressIndicatorBuilder: (context, url, progress) => Center(
                  child: CircularProgressIndicator(
                    value: progress.progress,
                  ),
                ),
                imageUrl:
                    'https://images.unsplash.com/photo-1532264523420-881a47db012d?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9',
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                imageUrl: 'https://via.placeholder.com/200x150',
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                imageUrl: 'https://via.placeholder.com/300x150',
                imageBuilder: (context, imageProvider) => Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      colorFilter: const ColorFilter.mode(
                        Colors.red,
                        BlendMode.colorBurn,
                      ),
                    ),
                  ),
                ),
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
            CachedNetworkImage(
              imageUrl: 'https://via.placeholder.com/300x300',
              placeholder: (context, url) => const CircleAvatar(
                backgroundColor: Colors.amber,
                radius: 150,
              ),
              imageBuilder: (context, image) => CircleAvatar(
                backgroundImage: image,
                radius: 150,
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                imageUrl: 'https://notAvalid.uri',
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                imageUrl: 'not a uri at all',
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                maxHeightDiskCache: 10,
                imageUrl: 'https://via.placeholder.com/350x200',
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
                fadeOutDuration: const Duration(seconds: 1),
                fadeInDuration: const Duration(seconds: 3),
              ),
            ),
            _sizedContainer(
                Image(image:CachedMemoryImageProvider(byteImage,base64Decode(byteImage)))
            ),
          ],
        ),
      ),
    );
  }

  Widget _blurHashImage() {
    return SizedBox(
      width: double.infinity,
      child: CachedNetworkImage(
        placeholder: (context, url) => const AspectRatio(
          aspectRatio: 1.6,
          child: BlurHash(hash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj'),
        ),
        imageUrl: 'https://blurha.sh/assets/images/img1.jpg',
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _sizedContainer(Widget child) {
    return SizedBox(
      width: 300.0,
      height: 150.0,
      child: Center(child: child),
    );
  }
}

/// Demonstrates a [ListView] containing [CachedNetworkImage]
class ListContent extends StatelessWidget {
  const ListContent({Key? key}) : super(key: key);

  static ExamplePage createPage() {
    return ExamplePage(Icons.list, (context) => const ListContent());
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (BuildContext context, int index) => Card(
        child: Column(
          children: <Widget>[
            CachedNetworkImage(
              imageUrl: 'https://loremflickr.com/320/240/music?lock=$index',
              placeholder: (BuildContext context, String url) => Container(
                width: 320,
                height: 240,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ),
      itemCount: 250,
    );
  }
}

/// Demonstrates a [GridView] containing [CachedNetworkImage]
class GridContent extends StatelessWidget {
  const GridContent({Key? key}) : super(key: key);

  static ExamplePage createPage() {
    return ExamplePage(Icons.grid_on, (context) => const GridContent());
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 250,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
      itemBuilder: (BuildContext context, int index) => CachedNetworkImage(
        imageUrl: 'https://loremflickr.com/100/100/music?lock=$index',
        placeholder: _loader,
        errorWidget: _error,
      ),
    );
  }

  Widget _loader(BuildContext context, String url) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _error(BuildContext context, String url, dynamic error) {
    return const Center(child: Icon(Icons.error));
  }
}


const byteImage = "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";