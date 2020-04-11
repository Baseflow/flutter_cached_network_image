import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

///
/// This cache manager just allows us to provide a different cache directory.
///
class SampleCacheManager extends BaseCacheManager {
  static const key = 'libCachedImageData';

  static SampleCacheManager _instance;

  factory SampleCacheManager() {
    _instance ??= SampleCacheManager._();
    return _instance;
  }

  SampleCacheManager._() : super(key);

  @override
  Future<String> getFilePath() async {
    var directory = await getExternalCacheDirectories();
    return  p.join(directory[0].path, key);
  }
}