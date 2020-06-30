import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

class BasicContent extends StatelessWidget {
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
                  'http://via.placeholder.com/350x150',
                ),
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                progressIndicatorBuilder: (context, url, progress) =>
                    CircularProgressIndicator(
                  value: progress.progress,
                ),
                imageUrl:
                    'https://images.unsplash.com/photo-1532264523420-881a47db012d?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9',
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                imageUrl: 'http://via.placeholder.com/200x150',
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                imageUrl: 'http://via.placeholder.com/300x150',
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
              imageUrl: 'http://via.placeholder.com/300x300',
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
                imageUrl: 'http://notAvalid.uri',
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
                imageUrl: 'http://via.placeholder.com/350x200',
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
                fadeOutDuration: const Duration(seconds: 1),
                fadeInDuration: const Duration(seconds: 3),
              ),
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
