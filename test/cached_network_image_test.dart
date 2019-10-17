import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'mock_cached_image_manager.dart';

void main() {
  group("$CachedNetworkImage", () {
    var cacheManager = MockCacheManager();
    when(cacheManager.getImage("https://test/1.png")).thenAnswer((_) async* {
      await Future.delayed(Duration(milliseconds: 100));
      yield CachedImage(
          "https://test/1.png",
          DateTime.now(),
          mockFile(
            () => base64.decode(
                'UklGRjYAAABXRUJQVlA4ICoAAAAQAgCdASoBAAEAAYcIhYWIhYSIiIIADA1gAAQAAAEAAAEAAP74h4AAAAA='),
          ));
    });
    when(cacheManager.getImage("https://test/error")).thenAnswer((_) async* {
      await Future.delayed(Duration(milliseconds: 100));
      throw Exception("error");
    });
    testWidgets('test placeholder', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CachedNetworkImage(
            imageUrl: "https://test/1.png",
            cacheManager: cacheManager,
            fadeInDuration: Duration.zero,
            placeholder: (_, __) => Text("Placeholder"),
          ),
        ),
      ));
      expect(find.byType(CachedNetworkImage), findsOneWidget);
      expect(find.text("Placeholder"), findsOneWidget, reason: "Placeholder");
      await tester.pump(Duration(milliseconds: 10));
      expect(find.text("Placeholder"), findsOneWidget, reason: "Loading");
      await tester.pump(Duration(milliseconds: 100));
      expect(find.byType(Image), findsOneWidget, reason: "Loaded");
    });
    testWidgets('test error', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CachedNetworkImage(
            imageUrl: "https://test/error",
            cacheManager: cacheManager,
            errorWidget: (_, __, ___) => Text("Loading Error"),
          ),
        ),
      ));
      expect(find.byType(CachedNetworkImage), findsOneWidget);
      await tester.pump(Duration(milliseconds: 100));
      expect(find.text("Loading Error"), findsOneWidget, reason: "failed");
    });
  });
}
