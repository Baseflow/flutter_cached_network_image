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

class MyHomePage extends StatefulWidget {
  final String title;

  MyHomePage({this.title});

  @override
  State<StatefulWidget> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHomePage> {
  var url = "not a valid uri";

  bool show = true;
  ScrollController controller;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    controller = ScrollController()
      ..addListener(() {
        setState(() {
          show = controller.position.activity.velocity == 0;
        });
      });
  }

  @override
  void didUpdateWidget(MyHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: new Text(widget.title),
        actions: <Widget>[
          IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  url = "http://via.placeholder.com/350x200";
                });
              }),
        ],
      ),
      body: _buildGrid(),
    );
  }

  Widget _sizedContainer(Widget child) {
    return new SizedBox(
      width: 300.0,
      height: 600.0,
      child: new Center(
        child: child,
      ),
    );
  }

  Widget _buildGrid() => GridView.builder(
    itemCount: 50,
//        controller: controller,
        gridDelegate:
            SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
        itemBuilder: (_, _i) => Container(
              child: CachedNetworkImage(
                placeholder: CircularProgressIndicator(),
                scrollController: controller,
                imageUrl: _i.isEven
                    ? "http://via.placeholder.com/200x150"
                    : "http://via.placeholder.com/350x200",
              ),
              decoration: BoxDecoration(color: Colors.black),
            ),
      );
}
