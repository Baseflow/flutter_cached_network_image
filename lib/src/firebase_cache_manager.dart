import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

//FirebaseCacheManager maintains all default values of BaseCacheManager
//and only changes the fileService.
class FirebaseCacheManager extends BaseCacheManager {
  static const key = 'firebaseCache';

  static FirebaseCacheManager _instance;

  factory FirebaseCacheManager() {
    _instance ??= FirebaseCacheManager._();
    return _instance;
  }

  FirebaseCacheManager._() : super(key, fileService: FirebaseHttpFileService());

  @override
  Future<String> getFilePath() async {
    var directory = await getTemporaryDirectory();
    return p.join(directory.path, key);
  }
}

//FirebaseHttpFileService is needed to convert the Firebase Storage path,
//to standard url which can be passed to a http request helper.
class FirebaseHttpFileService extends HttpFileService {
  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String> headers = const {}}) async {
    var ref = FirebaseStorage.instance.ref().child(url);
    var _url = await ref.getDownloadURL() as String;

    return super.get(_url);
  }
}
