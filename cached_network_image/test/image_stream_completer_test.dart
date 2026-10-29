// Copyright 2020 Rene Floor. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_test/flutter_test.dart';

class FakeFrameInfo implements FrameInfo {
  const FakeFrameInfo(this._duration, this._image);

  final Duration _duration;
  final Image _image;

  @override
  Duration get duration => _duration;

  @override
  Image get image => _image;

  int get imageHandleCount => image.debugGetOpenHandleStackTraces()!.length;

  FakeFrameInfo clone() {
    return FakeFrameInfo(_duration, _image.clone());
  }
}

class MockCodec implements Codec {
  @override
  int frameCount = 1;

  @override
  int repetitionCount = 1;

  int numFramesAsked = 0;
  int disposeCount = 0;

  Completer<FrameInfo> _nextFrameCompleter = Completer<FrameInfo>();

  @override
  Future<FrameInfo> getNextFrame() {
    numFramesAsked += 1;
    return _nextFrameCompleter.future;
  }

  void completeNextFrame(FrameInfo frameInfo) {
    _nextFrameCompleter.complete(frameInfo);
    _nextFrameCompleter = Completer<FrameInfo>();
  }

  void failNextFrame(String err) {
    _nextFrameCompleter.completeError(err);
    _nextFrameCompleter = Completer<FrameInfo>();
  }

  @override
  void dispose() {
    disposeCount++;
  }
}

class AnimatedCompleterFixture {
  AnimatedCompleterFixture({void Function(ImageInfo)? onImage}) {
    completer = MultiImageStreamCompleter(codec: codecStream.stream, scale: 1);
    listener = ImageStreamListener((image, _) {
      emittedImages++;
      try {
        onImage?.call(image);
      } finally {
        image.dispose();
      }
    });
    completer.addListener(listener);
    codecStream.add(codec);
    addTearDown(codecStream.close);
  }

  final codecStream = StreamController<Codec>();
  final codec = MockCodec()
    ..frameCount = 2
    ..repetitionCount = -1;
  late final MultiImageStreamCompleter completer;
  late final ImageStreamListener listener;
  int emittedImages = 0;
}

class FakeEventReportingImageStreamCompleter extends ImageStreamCompleter {
  FakeEventReportingImageStreamCompleter({
    Stream<ImageChunkEvent>? chunkEvents,
  }) {
    if (chunkEvents != null) {
      chunkEvents.listen((ImageChunkEvent event) {
        reportImageChunkEvent(event);
      });
    }
  }
}

