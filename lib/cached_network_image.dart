library cached_network_image;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';


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
      }): super(key: key);

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

  SharedPreferences prefs;
  Map<String, CacheObject> cacheData;
  static Object _lock = new Object();

  ///Shared preferences is used to keep track of the information about the files
  _init() async {
    prefs = await SharedPreferences.getInstance();

    //get saved cache data from shared prefs
    var jsonCacheString = prefs.getString("lib_cached_image_data");
    cacheData = new Map();
    if (jsonCacheString != null) {
      Map jsonCache = JSON.decode(jsonCacheString);
      jsonCache.forEach((key, data) {
        cacheData[key] = new CacheObject.fromMap(data);
      });
    }
  }

  ///Store all data to shared preferences
  _save() async {
    Map json = new Map();
    await synchronized(_lock, () {
      cacheData.forEach((key, cache) {
        json[key] = cache._map;
      });
    });
    prefs.setString("lib_cached_image_data", JSON.encode(json));
  }

  ///Get the file from the cache or online. Depending on availability and age
  Future<File> getFile(String url) async {
    if (!cacheData.containsKey(url)) {
      await synchronized(_lock, () {
        if (!cacheData.containsKey(url)) {
          cacheData[url] = new CacheObject();
        }
      });
    }

    var cacheObject = cacheData[url];
    await synchronized(cacheObject.lock, () async {
      //If we have never downloaded this file, do download
      if (cacheObject.filePath == null) {
        cacheData[url] = await downloadFile(url);
        return;
      }
      //If file is removed from the cache storage, download again
      var cachedFile = new File(cacheObject.filePath);
      var cachedFileExists = await cachedFile.exists();
      if (!cachedFileExists) {
        cacheData[url] = await downloadFile(url, path: cacheObject.filePath);
        return;
      }
      //If file is old, download if server has newer one
      if (cacheObject.validTill == null ||
          cacheObject.validTill.isBefore(new DateTime.now())) {
        var newCacheData = await downloadFile(url,
            path: cacheObject.filePath, eTag: cacheObject.eTag);
        if(newCacheData != null){
          cacheData[url] = newCacheData;
        }
        return;
      }
    });

    //If non of the above is true, than we don't have to download anything.
    _save();
    return new File(cacheData[url].filePath);
  }

  ///Download the file from the url
  Future<CacheObject> downloadFile(String url,
      {String path, String eTag}) async {
    var newCache = new CacheObject();
    newCache.setPath(path);
    var headers = new Map<String, String>();
    if (eTag != null) {
      headers["If-None-Match"] = eTag;
    }

    var response;
    try {
      response = await http.get(url, headers: headers);
    }catch(e){}
    if (response != null) {
      if (response.statusCode == 200) {
        await newCache.setDataFromHeaders(response.headers);
        var folder =  new File(newCache.filePath).parent;
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

  Object lock;
  Map _map;

  CacheObject() {
    _map = new Map();
    lock = new Object();
  }

  CacheObject.fromMap(Map map) {
    _map = map;
    lock = new Object();
  }

  Map toMap() {
    return _map;
  }

  setDataFromHeaders(Map<String, String> headers) async {
    if (headers.containsKey("cache-control")) {
      var cacheControl = headers["cache-control"];
      var controlSettings = cacheControl.split(", ");
      controlSettings.forEach((setting) {
        if (setting.startsWith("max-age=")) {
          var validSeconds =
          int.parse(setting.split("=")[1], onError: (source) => 0);
          if (validSeconds > 0) {
            _map["validTill"] = new DateTime.now()
                .add(new Duration(seconds: validSeconds))
                .millisecondsSinceEpoch;
          }
        }
      });
    }

    if (headers.containsKey("etag")) {
      _map["ETag"] = headers["etag"];
    }

    if (headers.containsKey("content-type")) {
      var type = headers["content-type"].split("/");
      if (type[0] == "image") {
        if (filePath == null || !filePath.endsWith(type[1])) {
          Directory directory = await getTemporaryDirectory();
          var folder = new Directory("${directory.path}/imagecache");
          if (!(await folder.exists())) {
            folder.createSync();
          }
          var fileName = "${new Uuid().v1()}.${type[1]}";
          _map["path"] = "${folder.path}/${fileName}";
        }
      }
    }
  }

  setPath(String path) {
    _map["path"] = path;
  }
}
