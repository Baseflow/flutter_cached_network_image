// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show GestureBinding;
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart'
    show SemanticsBinding;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'image_data.dart';

class TestRenderingFlutterBinding extends BindingBase
    with GestureBinding, SchedulerBinding, SemanticsBinding {}

void main() {
  group(ImageProvider, () {
    setUpAll(() {
      TestRenderingFlutterBinding(); // initializes the imageCache
      imageCache.clear();
    });

    group(NetworkImage, () {
      MockHttpClient httpClient;

      setUp(() {
        httpClient = MockHttpClient();
        debugNetworkImageHttpClientProvider = () => httpClient;
      });

      tearDown(() {
        debugNetworkImageHttpClientProvider = null;
      });

      test('Expect thrown exception with statusCode', () async {
        final int errorStatusCode = HttpStatus.notFound;
        const String requestUrl = 'foo-url';

        final MockHttpClientRequest request = MockHttpClientRequest();
        final MockHttpClientResponse response = MockHttpClientResponse();
        when(httpClient.getUrl(any))
            .thenAnswer((_) => Future<HttpClientRequest>.value(request));
        when(request.close())
            .thenAnswer((_) => Future<HttpClientResponse>.value(response));
        when(response.statusCode).thenReturn(errorStatusCode);

        final Completer<dynamic> caughtError = Completer<dynamic>();

        final ImageProvider imageProvider = NetworkImage(nonconst(requestUrl));
        final ImageStream result =
            imageProvider.resolve(ImageConfiguration.empty);
        result.addListener(
            ImageStreamListener((ImageInfo info, bool syncCall) {},
                onError: (dynamic error, StackTrace stackTrace) {
          caughtError.complete(error);
        }));

        final dynamic err = await caughtError.future;
        expect(
          err,
          throwsA(
            predicate((e) =>
                e is NetworkImageLoadException &&
                e.statusCode == errorStatusCode &&
                e.uri == Uri.base.resolve(requestUrl)),
          ),
        );
      });

      test('Disallows null urls', () {
        expect(() {
          NetworkImage(nonconst(null));
        }, throwsAssertionError);
      });

      test(
          'Uses the HttpClient provided by debugNetworkImageHttpClientProvider if set',
          () async {
        when(httpClient.getUrl(any)).thenThrow('client1');
        final List<dynamic> capturedErrors = <dynamic>[];

        Future<void> loadNetworkImage() async {
          final DecoderCallback callback = null;
          final NetworkImage networkImage = NetworkImage(nonconst('foo'));
          final ImageStreamCompleter completer =
              networkImage.load(networkImage, callback);
          completer.addListener(ImageStreamListener(
            (ImageInfo image, bool synchronousCall) {},
            onError: (dynamic error, StackTrace stackTrace) {
              capturedErrors.add(error);
            },
          ));
          await Future<void>.value();
        }

        await loadNetworkImage();
        expect(capturedErrors, <dynamic>['client1']);
        final MockHttpClient client2 = MockHttpClient();
        when(client2.getUrl(any)).thenThrow('client2');
        debugNetworkImageHttpClientProvider = () => client2;
        await loadNetworkImage();
        expect(capturedErrors, <dynamic>['client1', 'client2']);
      }, skip: isBrowser);

      test('Propagates http client errors during resolve()', () async {
        when(httpClient.getUrl(any)).thenThrow(Error());
        bool uncaught = false;

        await runZoned(() async {
          const ImageProvider imageProvider = NetworkImage('asdasdasdas');
          final Completer<bool> caughtError = Completer<bool>();
          FlutterError.onError = (FlutterErrorDetails details) {
            throw Error();
          };
          final ImageStream result =
              imageProvider.resolve(ImageConfiguration.empty);
          result.addListener(
              ImageStreamListener((ImageInfo info, bool syncCall) {},
                  onError: (dynamic error, StackTrace stackTrace) {
            caughtError.complete(true);
          }));
          expect(await caughtError.future, true);
        }, zoneSpecification: ZoneSpecification(
          handleUncaughtError: (Zone zone, ZoneDelegate zoneDelegate,
              Zone parent, Object error, StackTrace stackTrace) {
            uncaught = true;
          },
        ));
        expect(uncaught, false);
      });

      test('Notifies listeners of chunk events', () async {
        final List<Uint8List> chunks = <Uint8List>[];
        const int chunkSize = 8;
        for (int offset = 0;
            offset < kTransparentImage.length;
            offset += chunkSize) {
          chunks.add(Uint8List.fromList(
              kTransparentImage.skip(offset).take(chunkSize).toList()));
        }
        final Completer<void> imageAvailable = Completer<void>();
        final MockHttpClientRequest request = MockHttpClientRequest();
        final MockHttpClientResponse response = MockHttpClientResponse();
        when(httpClient.getUrl(any))
            .thenAnswer((_) => Future<HttpClientRequest>.value(request));
        when(request.close())
            .thenAnswer((_) => Future<HttpClientResponse>.value(response));
        when(response.statusCode).thenReturn(HttpStatus.ok);
        when(response.contentLength).thenReturn(kTransparentImage.length);
        when(response.listen(
          any,
          onDone: anyNamed('onDone'),
          onError: anyNamed('onError'),
          cancelOnError: anyNamed('cancelOnError'),
        )).thenAnswer((Invocation invocation) {
          final void Function(List<int>) onData =
              invocation.positionalArguments[0];
          final void Function(Object) onError =
              invocation.namedArguments[#onError];
          final void Function() onDone = invocation.namedArguments[#onDone];
          final bool cancelOnError = invocation.namedArguments[#cancelOnError];

          return Stream<Uint8List>.fromIterable(chunks).listen(
            onData,
            onDone: onDone,
            onError: onError,
            cancelOnError: cancelOnError,
          );
        });

        final ImageProvider imageProvider = NetworkImage(nonconst('foo'));
        final ImageStream result =
            imageProvider.resolve(ImageConfiguration.empty);
        final List<ImageChunkEvent> events = <ImageChunkEvent>[];
        result.addListener(ImageStreamListener(
          (ImageInfo image, bool synchronousCall) {
            imageAvailable.complete();
          },
          onChunk: events.add,
          onError: imageAvailable.completeError,
        ));
        await imageAvailable.future;
        expect(events.length, chunks.length);
        for (int i = 0; i < events.length; i++) {
          expect(events[i].cumulativeBytesLoaded,
              math.min((i + 1) * chunkSize, kTransparentImage.length));
          expect(events[i].expectedTotalBytes, kTransparentImage.length);
        }
      }, skip: isBrowser);
    });
  });
}

class MockHttpClient extends Mock implements HttpClient {}

class MockHttpClientRequest extends Mock implements HttpClientRequest {}

class MockHttpClientResponse extends Mock implements HttpClientResponse {}