void main() {
  late Image image20x10;
  late Image image200x100;
  late Image image300x100;
  setUp(() async {
    image20x10 = await createTestImage(width: 20, height: 10);
    image200x100 = await createTestImage(width: 200, height: 100);
    image300x100 = await createTestImage(width: 300, height: 100);
  });

  testWidgets('Codec future fails', (WidgetTester tester) async {
    final codecStream = StreamController<Codec>();
    MultiImageStreamCompleter(codec: codecStream.stream, scale: 1.0);
    codecStream.addError('failure message');
    await tester.idle();
    expect(tester.takeException(), 'failure message');
  });

  test('Completer unsubscribes to chunk events when disposed', () async {
    final codecStream = StreamController<Codec>();
    final chunkStream = StreamController<ImageChunkEvent>();

    final MultiImageStreamCompleter completer = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
      chunkEvents: chunkStream.stream,
    );

    expect(chunkStream.hasListener, true);

    chunkStream.add(
      const ImageChunkEvent(cumulativeBytesLoaded: 1, expectedTotalBytes: 3),
    );

    final ImageStreamListener listener = ImageStreamListener(
      (ImageInfo info, bool syncCall) {},
    );
    // Cause the completer to dispose.
    completer.addListener(listener);
    completer.removeListener(listener);

    expect(chunkStream.hasListener, false);

    // The above expectation should cover this, but the point of this test is to
    // make sure the completer does not assert that it's disposed and still
    // receiving chunk events. Streams from the network can keep sending data
    // even after evicting an image from the cache, for example.
    chunkStream.add(
      const ImageChunkEvent(cumulativeBytesLoaded: 2, expectedTotalBytes: 3),
    );
  });

  testWidgets('disposes a decoded frame waiting for the first app frame', (
    WidgetTester tester,
  ) async {
    final fixture = AnimatedCompleterFixture();
    final codec = fixture.codec;
    final completer = fixture.completer;
    final listener = fixture.listener;
    await tester.idle();

    final frame = FakeFrameInfo(
      const Duration(milliseconds: 200),
      image20x10.clone(),
    );
    codec.completeNextFrame(frame);
    await tester.idle();
    expect(frame.image.debugDisposed, false);
    expect(fixture.emittedImages, 0);

    // The frame has decoded but has not yet been emitted by an app frame.
    completer.removeListener(listener);
    expect(frame.image.debugDisposed, true);
    await tester.pump();
    expect(fixture.emittedImages, 0);
  });

  testWidgets(
    'disposes a waiting animation frame when last listener is removed',
    (WidgetTester tester) async {
      final fixture = AnimatedCompleterFixture();
      final codec = fixture.codec;
      final completer = fixture.completer;
      final listener = fixture.listener;
      await tester.idle();

      codec.completeNextFrame(
        FakeFrameInfo(const Duration(milliseconds: 200), image20x10.clone()),
      );
      await tester.idle();
      await tester.pump();
      expect(fixture.emittedImages, 1);
      expect(codec.numFramesAsked, 2);

      final waitingFrame = FakeFrameInfo(
        const Duration(milliseconds: 200),
        image200x100.clone(),
      );
      codec.completeNextFrame(waitingFrame);
      await tester.idle();
      // Schedule a delay while the first frame is still being displayed.
      await tester.pump(const Duration(milliseconds: 50));
      expect(waitingFrame.image.debugDisposed, false);
      expect(fixture.emittedImages, 1);

      completer.removeListener(listener);
      expect(waitingFrame.image.debugDisposed, true);
      await tester.pump(const Duration(milliseconds: 200));
      expect(fixture.emittedImages, 1);
      expect(codec.numFramesAsked, 2);
    },
  );

  testWidgets(
    'retains waiting frame until final keep-alive handle is released',
    (WidgetTester tester) async {
      final fixture = AnimatedCompleterFixture();
      final codec = fixture.codec;
      final completer = fixture.completer;
      final listener = fixture.listener;
      final firstHandle = completer.keepAlive();
      final lastHandle = completer.keepAlive();
      await tester.idle();

      final frame = FakeFrameInfo(
        const Duration(milliseconds: 200),
        image20x10.clone(),
      );
      codec.completeNextFrame(frame);
      await tester.idle();

      completer.removeListener(listener);
      expect(frame.image.debugDisposed, false);
      firstHandle.dispose();
      expect(frame.image.debugDisposed, false);
      lastHandle.dispose();
      expect(frame.image.debugDisposed, true);
      await tester.pump();
      expect(codec.numFramesAsked, 1);
    },
  );

  for (final keptAlive in [false, true]) {
    testWidgets(
      keptAlive
          ? 'last keep-alive handle can be released during animated frame delivery'
          : 'last listener can remove itself during animated frame delivery',
      (WidgetTester tester) async {
        ImageStreamCompleterHandle? handle;
        late final AnimatedCompleterFixture fixture;
        fixture = AnimatedCompleterFixture(
          onImage: (image) {
            fixture.completer.removeListener(fixture.listener);
            handle?.dispose();
            // The delivered clone remains owned by its listener.
            expect(image.image.debugDisposed, false);
          },
        );
        final codec = fixture.codec;
        if (keptAlive) handle = fixture.completer.keepAlive();
        await tester.idle();

        final frame = FakeFrameInfo(
          const Duration(milliseconds: 200),
          image20x10.clone(),
        );
        codec.completeNextFrame(frame);
        await tester.idle();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(fixture.emittedImages, 1);
        expect(frame.image.debugDisposed, true);
        // Final disposal during delivery must not request another frame.
        expect(codec.numFramesAsked, 1);
      },
    );
  }

  testWidgets('final disposal drains codec events and releases the codec', (
    tester,
  ) async {
    final fixture = AnimatedCompleterFixture();
    await tester.idle();
    final firstHandle = fixture.completer.keepAlive();
    final lastHandle = fixture.completer.keepAlive();
    fixture.completer.removeListener(fixture.listener);
    firstHandle.dispose();
    expect(fixture.codec.disposeCount, 0);
    expect(fixture.codecStream.hasListener, true);
    lastHandle.dispose();
    expect(fixture.codec.disposeCount, 1);
    expect(fixture.codecStream.hasListener, true);
    final lateCodec = MockCodec();
    fixture.codecStream.add(lateCodec);
    fixture.codecStream.addError(StateError('late codec failure'));
    await tester.idle();
    expect(lateCodec.disposeCount, 1);
    expect(lateCodec.numFramesAsked, 0);
    addTearDown(() async {
      await fixture.codecStream.close();
      expect(fixture.codecStream.hasListener, false);
    });
    final lateFrame = FakeFrameInfo(Duration.zero, image20x10.clone());
    fixture.codec.completeNextFrame(lateFrame);
    await tester.idle();
    expect(lateFrame.image.debugDisposed, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replacing a codec disposes it while its decode is in flight', (
    tester,
  ) async {
    final fixture = AnimatedCompleterFixture();
    await tester.idle();
    final replacement = MockCodec();
    fixture.codecStream.add(replacement);
    await tester.idle();
    expect(fixture.codec.disposeCount, 1);
    expect(replacement.disposeCount, 0);
    fixture.codec.failNextFrame('disposed codec');
    await tester.idle();
    expect(tester.takeException(), isNull);
    fixture.completer.removeListener(fixture.listener);
    expect(replacement.disposeCount, 1);
  });

  testWidgets('pending codecs are disposed on replacement and final disposal', (
    tester,
  ) async {
    final fixture = AnimatedCompleterFixture();
    await tester.idle();
    fixture.codec.completeNextFrame(
      FakeFrameInfo(const Duration(milliseconds: 200), image20x10.clone()),
    );
    await tester.idle();
    await tester.pump();
    fixture.codec.completeNextFrame(
      FakeFrameInfo(const Duration(milliseconds: 200), image200x100.clone()),
    );
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 50));
    final pending = MockCodec();
    final replacement = MockCodec();
    fixture.codecStream.add(pending);
    await tester.idle();
    fixture.codecStream.add(replacement);
    await tester.idle();
    expect(pending.disposeCount, 1);
    expect(fixture.codec.disposeCount, 0);
    expect(replacement.disposeCount, 0);
    fixture.completer.removeListener(fixture.listener);
    expect(fixture.codec.disposeCount, 1);
    expect(replacement.disposeCount, 1);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh after a completed play-once animation is decoded', (
    tester,
  ) async {
    final fixture = AnimatedCompleterFixture();
    fixture.codec.repetitionCount = 0;
    await tester.idle();
    fixture.codec.completeNextFrame(
      FakeFrameInfo(const Duration(milliseconds: 200), image20x10.clone()),
    );
    await tester.idle();
    await tester.pump();
    fixture.codec.completeNextFrame(
      FakeFrameInfo(const Duration(milliseconds: 200), image200x100.clone()),
    );
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 150));
    expect(fixture.emittedImages, 2);
    final refresh = MockCodec();
    fixture.codecStream.add(refresh);
    await tester.idle();
    expect(refresh.numFramesAsked, 1);
    refresh.completeNextFrame(
      FakeFrameInfo(Duration.zero, image300x100.clone()),
    );
    await tester.idle();
    expect(fixture.emittedImages, 3);
    fixture.completer.removeListener(fixture.listener);
    expect(fixture.codec.disposeCount, 1);
    expect(refresh.disposeCount, 1);
  });

  for (final pendingIsActive in [false, true]) {
    testWidgets(
      'repeated pending codec is disposed once (active: $pendingIsActive)',
      (tester) async {
        final fixture = AnimatedCompleterFixture();
        await tester.idle();
        fixture.codec.completeNextFrame(
          FakeFrameInfo(const Duration(milliseconds: 200), image20x10.clone()),
        );
        await tester.idle();
        await tester.pump();
        fixture.codec.completeNextFrame(
          FakeFrameInfo(
            const Duration(milliseconds: 200),
            image200x100.clone(),
          ),
        );
        await tester.idle();
        await tester.pump(const Duration(milliseconds: 50));
        final pending = pendingIsActive ? fixture.codec : MockCodec();
        fixture.codecStream.add(pending);
        fixture.codecStream.add(pending);
        await tester.idle();
        expect(pending.disposeCount, 0);
        fixture.completer.removeListener(fixture.listener);
        expect(pending.disposeCount, 1);
        expect(fixture.codec.disposeCount, 1);
      },
    );
  }

  testWidgets('switching to a pending codec releases the previous codec', (
    tester,
  ) async {
    final fixture = AnimatedCompleterFixture();
    await tester.idle();
    fixture.codec.completeNextFrame(
      FakeFrameInfo(const Duration(milliseconds: 200), image20x10.clone()),
    );
    await tester.idle();
    await tester.pump();
    fixture.codec.completeNextFrame(
      FakeFrameInfo(const Duration(milliseconds: 200), image200x100.clone()),
    );
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 50));
    final pending = MockCodec();
    fixture.codecStream.add(pending);
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 200));
    expect(fixture.codec.disposeCount, 1);
    expect(pending.numFramesAsked, 1);
    expect(pending.disposeCount, 0);
    fixture.completer.removeListener(fixture.listener);
    expect(pending.disposeCount, 1);
  });

  for (final scenario in [
    (pause: false, resume: false),
    (pause: true, resume: false),
    (pause: true, resume: true),
  ]) {
    final pauseBeforeRefresh = scenario.pause;
    final resumeBeforeRefresh = scenario.resume;
    testWidgets(
      'newest refresh supersedes parked codec (pause: $pauseBeforeRefresh, resume: $resumeBeforeRefresh)',
      (tester) async {
        final fixture = AnimatedCompleterFixture();
        final handle = fixture.completer.keepAlive();
        await tester.idle();
        fixture.codec.completeNextFrame(
          FakeFrameInfo(const Duration(milliseconds: 200), image20x10.clone()),
        );
        await tester.idle();
        await tester.pump();
        final waitingFrame = FakeFrameInfo(
          const Duration(milliseconds: 200),
          image200x100.clone(),
        );
        fixture.codec.completeNextFrame(waitingFrame);
        await tester.idle();
        await tester.pump(const Duration(milliseconds: 50));
        final parked = MockCodec();
        fixture.codecStream.add(parked);
        await tester.idle();
        if (pauseBeforeRefresh) {
          fixture.completer.removeListener(fixture.listener);
          if (resumeBeforeRefresh) {
            fixture.completer.addListener(fixture.listener);
          }
        }
        final newest = MockCodec()
          ..frameCount = 2
          ..repetitionCount = -1;
        fixture.codecStream.add(newest);
        await tester.idle();
        expect(parked.disposeCount, 1);
        expect(parked.numFramesAsked, 0);
        if (pauseBeforeRefresh && !resumeBeforeRefresh) {
          expect(newest.numFramesAsked, 0);
          fixture.completer.addListener(fixture.listener);
          await tester.idle();
        }
        if (!pauseBeforeRefresh) {
          // The current animation finishes its cycle before the refresh.
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(fixture.codec.disposeCount, 1);
        expect(newest.numFramesAsked, 1);
        // Play beyond a full cycle: no superseded codec may return.
        for (var frame = 0; frame < 3; frame++) {
          newest.completeNextFrame(
            FakeFrameInfo(
              const Duration(milliseconds: 200),
              image300x100.clone(),
            ),
          );
          await tester.idle();
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(waitingFrame.image.debugDisposed, true);
        expect(newest.numFramesAsked, 4);
        expect(newest.disposeCount, 0);
        expect(parked.numFramesAsked, 0);
        fixture.completer.removeListener(fixture.listener);
        handle.dispose();
        expect(newest.disposeCount, 1);
        expect(parked.disposeCount, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'synchronous refresh during delivery preserves new animation cycle',
    (tester) async {
      final stream = StreamController<Codec>(sync: true);
      addTearDown(stream.close);
      final original = MockCodec()
        ..frameCount = 2
        ..repetitionCount = 0;
      final refresh = MockCodec()
        ..frameCount = 2
        ..repetitionCount = 0;
      final completer = MultiImageStreamCompleter(
        codec: stream.stream,
        scale: 1,
      );
      var delivered = 0;
      final listener = ImageStreamListener((image, _) {
        delivered++;
        image.dispose();
        if (delivered == 1) stream.add(refresh);
      });
      completer.addListener(listener);
      stream.add(original);
      original.completeNextFrame(
        FakeFrameInfo(const Duration(milliseconds: 200), image20x10.clone()),
      );
      await tester.idle();
      await tester.pump();
      expect(original.disposeCount, 1);
      expect(refresh.numFramesAsked, 1);
      refresh.completeNextFrame(
        FakeFrameInfo(const Duration(milliseconds: 200), image200x100.clone()),
      );
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 200));
      expect(refresh.numFramesAsked, 2);
      refresh.completeNextFrame(
        FakeFrameInfo(const Duration(milliseconds: 200), image300x100.clone()),
      );
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 200));
      expect(delivered, 3);
      expect(original.numFramesAsked, 1);
      expect(refresh.numFramesAsked, 2);
      expect(refresh.disposeCount, 0);
      completer.removeListener(listener);
      expect(refresh.disposeCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'synchronous refresh preserves the delivered non-first frame duration',
    (tester) async {
      final stream = StreamController<Codec>(sync: true);
      addTearDown(stream.close);
      final original = MockCodec()..frameCount = 3;
      final refresh = MockCodec()
        ..frameCount = 2
        ..repetitionCount = 0;
      final completer = MultiImageStreamCompleter(
        codec: stream.stream,
        scale: 1,
      );
      var delivered = 0;
      final listener = ImageStreamListener((image, _) {
        delivered++;
        image.dispose();
        if (delivered == 2) stream.add(refresh);
      });
      completer.addListener(listener);
      addTearDown(() {
        if (completer.hasListeners) completer.removeListener(listener);
      });
      stream.add(original);
      original.completeNextFrame(
        FakeFrameInfo(const Duration(milliseconds: 100), image20x10.clone()),
      );
      await tester.idle();
      await tester.pump();
      original.completeNextFrame(
        FakeFrameInfo(const Duration(milliseconds: 400), image200x100.clone()),
      );
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 100));
      refresh.completeNextFrame(
        FakeFrameInfo(const Duration(milliseconds: 50), image300x100.clone()),
      );
      await tester.idle();
      await tester.pump();
      expect(delivered, 2);
      await tester.pump(const Duration(milliseconds: 399));
      expect(delivered, 2);
      await tester.pump(const Duration(milliseconds: 1));
      expect(delivered, 3);
      expect(original.numFramesAsked, 2);
      expect(original.disposeCount, 1);
      refresh.completeNextFrame(
        FakeFrameInfo(const Duration(milliseconds: 50), image300x100.clone()),
      );
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 50));
      expect(delivered, 4);
      completer.removeListener(listener);
      expect(refresh.disposeCount, 1);
    },
  );

  testWidgets('base disposal releases codecs before any listener was added', (
    tester,
  ) async {
    final stream = StreamController<Codec>();
    addTearDown(stream.close);
    final codec = MockCodec();
    final completer = MultiImageStreamCompleter(codec: stream.stream, scale: 1);
    final handle = completer.keepAlive();
    stream.add(codec);
    await tester.idle();
    handle.dispose();
    expect(codec.disposeCount, 1);
    final lateCodec = MockCodec();
    stream.add(lateCodec);
    await tester.idle();
    expect(lateCodec.disposeCount, 1);
  });

  testWidgets('listener removal with keep-alive pauses decoding until resumed', (
    tester,
  ) async {
    late final AnimatedCompleterFixture fixture;
    fixture = AnimatedCompleterFixture(
      onImage: (_) {
        fixture.completer.removeListener(fixture.listener);
      },
    );
    final handle = fixture.completer.keepAlive();
    await tester.idle();
    fixture.codec.completeNextFrame(
      FakeFrameInfo(const Duration(milliseconds: 200), image20x10.clone()),
    );
    await tester.idle();
    await tester.pump();
    expect(fixture.codec.numFramesAsked, 1);
    expect(fixture.codec.disposeCount, 0);
    // A fresh listener resumes the next frame rather than replaying the first.
    final listener = ImageStreamListener((image, _) => image.dispose());
    fixture.completer.addListener(listener);
    await tester.idle();
    expect(fixture.codec.numFramesAsked, 2);
    fixture.codec.completeNextFrame(
      FakeFrameInfo(const Duration(milliseconds: 200), image200x100.clone()),
    );
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 200));
    expect(fixture.codec.numFramesAsked, 3);
    fixture.completer.removeListener(listener);
    handle.dispose();
    expect(fixture.codec.disposeCount, 1);
  });

  testWidgets(
    'pending refresh is selected when delivery removes last listener',
    (tester) async {
      late final AnimatedCompleterFixture fixture;
      fixture = AnimatedCompleterFixture(
        onImage: (_) {
          if (fixture.emittedImages == 2) {
            fixture.completer.removeListener(fixture.listener);
          }
        },
      );
      fixture.codec.repetitionCount = 0;
      final handle = fixture.completer.keepAlive();
      await tester.idle();
      fixture.codec.completeNextFrame(
        FakeFrameInfo(const Duration(milliseconds: 200), image20x10.clone()),
      );
      await tester.idle();
      await tester.pump();
      fixture.codec.completeNextFrame(
        FakeFrameInfo(const Duration(milliseconds: 200), image200x100.clone()),
      );
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 50));
      final refresh = MockCodec();
      fixture.codecStream.add(refresh);
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 200));
      expect(fixture.emittedImages, 2);
      expect(fixture.codec.disposeCount, 1);
      expect(refresh.numFramesAsked, 0);

      final images = <ImageInfo>[];
      final listener = ImageStreamListener((image, _) => images.add(image));
      fixture.completer.addListener(listener);
      await tester.idle();
      expect(refresh.numFramesAsked, 1);
      expect(fixture.codec.numFramesAsked, 2);
      refresh.completeNextFrame(
        FakeFrameInfo(Duration.zero, image300x100.clone()),
      );
      await tester.idle();
      expect(images.length, 2);
      expect(images.last.image.isCloneOf(image300x100), true);
      for (final image in images) {
        image.dispose();
      }
      fixture.completer.removeListener(listener);
      handle.dispose();
      expect(refresh.disposeCount, 1);
    },
  );

  for (final asyncGenerator in [false, true]) {
    Stream<Codec> codecStream(Future<Codec> future) async* {
      yield await future;
    }

    testWidgets(
      'late codec is disposed after completer disposal (async generator: $asyncGenerator)',
      (tester) async {
        final future = Completer<Codec>();
        final stream = asyncGenerator
            ? codecStream(future.future)
            : future.future.asStream();
        final completer = MultiImageStreamCompleter(codec: stream, scale: 1);
        final listener = ImageStreamListener((image, _) => image.dispose());
        completer.addListener(listener);
        await tester.idle();
        completer.removeListener(listener);
        final codec = MockCodec();
        future.complete(codec);
        await tester.idle();
        expect(codec.disposeCount, 1);
        expect(codec.numFramesAsked, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'late codec error is ignored after disposal (async generator: $asyncGenerator)',
      (tester) async {
        final future = Completer<Codec>();
        final stream = asyncGenerator
            ? codecStream(future.future)
            : future.future.asStream();
        final completer = MultiImageStreamCompleter(codec: stream, scale: 1);
        final listener = ImageStreamListener((image, _) => image.dispose());
        completer.addListener(listener);
        await tester.idle();
        completer.removeListener(listener);
        future.completeError(StateError('late decode failure'));
        await tester.idle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Decoding starts when a listener is added after codec is ready', (
    WidgetTester tester,
  ) async {
    final codecStream = StreamController<Codec>();
    final mockCodec = MockCodec();
    mockCodec.frameCount = 1;
    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    codecStream.add(mockCodec);
    await tester.idle();
    expect(mockCodec.numFramesAsked, 0);

    listener(ImageInfo image, bool synchronousCall) {}
    imageStream.addListener(ImageStreamListener(listener));
    await tester.idle();
    expect(mockCodec.numFramesAsked, 1);
  });

  testWidgets(
    'Decoding starts when a codec is ready after a listener is added',
    (WidgetTester tester) async {
      final codecStream = StreamController<Codec>();
      final mockCodec = MockCodec();
      mockCodec.frameCount = 1;
      final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
        codec: codecStream.stream,
        scale: 1.0,
      );

      listener(ImageInfo image, bool synchronousCall) {}
      imageStream.addListener(ImageStreamListener(listener));
      await tester.idle();
      expect(mockCodec.numFramesAsked, 0);

      codecStream.add(mockCodec);
      await tester.idle();
      expect(mockCodec.numFramesAsked, 1);
    },
  );

  testWidgets('Adding a second codec triggers start decoding', (
    WidgetTester tester,
  ) async {
    final codecStream = StreamController<Codec>();
    final firstCodec = MockCodec();
    final secondCodec = MockCodec();
    firstCodec.frameCount = 1;
    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    listener(ImageInfo image, bool synchronousCall) {}
    imageStream.addListener(ImageStreamListener(listener));
    await tester.idle();
    expect(firstCodec.numFramesAsked, 0);

    codecStream.add(firstCodec);
    await tester.idle();
    expect(firstCodec.numFramesAsked, 1);

    expect(secondCodec.numFramesAsked, 0);

    codecStream.add(secondCodec);
    await tester.idle();
    expect(secondCodec.numFramesAsked, 1);
  });

  testWidgets('Decoding does not crash when disposed', (
    WidgetTester tester,
  ) async {
    final codecStream = StreamController<Codec>();
    final mockCodec = MockCodec();
    mockCodec.frameCount = 1;
    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    codecStream.add(mockCodec);
    await tester.idle();
    expect(mockCodec.numFramesAsked, 0);

    listener(ImageInfo image, bool synchronousCall) {}
    final streamListener = ImageStreamListener(listener);
    imageStream.addListener(streamListener);
    await tester.idle();
    expect(mockCodec.numFramesAsked, 1);

    final FrameInfo frame = FakeFrameInfo(
      const Duration(milliseconds: 200),
      image20x10,
    );
    mockCodec.completeNextFrame(frame);
    imageStream.removeListener(streamListener);
    await tester.idle();
  });

  testWidgets('Chunk events of base ImageStreamCompleter are delivered', (
    WidgetTester tester,
  ) async {
    final chunkEvents = <ImageChunkEvent>[];
    final streamController = StreamController<ImageChunkEvent>();
    final ImageStreamCompleter imageStream =
        FakeEventReportingImageStreamCompleter(
          chunkEvents: streamController.stream,
        );

    imageStream.addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {},
        onChunk: (ImageChunkEvent event) {
          chunkEvents.add(event);
        },
      ),
    );
    streamController.add(
      const ImageChunkEvent(cumulativeBytesLoaded: 1, expectedTotalBytes: 3),
    );
    streamController.add(
      const ImageChunkEvent(cumulativeBytesLoaded: 2, expectedTotalBytes: 3),
    );
    await tester.idle();

    expect(chunkEvents.length, 2);
    expect(chunkEvents[0].cumulativeBytesLoaded, 1);
    expect(chunkEvents[0].expectedTotalBytes, 3);
    expect(chunkEvents[1].cumulativeBytesLoaded, 2);
    expect(chunkEvents[1].expectedTotalBytes, 3);
  });

  testWidgets(
    'Chunk events of base ImageStreamCompleter are not buffered before listener registration',
    (WidgetTester tester) async {
      final chunkEvents = <ImageChunkEvent>[];
      final streamController = StreamController<ImageChunkEvent>();
      final ImageStreamCompleter imageStream =
          FakeEventReportingImageStreamCompleter(
            chunkEvents: streamController.stream,
          );

      streamController.add(
        const ImageChunkEvent(cumulativeBytesLoaded: 1, expectedTotalBytes: 3),
      );
      await tester.idle();
      imageStream.addListener(
        ImageStreamListener(
          (ImageInfo image, bool synchronousCall) {},
          onChunk: (ImageChunkEvent event) {
            chunkEvents.add(event);
          },
        ),
      );
      streamController.add(
        const ImageChunkEvent(cumulativeBytesLoaded: 2, expectedTotalBytes: 3),
      );
      await tester.idle();

      expect(chunkEvents.length, 1);
      expect(chunkEvents[0].cumulativeBytesLoaded, 2);
      expect(chunkEvents[0].expectedTotalBytes, 3);
    },
  );

  testWidgets('Chunk events of MultiImageStreamCompleter are delivered', (
    WidgetTester tester,
  ) async {
    final chunkEvents = <ImageChunkEvent>[];
    final codecStream = StreamController<Codec>();
    final streamController = StreamController<ImageChunkEvent>();
    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      chunkEvents: streamController.stream,
      scale: 1.0,
    );

    imageStream.addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {},
        onChunk: (ImageChunkEvent event) {
          chunkEvents.add(event);
        },
      ),
    );
    streamController.add(
      const ImageChunkEvent(cumulativeBytesLoaded: 1, expectedTotalBytes: 3),
    );
    streamController.add(
      const ImageChunkEvent(cumulativeBytesLoaded: 2, expectedTotalBytes: 3),
    );
    await tester.idle();

    expect(chunkEvents.length, 2);
    expect(chunkEvents[0].cumulativeBytesLoaded, 1);
    expect(chunkEvents[0].expectedTotalBytes, 3);
    expect(chunkEvents[1].cumulativeBytesLoaded, 2);
    expect(chunkEvents[1].expectedTotalBytes, 3);
  });

  testWidgets(
    'Chunk events of MultiImageStreamCompleter are not buffered before listener registration',
    (WidgetTester tester) async {
      final chunkEvents = <ImageChunkEvent>[];
      final codecStream = StreamController<Codec>();
      final streamController = StreamController<ImageChunkEvent>();
      final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
        codec: codecStream.stream,
        chunkEvents: streamController.stream,
        scale: 1.0,
      );

      streamController.add(
        const ImageChunkEvent(cumulativeBytesLoaded: 1, expectedTotalBytes: 3),
      );
      await tester.idle();
      imageStream.addListener(
        ImageStreamListener(
          (ImageInfo image, bool synchronousCall) {},
          onChunk: (ImageChunkEvent event) {
            chunkEvents.add(event);
          },
        ),
      );
      streamController.add(
        const ImageChunkEvent(cumulativeBytesLoaded: 2, expectedTotalBytes: 3),
      );
      await tester.idle();

      expect(chunkEvents.length, 1);
      expect(chunkEvents[0].cumulativeBytesLoaded, 2);
      expect(chunkEvents[0].expectedTotalBytes, 3);
    },
  );

  testWidgets('Chunk errors are reported', (WidgetTester tester) async {
    final chunkEvents = <ImageChunkEvent>[];
    final codecStream = StreamController<Codec>();
    final streamController = StreamController<ImageChunkEvent>();
    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      chunkEvents: streamController.stream,
      scale: 1.0,
    );

    imageStream.addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {},
        onChunk: (ImageChunkEvent event) {
          chunkEvents.add(event);
        },
      ),
    );
    streamController.addError(Error());
    streamController.add(
      const ImageChunkEvent(cumulativeBytesLoaded: 2, expectedTotalBytes: 3),
    );
    await tester.idle();

    expect(tester.takeException(), isNotNull);
    expect(chunkEvents.length, 1);
    expect(chunkEvents[0].cumulativeBytesLoaded, 2);
    expect(chunkEvents[0].expectedTotalBytes, 3);
  });

  testWidgets('getNextFrame future fails', (WidgetTester tester) async {
    final mockCodec = MockCodec();
    mockCodec.frameCount = 1;
    final codecStream = StreamController<Codec>();

    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    listener(ImageInfo image, bool synchronousCall) {}
    imageStream.addListener(ImageStreamListener(listener));
    codecStream.add(mockCodec);
    // MultiImageStreamCompleter only sets an error handler for the next
    // frame future after the codec future has completed.
    // Idling here lets the MultiImageStreamCompleter advance and set the
    // error handler for the nextFrame future.
    await tester.idle();

    mockCodec.failNextFrame('frame completion error');
    await tester.idle();

    expect(tester.takeException(), 'frame completion error');
  });

  testWidgets('ImageStream emits frame (static image)', (
    WidgetTester tester,
  ) async {
    final mockCodec = MockCodec();
    mockCodec.frameCount = 1;
    final codecStream = StreamController<Codec>();

    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    final emittedImages = <ImageInfo>[];
    imageStream.addListener(
      ImageStreamListener((ImageInfo image, bool synchronousCall) {
        emittedImages.add(image);
      }),
    );

    codecStream.add(mockCodec);
    await tester.idle();

    final FrameInfo frame = FakeFrameInfo(
      const Duration(milliseconds: 200),
      image20x10,
    );
    mockCodec.completeNextFrame(frame);
    await tester.idle();

    expect(
      emittedImages.every(
        (ImageInfo info) => info.image.isCloneOf(frame.image),
      ),
      true,
    );
  });

  testWidgets('ImageStream emits the completer debugLabel (static image)', (
    WidgetTester tester,
  ) async {
    final mockCodec = MockCodec();
    mockCodec.frameCount = 1;
    final codecStream = StreamController<Codec>();

    const String debugLabel = 'debug label';
    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
      debugLabel: debugLabel,
    );

    final emittedImages = <ImageInfo>[];
    imageStream.addListener(
      ImageStreamListener((ImageInfo image, bool synchronousCall) {
        emittedImages.add(image);
      }),
    );

    codecStream.add(mockCodec);
    await tester.idle();

    mockCodec.completeNextFrame(
      FakeFrameInfo(const Duration(milliseconds: 200), image20x10),
    );
    await tester.idle();

    expect(emittedImages.single.debugLabel, debugLabel);
  });

  testWidgets('ImageStream emits the completer debugLabel (animated images)', (
    WidgetTester tester,
  ) async {
    final mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = 0;
    final codecStream = StreamController<Codec>();

    const String debugLabel = 'debug label';
    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
      debugLabel: debugLabel,
    );

    final emittedImages = <ImageInfo>[];
    imageStream.addListener(
      ImageStreamListener((ImageInfo image, bool synchronousCall) {
        emittedImages.add(image);
      }),
    );

    codecStream.add(mockCodec);
    await tester.idle();

    mockCodec.completeNextFrame(
      FakeFrameInfo(const Duration(milliseconds: 200), image20x10),
    );
    await tester.idle();

    // Animated images are emitted on an animation tick instead of directly.
    await tester.pump();

    expect(emittedImages.single.debugLabel, debugLabel);
  });

  testWidgets('ImageStream emits frames (animated images)', (
    WidgetTester tester,
  ) async {
    final mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = -1;
    final codecStream = StreamController<Codec>();

    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    final emittedImages = <ImageInfo>[];
    imageStream.addListener(
      ImageStreamListener((ImageInfo image, bool synchronousCall) {
        emittedImages.add(image);
      }),
    );

    codecStream.add(mockCodec);
    await tester.idle();

    final FrameInfo frame1 = FakeFrameInfo(
      const Duration(milliseconds: 200),
      image20x10,
    );
    mockCodec.completeNextFrame(frame1);
    await tester.idle();
    // We are waiting for the next animation tick, so at this point no frames
    // should have been emitted.
    expect(emittedImages.length, 0);

    await tester.pump();
    expect(emittedImages.single.image.isCloneOf(frame1.image), true);

    final FrameInfo frame2 = FakeFrameInfo(
      const Duration(milliseconds: 400),
      image200x100,
    );
    mockCodec.completeNextFrame(frame2);

    await tester.pump(const Duration(milliseconds: 100));
    // The duration for the current frame was 200ms, so we don't emit the next
    // frame yet even though it is ready.
    expect(emittedImages.length, 1);

    await tester.pump(const Duration(milliseconds: 100));
    expect(emittedImages[0].image.isCloneOf(frame1.image), true);
    expect(emittedImages[1].image.isCloneOf(frame2.image), true);

    // Let the pending timer for the next frame to complete so we can cleanly
    // quit the test without pending timers.
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('animation wraps back', (WidgetTester tester) async {
    final mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = -1;
    final codecStream = StreamController<Codec>();

    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    final emittedImages = <ImageInfo>[];
    imageStream.addListener(
      ImageStreamListener((ImageInfo image, bool synchronousCall) {
        emittedImages.add(image);
      }),
    );

    codecStream.add(mockCodec);
    await tester.idle();

    final frame1 = FakeFrameInfo(const Duration(milliseconds: 200), image20x10);
    final frame2 = FakeFrameInfo(
      const Duration(milliseconds: 400),
      image200x100,
    );

    mockCodec.completeNextFrame(frame1.clone());
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // first animation frame shows on first app frame.
    mockCodec.completeNextFrame(frame2.clone());
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(const Duration(milliseconds: 200)); // emit 2nd frame.
    mockCodec.completeNextFrame(frame1.clone());
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(const Duration(milliseconds: 400)); // emit 3rd frame

    expect(emittedImages[0].image.isCloneOf(frame1.image), true);
    expect(emittedImages[1].image.isCloneOf(frame2.image), true);
    expect(emittedImages[2].image.isCloneOf(frame1.image), true);

    // Let the pending timer for the next frame to complete so we can cleanly
    // quit the test without pending timers.
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('animation doesnt repeat more than specified', (
    WidgetTester tester,
  ) async {
    final mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = 0;
    final codecStream = StreamController<Codec>();

    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    final emittedImages = <ImageInfo>[];
    imageStream.addListener(
      ImageStreamListener((ImageInfo image, bool synchronousCall) {
        emittedImages.add(image);
      }),
    );

    codecStream.add(mockCodec);
    await tester.idle();

    final FrameInfo frame1 = FakeFrameInfo(
      const Duration(milliseconds: 200),
      image20x10,
    );
    final FrameInfo frame2 = FakeFrameInfo(
      const Duration(milliseconds: 400),
      image200x100,
    );

    mockCodec.completeNextFrame(frame1);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // first animation frame shows on first app frame.
    mockCodec.completeNextFrame(frame2);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(const Duration(milliseconds: 200)); // emit 2nd frame.
    mockCodec.completeNextFrame(frame1);
    // allow another frame to complete (but we shouldn't be asking for it as
    // this animation should not repeat.
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 400));

    expect(emittedImages[0].image.isCloneOf(frame1.image), true);
    expect(emittedImages[1].image.isCloneOf(frame2.image), true);
  });

  testWidgets('frames are only decoded when there are listeners', (
    WidgetTester tester,
  ) async {
    final mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = -1;
    final codecStream = StreamController<Codec>();

    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    listener(ImageInfo image, bool synchronousCall) {}
    imageStream.addListener(ImageStreamListener(listener));
    final handle = imageStream.keepAlive();

    codecStream.add(mockCodec);
    await tester.idle();

    final FrameInfo frame1 = FakeFrameInfo(
      const Duration(milliseconds: 200),
      image20x10,
    );
    final FrameInfo frame2 = FakeFrameInfo(
      const Duration(milliseconds: 400),
      image200x100,
    );

    mockCodec.completeNextFrame(frame1);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // first animation frame shows on first app frame.
    mockCodec.completeNextFrame(frame2);
    imageStream.removeListener(ImageStreamListener(listener));
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(const Duration(milliseconds: 400)); // emit 2nd frame.

    // Decoding of the 3rd frame should not start as there are no registered
    // listeners to the stream
    expect(mockCodec.numFramesAsked, 2);

    // Re-adding shows the waiting 2nd frame before asking for the 3rd.
    imageStream.addListener(ImageStreamListener(listener));
    await tester.idle();
    expect(mockCodec.numFramesAsked, 2);

    await tester.pump();
    expect(mockCodec.numFramesAsked, 3);

    handle.dispose();
  });

  testWidgets(
    'static images are not decoded again when a listener is re-added',
    (WidgetTester tester) async {
      final mockCodec = MockCodec();
      final codecStream = StreamController<Codec>();

      final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
        codec: codecStream.stream,
        scale: 1.0,
      );

      var emittedImages = 0;
      listener(ImageInfo image, bool synchronousCall) => emittedImages += 1;
      imageStream.addListener(ImageStreamListener(listener));
      final handle = imageStream.keepAlive();

      codecStream.add(mockCodec);
      await tester.idle();
      mockCodec.completeNextFrame(FakeFrameInfo(Duration.zero, image20x10));
      await tester.idle();

      imageStream.removeListener(ImageStreamListener(listener));
      imageStream.addListener(ImageStreamListener(listener));
      await tester.idle();

      expect(mockCodec.numFramesAsked, 1);
      expect(emittedImages, 2);

      handle.dispose();
    },
  );

  testWidgets('multiple stream listeners', (WidgetTester tester) async {
    final mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = -1;
    final codecStream = StreamController<Codec>();

    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    final emittedImages1 = <ImageInfo>[];
    listener1(ImageInfo image, bool synchronousCall) {
      emittedImages1.add(image);
    }

    final emittedImages2 = <ImageInfo>[];
    listener2(ImageInfo image, bool synchronousCall) {
      emittedImages2.add(image);
    }

    imageStream.addListener(ImageStreamListener(listener1));
    imageStream.addListener(ImageStreamListener(listener2));

    codecStream.add(mockCodec);
    await tester.idle();

    final FrameInfo frame1 = FakeFrameInfo(
      const Duration(milliseconds: 200),
      image20x10,
    );
    final FrameInfo frame2 = FakeFrameInfo(
      const Duration(milliseconds: 400),
      image200x100,
    );

    mockCodec.completeNextFrame(frame1);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // first animation frame shows on first app frame.

    expect(emittedImages1.single.image.isCloneOf(frame1.image), true);
    expect(emittedImages2.single.image.isCloneOf(frame1.image), true);

    mockCodec.completeNextFrame(frame2);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // next app frame will schedule a timer.
    imageStream.removeListener(ImageStreamListener(listener1));

    await tester.pump(const Duration(milliseconds: 400)); // emit 2nd frame.
    expect(emittedImages1.single.image.isCloneOf(frame1.image), true);
    expect(emittedImages2[0].image.isCloneOf(frame1.image), true);
    expect(emittedImages2[1].image.isCloneOf(frame2.image), true);
  });

  testWidgets('timer is canceled when listeners are removed', (
    WidgetTester tester,
  ) async {
    final mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = -1;
    final codecStream = StreamController<Codec>();

    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    listener(ImageInfo image, bool synchronousCall) {}
    imageStream.addListener(ImageStreamListener(listener));

    codecStream.add(mockCodec);
    await tester.idle();

    final FrameInfo frame1 = FakeFrameInfo(
      const Duration(milliseconds: 200),
      image20x10,
    );
    final FrameInfo frame2 = FakeFrameInfo(
      const Duration(milliseconds: 400),
      image200x100,
    );

    mockCodec.completeNextFrame(frame1);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // first animation frame shows on first app frame.

    mockCodec.completeNextFrame(frame2);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump();

    imageStream.removeListener(ImageStreamListener(listener));
    // The test framework will fail this if there are pending timers at this
    // point.
  });

  testWidgets('error handlers can intercept errors', (
    WidgetTester tester,
  ) async {
    final mockCodec = MockCodec();
    mockCodec.frameCount = 1;
    final codecStream = StreamController<Codec>();

    final ImageStreamCompleter streamUnderTest = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    Object? capturedException;
    errorListener(Object exception, StackTrace? stackTrace) {
      capturedException = exception;
    }

    streamUnderTest.addListener(
      ImageStreamListener(
        (ImageInfo image, bool synchronousCall) {},
        onError: errorListener,
      ),
    );

    codecStream.add(mockCodec);
    // MultiImageStreamCompleter only sets an error handler for the next
    // frame future after the codec future has completed.
    // Idling here lets the MultiImageStreamCompleter advance and set the
    // error handler for the nextFrame future.
    await tester.idle();

    mockCodec.failNextFrame('frame completion error');
    await tester.idle();

    // No exception is passed up.
    expect(tester.takeException(), isNull);
    expect(capturedException, 'frame completion error');
  });

  testWidgets('remove and add listener ', (WidgetTester tester) async {
    final mockCodec = MockCodec();
    mockCodec.frameCount = 3;
    mockCodec.repetitionCount = 0;
    final codecStream = StreamController<Codec>();

    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    listener(ImageInfo image, bool synchronousCall) {}
    imageStream.addListener(ImageStreamListener(listener));

    codecStream.add(mockCodec);

    await tester.idle(); // let nextFrameFuture complete

    imageStream.addListener(ImageStreamListener(listener));
    imageStream.removeListener(ImageStreamListener(listener));

    final FrameInfo frame1 = FakeFrameInfo(
      const Duration(milliseconds: 200),
      image20x10,
    );

    mockCodec.completeNextFrame(frame1);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // first animation frame shows on first app frame.

    await tester.pump(const Duration(milliseconds: 200)); // emit 2nd frame.
  });

  testWidgets(
    'Keep alive handles do not drive frames or prevent last listener callbacks',
    (WidgetTester tester) async {
      final image10x10 = (await tester.runAsync(
        () => createTestImage(width: 10, height: 10),
      ));
      final mockCodec = MockCodec();
      mockCodec.frameCount = 2;
      mockCodec.repetitionCount = -1;
      final codecStream = StreamController<Codec>();

      final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
        codec: codecStream.stream,
        scale: 1.0,
      );

      var onImageCount = 0;
      activeListener(ImageInfo image, bool synchronousCall) {
        onImageCount += 1;
      }

      var lastListenerDropped = false;
      imageStream.addOnLastListenerRemovedCallback(() {
        lastListenerDropped = true;
      });

      expect(lastListenerDropped, false);
      final handle = imageStream.keepAlive();
      expect(lastListenerDropped, false);
      SchedulerBinding.instance.debugAssertNoTransientCallbacks(
        'Only passive listeners',
      );

      codecStream.add(mockCodec);
      await tester.idle();

      expect(onImageCount, 0);

      final frame1 = FakeFrameInfo(Duration.zero, image20x10);
      mockCodec.completeNextFrame(frame1);
      await tester.idle();
      SchedulerBinding.instance.debugAssertNoTransientCallbacks(
        'Only passive listeners',
      );
      await tester.pump();
      expect(onImageCount, 0);

      imageStream.addListener(ImageStreamListener(activeListener));

      final frame2 = FakeFrameInfo(Duration.zero, image10x10!);
      mockCodec.completeNextFrame(frame2);
      await tester.idle();
      expect(SchedulerBinding.instance.transientCallbackCount, 1);
      await tester.pump();

      expect(onImageCount, 1);

      imageStream.removeListener(ImageStreamListener(activeListener));
      expect(lastListenerDropped, true);

      mockCodec.completeNextFrame(frame1);
      await tester.idle();
      expect(SchedulerBinding.instance.transientCallbackCount, 1);
      await tester.pump();

      expect(onImageCount, 1);

      SchedulerBinding.instance.debugAssertNoTransientCallbacks(
        'Only passive listeners',
      );

      mockCodec.completeNextFrame(frame2);
      await tester.idle();
      SchedulerBinding.instance.debugAssertNoTransientCallbacks(
        'Only passive listeners',
      );
      await tester.pump();

      expect(onImageCount, 1);

      handle.dispose();
    },
  );

  testWidgets('Multi-frame image is completed before next image is shown', (
    WidgetTester tester,
  ) async {
    final firstCodec = MockCodec();
    firstCodec.frameCount = 3;
    firstCodec.repetitionCount = -1;
    final secondCodec = MockCodec();

    final codecStream = StreamController<Codec>();

    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    listener(ImageInfo image, bool synchronousCall) {}
    imageStream.addListener(ImageStreamListener(listener));

    codecStream.add(firstCodec);
    await tester.idle();

    final FrameInfo frame1 = FakeFrameInfo(
      const Duration(milliseconds: 200),
      image20x10,
    );
    final FrameInfo frame2 = FakeFrameInfo(
      const Duration(milliseconds: 400),
      image200x100,
    );
    final FrameInfo frame3 = FakeFrameInfo(
      const Duration(milliseconds: 200),
      image300x100,
    );

    firstCodec.completeNextFrame(frame1);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // first animation frame shows on first app frame.

    firstCodec.completeNextFrame(frame2);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(const Duration(milliseconds: 100)); // second frame is
    // not yet shown, but ready.

    codecStream.add(secondCodec);
    await tester.idle(); // let nextFrameFuture complete

    await tester.pump(const Duration(milliseconds: 300)); // emit 2nd frame.
    firstCodec.completeNextFrame(frame3);
    await tester.idle(); // let nextFrameFuture complete
    expect(secondCodec.numFramesAsked, 0);
    await tester.pump(const Duration(milliseconds: 200)); // emit 3rd frame.
    await tester.idle();

    // emit 1st frame 2nd image
    await tester.pump(const Duration(milliseconds: 200));

    // Decoding of the 3rd frame should not start as we switched images
    expect(firstCodec.numFramesAsked, 3);
    expect(secondCodec.numFramesAsked, 1);
  });

  testWidgets('animated images resume decoding when a listener is re-added', (
    WidgetTester tester,
  ) async {
    final mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = -1;
    final codecStream = StreamController<Codec>();

    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    final emittedImages = <ImageInfo>[];
    listener(ImageInfo image, bool synchronousCall) {
      if (!synchronousCall) emittedImages.add(image);
    }

    imageStream.addListener(ImageStreamListener(listener));

    final handle = imageStream.keepAlive();

    codecStream.add(mockCodec);
    await tester.idle();

    final FrameInfo frame1 = FakeFrameInfo(
      const Duration(milliseconds: 200),
      image20x10,
    );
    final FrameInfo frame2 = FakeFrameInfo(
      const Duration(milliseconds: 400),
      image200x100,
    );

    // Complete and emit 1st frame (which also requests 2nd frame)
    mockCodec.completeNextFrame(frame1);
    await tester.idle();
    await tester.pump();
    expect(emittedImages.length, 1);
    expect(mockCodec.numFramesAsked, 2);

    // Complete 2nd frame while listener is removed, so it waits
    mockCodec.completeNextFrame(frame2);
    imageStream.removeListener(ImageStreamListener(listener));
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 400));

    // Still 2 frames asked while no listener is attached
    expect(mockCodec.numFramesAsked, 2);
    expect(emittedImages.length, 1);

    // Re-adding listener shows the waiting 2nd frame instead of decoding
    // another one
    imageStream.addListener(ImageStreamListener(listener));
    await tester.idle();
    expect(mockCodec.numFramesAsked, 2);

    await tester.pump();
    expect(emittedImages.length, 2);
    expect(emittedImages[1].image.isCloneOf(frame2.image), true);
    expect(mockCodec.numFramesAsked, 3);

    // Complete the next frame and verify animation continues emitting
    final FrameInfo frame3 = FakeFrameInfo(
      const Duration(milliseconds: 200),
      image300x100,
    );
    mockCodec.completeNextFrame(frame3);
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(emittedImages.length, 3);
    expect(emittedImages[2].image.isCloneOf(frame3.image), true);

    imageStream.removeListener(ImageStreamListener(listener));
    handle.dispose();
  });

  testWidgets(
    'animated frame waiting on its timer resumes when a listener is re-added',
    (WidgetTester tester) async {
      final mockCodec = MockCodec();
      mockCodec.frameCount = 2;
      mockCodec.repetitionCount = -1;
      final codecStream = StreamController<Codec>();

      final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
        codec: codecStream.stream,
        scale: 1.0,
      );

      final emittedImages = <ImageInfo>[];
      listener(ImageInfo image, bool synchronousCall) {
        if (!synchronousCall) emittedImages.add(image);
      }

      imageStream.addListener(ImageStreamListener(listener));
      final handle = imageStream.keepAlive();

      codecStream.add(mockCodec);
      await tester.idle();

      final FrameInfo frame1 = FakeFrameInfo(
        const Duration(milliseconds: 200),
        image20x10,
      );
      final FrameInfo frame2 = FakeFrameInfo(
        const Duration(milliseconds: 200),
        image200x100,
      );

      mockCodec.completeNextFrame(frame1);
      await tester.idle();
      await tester.pump();
      expect(emittedImages.length, 1);
      expect(mockCodec.numFramesAsked, 2);

      // The 2nd frame is ready but the 1st frame's duration hasn't passed, so
      // it waits on a timer
      mockCodec.completeNextFrame(frame2);
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 100));
      expect(emittedImages.length, 1);

      // Removing the listener cancels the timer
      imageStream.removeListener(ImageStreamListener(listener));
      await tester.pump(const Duration(milliseconds: 200));
      expect(emittedImages.length, 1);
      expect(mockCodec.numFramesAsked, 2);

      imageStream.addListener(ImageStreamListener(listener));
      await tester.idle();
      expect(mockCodec.numFramesAsked, 2);

      await tester.pump();
      expect(emittedImages.length, 2);
      expect(emittedImages[1].image.isCloneOf(frame2.image), true);
      expect(mockCodec.numFramesAsked, 3);

      imageStream.removeListener(ImageStreamListener(listener));
      handle.dispose();
    },
  );

  testWidgets(
    'second static codec arriving with no listeners is decoded when listener is re-added',
    (WidgetTester tester) async {
      final firstCodec = MockCodec();
      final secondCodec = MockCodec();
      final codecStream = StreamController<Codec>();

      final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
        codec: codecStream.stream,
        scale: 1.0,
      );

      final emittedImages = <ImageInfo>[];
      listener(ImageInfo image, bool synchronousCall) {
        emittedImages.add(image);
      }

      imageStream.addListener(ImageStreamListener(listener));
      final handle = imageStream.keepAlive();

      codecStream.add(firstCodec);
      await tester.idle();
      firstCodec.completeNextFrame(FakeFrameInfo(Duration.zero, image20x10));
      await tester.idle();

      expect(firstCodec.numFramesAsked, 1);
      expect(emittedImages.length, 1);

      imageStream.removeListener(ImageStreamListener(listener));

      codecStream.add(secondCodec);
      await tester.idle();
      expect(secondCodec.numFramesAsked, 0);

      imageStream.addListener(ImageStreamListener(listener));
      await tester.idle();
      expect(secondCodec.numFramesAsked, 1);

      final secondFrame = FakeFrameInfo(Duration.zero, image200x100);
      secondCodec.completeNextFrame(secondFrame.clone());
      await tester.idle();

      expect(emittedImages.last.image.isCloneOf(secondFrame.image), true);

      handle.dispose();
    },
  );

  testWidgets(
    'static image finishing decode without listeners is kept for next listener',
    (WidgetTester tester) async {
      final mockCodec = MockCodec();
      final codecStream = StreamController<Codec>();

      final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
        codec: codecStream.stream,
        scale: 1.0,
      );

      var emittedImages = 0;
      listener(ImageInfo image, bool synchronousCall) => emittedImages += 1;
      imageStream.addListener(ImageStreamListener(listener));
      final handle = imageStream.keepAlive();

      codecStream.add(mockCodec);
      await tester.idle();
      expect(mockCodec.numFramesAsked, 1);

      imageStream.removeListener(ImageStreamListener(listener));

      mockCodec.completeNextFrame(FakeFrameInfo(Duration.zero, image20x10));
      await tester.idle();
      expect(emittedImages, 0);

      imageStream.addListener(ImageStreamListener(listener));
      await tester.idle();

      expect(mockCodec.numFramesAsked, 1);
      expect(emittedImages, 1);

      handle.dispose();
    },
  );

  testWidgets(
    're-adding listener while static decode is in flight does not decode twice',
    (WidgetTester tester) async {
      final mockCodec = MockCodec();
      final codecStream = StreamController<Codec>();

      final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
        codec: codecStream.stream,
        scale: 1.0,
      );

      var emittedImages = 0;
      listener(ImageInfo image, bool synchronousCall) => emittedImages += 1;
      imageStream.addListener(ImageStreamListener(listener));
      final handle = imageStream.keepAlive();

      codecStream.add(mockCodec);
      await tester.idle();
      expect(mockCodec.numFramesAsked, 1);

      imageStream.removeListener(ImageStreamListener(listener));
      imageStream.addListener(ImageStreamListener(listener));
      await tester.idle();

      expect(mockCodec.numFramesAsked, 1);

      mockCodec.completeNextFrame(FakeFrameInfo(Duration.zero, image20x10));
      await tester.idle();

      expect(mockCodec.numFramesAsked, 1);
      expect(emittedImages, 1);

      handle.dispose();
    },
  );

  testWidgets(
    'animated codec arriving after a static placeholder shows all its frames',
    (WidgetTester tester) async {
      final placeholderCodec = MockCodec();
      final animatedCodec = MockCodec();
      animatedCodec.frameCount = 3;
      animatedCodec.repetitionCount = 0;
      final codecStream = StreamController<Codec>();

      final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
        codec: codecStream.stream,
        scale: 1.0,
      );

      final emittedImages = <ImageInfo>[];
      listener(ImageInfo image, bool synchronousCall) {
        emittedImages.add(image);
      }

      imageStream.addListener(ImageStreamListener(listener));

      codecStream.add(placeholderCodec);
      await tester.idle();
      placeholderCodec.completeNextFrame(
        FakeFrameInfo(Duration.zero, image20x10.clone()),
      );
      await tester.idle();
      expect(emittedImages.length, 1);

      codecStream.add(animatedCodec);
      await tester.idle();
      expect(animatedCodec.numFramesAsked, 1);

      final frames = [
        FakeFrameInfo(const Duration(milliseconds: 200), image200x100),
        FakeFrameInfo(const Duration(milliseconds: 200), image300x100),
        FakeFrameInfo(const Duration(milliseconds: 200), image20x10),
      ];

      animatedCodec.completeNextFrame(frames[0]);
      await tester.idle();
      await tester.pump();
      expect(animatedCodec.numFramesAsked, 2);

      animatedCodec.completeNextFrame(frames[1]);
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 200));
      expect(animatedCodec.numFramesAsked, 3);

      animatedCodec.completeNextFrame(frames[2]);
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 200));

      // Played once, so no 4th frame is asked for
      expect(animatedCodec.numFramesAsked, 3);
      expect(emittedImages.length, 4);
      expect(emittedImages[1].image.isCloneOf(frames[0].image), true);
      expect(emittedImages[2].image.isCloneOf(frames[1].image), true);
      expect(emittedImages[3].image.isCloneOf(frames[2].image), true);
    },
  );

  testWidgets(
    'waiting animated frame is dropped when a new codec arrives without listeners',
    (WidgetTester tester) async {
      final animatedCodec = MockCodec();
      animatedCodec.frameCount = 2;
      animatedCodec.repetitionCount = -1;
      final staticCodec = MockCodec();
      final codecStream = StreamController<Codec>();

      final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
        codec: codecStream.stream,
        scale: 1.0,
      );

      final emittedImages = <ImageInfo>[];
      listener(ImageInfo image, bool synchronousCall) {
        if (!synchronousCall) emittedImages.add(image);
      }

      imageStream.addListener(ImageStreamListener(listener));
      final handle = imageStream.keepAlive();

      codecStream.add(animatedCodec);
      await tester.idle();

      animatedCodec.completeNextFrame(
        FakeFrameInfo(const Duration(milliseconds: 200), image20x10),
      );
      await tester.idle();
      await tester.pump();
      expect(emittedImages.length, 1);
      expect(animatedCodec.numFramesAsked, 2);

      // The 2nd frame is decoded while nobody is listening, so it waits
      imageStream.removeListener(ImageStreamListener(listener));
      final waitingFrame = FakeFrameInfo(
        const Duration(milliseconds: 200),
        image200x100.clone(),
      );
      animatedCodec.completeNextFrame(waitingFrame);
      await tester.idle();
      await tester.pump();

      codecStream.add(staticCodec);
      await tester.idle();
      expect(staticCodec.numFramesAsked, 0);
      expect(waitingFrame.image.debugDisposed, true);

      imageStream.addListener(ImageStreamListener(listener));
      await tester.idle();
      expect(staticCodec.numFramesAsked, 1);

      final staticFrame = FakeFrameInfo(Duration.zero, image300x100);
      staticCodec.completeNextFrame(staticFrame);
      await tester.idle();
      await tester.pump(const Duration(milliseconds: 200));

      expect(emittedImages.length, 2);
      expect(emittedImages[1].image.isCloneOf(staticFrame.image), true);

      handle.dispose();
    },
  );

  testWidgets(
    'new codec arriving before a scheduled animated frame is shown does not throw',
    (WidgetTester tester) async {
      final animatedCodec = MockCodec();
      animatedCodec.frameCount = 2;
      animatedCodec.repetitionCount = -1;
      final staticCodec = MockCodec();
      final codecStream = StreamController<Codec>();

      final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
        codec: codecStream.stream,
        scale: 1.0,
      );

      final emittedImages = <ImageInfo>[];
      listener(ImageInfo image, bool synchronousCall) {
        emittedImages.add(image);
      }

      imageStream.addListener(ImageStreamListener(listener));

      codecStream.add(animatedCodec);
      await tester.idle();

      // The 1st frame is decoded and waits for the next app frame
      animatedCodec.completeNextFrame(
        FakeFrameInfo(const Duration(milliseconds: 200), image20x10),
      );
      await tester.idle();

      // A new codec arrives before that app frame
      codecStream.add(staticCodec);
      await tester.idle();
      expect(staticCodec.numFramesAsked, 1);

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(emittedImages, isEmpty);

      final staticFrame = FakeFrameInfo(Duration.zero, image200x100);
      staticCodec.completeNextFrame(staticFrame);
      await tester.idle();

      expect(emittedImages.single.image.isCloneOf(staticFrame.image), true);
    },
  );

  testWidgets('failed decode does not block later decodes', (
    WidgetTester tester,
  ) async {
    final mockCodec = MockCodec();
    final codecStream = StreamController<Codec>();

    final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
      codec: codecStream.stream,
      scale: 1.0,
    );

    final emittedImages = <ImageInfo>[];
    listener(ImageInfo image, bool synchronousCall) {
      emittedImages.add(image);
    }

    imageStream.addListener(ImageStreamListener(listener));
    final handle = imageStream.keepAlive();

    codecStream.add(mockCodec);
    await tester.idle();
    expect(mockCodec.numFramesAsked, 1);

    mockCodec.failNextFrame('frame completion error');
    await tester.idle();
    expect(tester.takeException(), 'frame completion error');
    expect(emittedImages, isEmpty);

    // A failed decode leaves no image, so the next listener decodes again
    imageStream.removeListener(ImageStreamListener(listener));
    imageStream.addListener(ImageStreamListener(listener));
    await tester.idle();
    expect(mockCodec.numFramesAsked, 2);

    final frame = FakeFrameInfo(Duration.zero, image20x10);
    mockCodec.completeNextFrame(frame);
    await tester.idle();

    expect(emittedImages.single.image.isCloneOf(frame.image), true);

    handle.dispose();
  });

  testWidgets(
    'frame from a codec replaced mid-decode is disposed, not emitted',
    (WidgetTester tester) async {
      final firstCodec = MockCodec();
      final secondCodec = MockCodec();
      final codecStream = StreamController<Codec>();

      final ImageStreamCompleter imageStream = MultiImageStreamCompleter(
        codec: codecStream.stream,
        scale: 1.0,
      );

      final emittedImages = <ImageInfo>[];
      listener(ImageInfo image, bool synchronousCall) {
        emittedImages.add(image);
      }

      imageStream.addListener(ImageStreamListener(listener));

      codecStream.add(firstCodec);
      await tester.idle();
      expect(firstCodec.numFramesAsked, 1);

      // The second codec arrives while the first one is still decoding
      codecStream.add(secondCodec);
      await tester.idle();
      expect(secondCodec.numFramesAsked, 1);

      final staleFrame = FakeFrameInfo(Duration.zero, image20x10.clone());
      firstCodec.completeNextFrame(staleFrame);
      await tester.idle();
      expect(emittedImages, isEmpty);
      expect(staleFrame.image.debugDisposed, true);

      final freshFrame = FakeFrameInfo(Duration.zero, image200x100);
      secondCodec.completeNextFrame(freshFrame);
      await tester.idle();

      expect(emittedImages.single.image.isCloneOf(freshFrame.image), true);
    },
  );
}
