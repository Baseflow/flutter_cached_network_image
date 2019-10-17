import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:mockito/mockito.dart';
import 'package:cached_network_image/src/cached_image_manager.dart';

class MockCacheManager extends Mock implements CacheManager {}

class MockFile extends Mock implements File {}

File mockFile(Uint8List bytes()) {
  var f = MockFile();
  when(f.readAsBytes()).thenAnswer((_) => Future.sync(bytes));
  when(f.readAsBytesSync()).thenReturn(bytes());
  return f;
}
