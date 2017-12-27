library cached_network_image;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';
import 'dart:ui' as ui show Image, decodeImageFromList;

/**
 *  CachedNetworkImage for Flutter
 *
 *  Copyright (c) 2017 Rene Floor
 *
 *  Released under MIT License.
 */

class CachedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget placeholder;

  /// Image is downloaded from the url
  /// Placeholder is shown while the image is being downloaded
  CachedNetworkImage(
    this.imageUrl, {
    Key key,
    this.fit,
    this.placeholder,
  })
      : super(key: key);

  @override
  _CachedNetworkImageState createState() => new _CachedNetworkImageState();
}

class _CachedNetworkImageState extends State<CachedNetworkImage> {
  File file;

  @override
  initState() {
    super.initState();
    _getImageFile();
  }

  @override
  Widget build(BuildContext context) {
    if (file == null) {
      return widget.placeholder ?? new Container();
    } else {
      return new Image.file(
        file,
        fit: widget.fit,
      );
    }
  }

  _getImageFile() async {
    var cacheManager = await CacheManager.getInstance();
    var f = await cacheManager.getFile(widget.imageUrl);
    setState(() => file = f);
  }
}

class CacheManager {
  static Duration inbetweenCleans = new Duration(days: 7);
  static Duration maxAgeCacheObject = new Duration(days: 30);
  static int maxNrOfCacheObjects = 200;

  static CacheManager _instance;
  static Future<CacheManager> getInstance() async {
    if (_instance == null) {
      await synchronized(_lock, () async {
        if (_instance == null) {
          _instance = new CacheManager._();
          await _instance._init();
        }
      });
    }
    return _instance;
  }

  CacheManager._();

  SharedPreferences _prefs;
  Map<String, CacheObject> _cacheData;
  DateTime lastCacheClean;

  static Object _lock = new Object();

  ///Shared preferences is used to keep track of the information about the files
  _init() async {
    _prefs = await SharedPreferences.getInstance();

    //get saved cache data from shared prefs
    var jsonCacheString = _prefs.getString("lib_cached_image_data");
    _cacheData = new Map();
    if (jsonCacheString != null) {
      Map jsonCache = JSON.decode(jsonCacheString);
      jsonCache.forEach((key, data) {
        _cacheData[key] = new CacheObject.fromMap(key, data);
      });
    }

    // Get data about when the last clean action has been performed
    var cleanMillis = _prefs.getInt("lib_cached_image_data_last_clean");
    if (cleanMillis != null) {
      lastCacheClean = new DateTime.fromMillisecondsSinceEpoch(cleanMillis);
    } else {
      lastCacheClean = new DateTime.now();
      _prefs.setInt("lib_cached_image_data_last_clean",
          lastCacheClean.millisecondsSinceEpoch);
    }
  }

  bool _isStoringData = false;
  bool _shouldStoreDataAgain = false;
  Object _storeLock = new Object();
  ///Store all data to shared preferences
  _save() async {

    if(!(await _canSave())){
      return;
    }

    await synchronized(_lock, () async {
      await _cleanCache();
      await _saveDataInPrefs();
    });
  }

  Future<bool> _canSave() async {
    return await synchronized(_storeLock, (){
      if(_isStoringData){
        _shouldStoreDataAgain = true;
        return false;
      }
      _isStoringData = true;
      return true;
    });
  }

  Future<bool> _shouldSaveAgain() async{
    return await synchronized(_storeLock, (){
      if(_shouldStoreDataAgain){
        _shouldStoreDataAgain = false;
        return true;
      }
      _isStoringData = false;
      return false;
    });
  }

  _saveDataInPrefs() async{
    Map json = new Map();
    _cacheData.forEach((key, cache) {
      json[key] = cache._map;
    });
    _prefs.setString("lib_cached_image_data", JSON.encode(json));

    if(await _shouldSaveAgain()){
      await _saveDataInPrefs();
    }
  }

