import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'CachedNetworkImage Demo',
      theme: new ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or press Run > Flutter Hot Reload in IntelliJ). Notice that the
        // counter didn't reset back to zero; the application is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: new MyHomePage(title: 'CachedNetworkImage'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  final String title;

  MyHomePage({this.title});

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: new Text(title),
      ),
      body: _testContent(),
    );
  }

  _testContent() {
    return new SingleChildScrollView(
      child: new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _sizedContainer(
              new Image(
                image: new CachedNetworkImageProvider(
                    "http://via.placeholder.com/350x150"),
              ),
            ),
            _sizedContainer(
              new Image(
                image: new CachedNetworkImageProvider(
                  "https://www.moejam.com/uploadfile/2014/0504/20140504012525197.jpg",
                  isDeleteSourceCached: true,
                  compressCallback: (_file) async {
                    final tempDir = await getTemporaryDirectory();
                    var paths = _file.absolute.path.split("/");
                    var resultName = paths[paths.length - 1];
                    File result = await FlutterImageCompress.compressAndGetFile(
                      _file.absolute.path,
                      tempDir.path + "/$resultName",
                      minWidth: 768,
                      minHeight: 1024,
                      quality: 88,
                    );
                    return result;
                  },
                ),
              ),
            ),
            _sizedContainer(
              new CachedNetworkImage(
                placeholder: (context, url) => new CircularProgressIndicator(),
                imageUrl: "http://via.placeholder.com/200x150",
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                imageUrl: "http://via.placeholder.com/300x150",
                imageBuilder: (context, imageProvider) => Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                        colorFilter:
                            ColorFilter.mode(Colors.red, BlendMode.colorBurn)),
                  ),
                ),
                placeholder: (context, url) => CircularProgressIndicator(),
                errorWidget: (context, url, error) => Icon(Icons.error),
              ),
            ),
            _sizedContainer(
              new CachedNetworkImage(
                imageUrl: "http://notAvalid.uri",
                placeholder: (context, url) => new CircularProgressIndicator(),
                errorWidget: (context, url, error) => new Icon(Icons.error),
              ),
            ),
            _sizedContainer(
              new CachedNetworkImage(
                imageUrl: "not a uri at all",
                placeholder: (context, url) => new CircularProgressIndicator(),
                errorWidget: (context, url, error) => new Icon(Icons.error),
              ),
            ),
            _sizedContainer(
              new CachedNetworkImage(
                imageUrl: "http://via.placeholder.com/350x200",
                placeholder: (context, url) => new CircularProgressIndicator(),
                errorWidget: (context, url, error) => new Icon(Icons.error),
                fadeOutDuration: new Duration(seconds: 1),
                fadeInDuration: new Duration(seconds: 3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _gridView() {
    return new GridView.builder(
        itemCount: 250,
        gridDelegate:
            new SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
        itemBuilder: (BuildContext context, int index) {
          return new CachedNetworkImage(
            imageUrl:
                "http://via.placeholder.com/${(index + 1)}x${(index % 100 + 1)}",
            placeholder: _loader,
            errorWidget: _error,
          );
        });
  }

  Widget _loader(BuildContext context, String url) {
    return new Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _error(BuildContext context, String url, Exception error) {
    print(error);
    return new Center(
      child: Icon(Icons.error),
    );
  }

  Widget _sizedContainer(Widget child) {
    return new SizedBox(
      width: 300.0,
      height: 150.0,
      child: new Center(
        child: child,
      ),
    );
  }
}
