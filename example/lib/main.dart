import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      body:
      new SingleChildScrollView(child:
      new Center(
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[

            _sizedContainer(
              new Image(
                image: new CachedNetworkImageProvider("http://via.placeholder.com/350x150"),
              ),
            ),

            _sizedContainer(
              new CachedNetworkImage(
                imageUrl: "http://via.placeholder.com/200x150",
              ),
            ),

            _sizedContainer(
              new CachedNetworkImage(
                imageUrl: "not a valid uri",
                placeholder: new CircularProgressIndicator(),
                errorWidget: new Icon(Icons.error),
              ),
            ),

            _sizedContainer(
              new CachedNetworkImage(
                imageUrl: "http://via.placeholder.com/350x200",
                placeholder: new CircularProgressIndicator(),
                errorWidget: new Icon(Icons.error),
                fadeOutDuration: new Duration(seconds: 1),
                fadeInDuration: new Duration(seconds: 3),
              ),
            ),

          ],
        ),
      ),
      ),
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