  _cleanCache({force: false}) async {
    var sinceLastClean = new DateTime.now().difference(lastCacheClean);

    if (force ||
        sinceLastClean > inbetweenCleans ||
        _cacheData.length > maxNrOfCacheObjects) {
      var oldestDateAllowed = new DateTime.now().subtract(maxAgeCacheObject);

      //Remove old objects
      var oldValues =
          _cacheData.values.where((c) => c.touched.isBefore(oldestDateAllowed));
      for (var oldValue in oldValues) {
        await _removeFile(oldValue);
      }

      //Remove oldest objects when cache contains to many items
      if (_cacheData.length > maxNrOfCacheObjects) {
        var allValues = _cacheData.values.toList();
        allValues.sort((c1, c2) => c1.touched.compareTo(c2.touched));
        for (var i = allValues.length; i > maxNrOfCacheObjects; i--) {
          var lastItem = allValues[i - 1];
          await _removeFile(lastItem);
        }
      }

      lastCacheClean = new DateTime.now();
      _prefs.setInt("lib_cached_image_data_last_clean",
          lastCacheClean.millisecondsSinceEpoch);
    }
  }

  _removeFile(CacheObject cacheObject) async {
    var file = new File(cacheObject.filePath);
    if (await file.exists()) {
      file.delete();
    }
    _cacheData.remove(cacheObject.url);
  }

  ///Get the file from the cache or online. Depending on availability and age
  Future<File> getFile(String url) async {
    if (!_cacheData.containsKey(url)) {
      await synchronized(_lock, () {
        if (!_cacheData.containsKey(url)) {
          _cacheData[url] = new CacheObject(url);
        }
      });
    }

    var cacheObject = _cacheData[url];
    await synchronized(cacheObject.lock, () async {
      // Set touched date to show that this object is being used recently
      cacheObject.touch();

      //If we have never downloaded this file, do download
      if (cacheObject.filePath == null) {
        _cacheData[url] = await downloadFile(url);
        return;
      }
      //If file is removed from the cache storage, download again
      var cachedFile = new File(cacheObject.filePath);
      var cachedFileExists = await cachedFile.exists();
      if (!cachedFileExists) {
        _cacheData[url] = await downloadFile(url, path: cacheObject.filePath);
        return;
      }
      //If file is old, download if server has newer one
      if (cacheObject.validTill == null ||
          cacheObject.validTill.isBefore(new DateTime.now())) {
        var newCacheData = await downloadFile(url,
            path: cacheObject.filePath, eTag: cacheObject.eTag);
        if (newCacheData != null) {
          _cacheData[url] = newCacheData;
        }
        return;
      }
    });

    //If non of the above is true, than we don't have to download anything.
    _save();
    return new File(_cacheData[url].filePath);
  }

  ///Download the file from the url
  Future<CacheObject> downloadFile(String url,
      {String path, String eTag}) async {
    var newCache = new CacheObject(url);
    newCache.setPath(path);
    var headers = new Map<String, String>();
    if (eTag != null) {
      headers["If-None-Match"] = eTag;
    }

    var response;
    try {
      response = await http.get(url, headers: headers);
    } catch (e) {}
    if (response != null) {
      if (response.statusCode == 200) {
        await newCache.setDataFromHeaders(response.headers);
        var folder = new File(newCache.filePath).parent;
        if (!(await folder.exists())) {
          folder.createSync(recursive: true);
        }
        await new File(newCache.filePath).writeAsBytes(response.bodyBytes);

        return newCache;
      }
      if (response.statusCode == 304) {
        newCache.setDataFromHeaders(response.headers);
        return newCache;
      }
    }

    return null;
  }
}

///Cache information of one file
class CacheObject {
  String get filePath {
    if (_map.containsKey("path")) {
      return _map["path"];
    }
    return null;
  }

  DateTime get validTill {
    if (_map.containsKey("validTill")) {
      return new DateTime.fromMillisecondsSinceEpoch(_map["validTill"]);
    }
    return null;
  }

  String get eTag {
    if (_map.containsKey("ETag")) {
      return _map["ETag"];
    }
    return null;
  }

  DateTime touched;
  String url;

  Object lock;
  Map _map;

  CacheObject(String url) {
    this.url = url;
    _map = new Map();
    touch();
    lock = new Object();
  }

  CacheObject.fromMap(String url, Map map) {
    this.url = url;
    _map = map;

    if (_map.containsKey("touched")) {
      touched = new DateTime.fromMillisecondsSinceEpoch(_map["touched"]);
    } else {
      touch();
    }

    lock = new Object();
  }

  Map toMap() {
    return _map;
  }

  touch() {
    touched = new DateTime.now();
    _map["touched"] = touched.millisecondsSinceEpoch;
  }

  setDataFromHeaders(Map<String, String> headers) async {
    //Without a cache-control header we keep the file for a week
    var ageDuration = new Duration(days: 7);

    if (headers.containsKey("cache-control")) {
      var cacheControl = headers["cache-control"];
      var controlSettings = cacheControl.split(", ");
      controlSettings.forEach((setting) {
        if (setting.startsWith("max-age=")) {
          var validSeconds =
              int.parse(setting.split("=")[1], onError: (source) => 0);
          if (validSeconds > 0) {
            ageDuration = new Duration(seconds: validSeconds);
          }
        }
      });
    }

    _map["validTill"] =
        new DateTime.now().add(ageDuration).millisecondsSinceEpoch;

    if (headers.containsKey("etag")) {
      _map["ETag"] = headers["etag"];
    }

    var fileExtension = "";
    if (headers.containsKey("content-type")) {
      var type = headers["content-type"].split("/");
      if (type.length == 2) {
        fileExtension = ".${type[1]}";
      }
    }

    if(filePath != null && !filePath.endsWith(fileExtension)){
      removeOldFile(filePath);
      _map["path"] = null;
    }

    if(filePath == null){
      Directory directory = await getTemporaryDirectory();
      var folder = new Directory("${directory.path}/cache");
      if (!(await folder.exists())) {
      folder.createSync();
      }
      var fileName = "${new Uuid().v1()}${fileExtension}";
      _map["path"] = "${folder.path}/${fileName}";
    }
  }

  removeOldFile(String filePath) async{
    var file = new File(filePath);
    if(await file.exists()){
      await file.delete();
    }
  }

  setPath(String path) {
    _map["path"] = path;
  }
}

class CachedNetworkImageProvider
    extends ImageProvider<CachedNetworkImageProvider> {
  const CachedNetworkImageProvider(this.url, {this.scale: 1.0})
      : assert(url != null),
        assert(scale != null);

  final String url;

  final double scale;

  @override
  Future<CachedNetworkImageProvider> obtainKey(
      ImageConfiguration configuration) {
    return new SynchronousFuture<CachedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter load(CachedNetworkImageProvider key) {
    return new OneFrameImageStreamCompleter(_loadAsync(key),
        informationCollector: (StringBuffer information) {
      information.writeln('Image provider: $this');
      information.write('Image key: $key');
    });
  }

  Future<ImageInfo> _loadAsync(CachedNetworkImageProvider key) async {
    var cacheManager = await CacheManager.getInstance();
    var file = await cacheManager.getFile(url);
    return _loadAsyncFromFile(key, file);
  }

  Future<ImageInfo> _loadAsyncFromFile(
      CachedNetworkImageProvider key, File file) async {
    assert(key == this);

    final Uint8List bytes = await file.readAsBytes();
    if (bytes.lengthInBytes == 0) return null;

    final ui.Image image = await decodeImageFromList(bytes);
    if (image == null) return null;

    return new ImageInfo(
      image: image,
      scale: key.scale,
    );
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final CachedNetworkImageProvider typedOther = other;
    return url == typedOther.url && scale == typedOther.scale;
  }

  @override
  int get hashCode => hashValues(url, scale);

  @override
  String toString() => '$runtimeType("$url", scale: $scale)';
}
