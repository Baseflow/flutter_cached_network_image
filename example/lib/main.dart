import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'CachedNetworkImage Demo',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: MyHomePage(),
      );
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int currentPage = 0;

  @override
  Widget build(BuildContext context) {
    Widget content;
    return Scaffold(
      appBar: AppBar(title: Text('CachedNetworkImage')),
      body: _content(currentPage),
      bottomNavigationBar: BottomNavigationBar(
        onTap: (value) => setState(() {
          currentPage = value;
        }),
        currentIndex: currentPage,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.image),
            title: Text('Basic'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            title: Text('ListView'),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_on),
            title: Text('GridView'),
          ),
        ],
      ),
    );
  }

  _content(int page) {
    switch (currentPage) {
      case 0:
        return _basicContent();
      case 1:
        return _listViewContent();
      case 2:
        return _gridView();
    }
  }

  _basicContent() {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _sizedContainer(
              Image(
                image: CachedNetworkImageProvider(
                  'http://via.placeholder.com/350x150',
                ),
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                placeholder: (context, url) => CircularProgressIndicator(),
                imageUrl: 'http://via.placeholder.com/200x150',
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                imageUrl: 'http://via.placeholder.com/300x150',
                imageBuilder: (context, imageProvider) => Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.red,
                        BlendMode.colorBurn,
                      ),
                    ),
                  ),
                ),
                placeholder: (context, url) => CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
            CachedNetworkImage(
              imageUrl: 'http://via.placeholder.com/300x300',
              placeholder: (context, url) => CircleAvatar(
                backgroundColor: Colors.amber,
                radius: 150,
              ),
              imageBuilder: (context, image) => CircleAvatar(
                backgroundImage: image,
                radius: 150,
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                imageUrl: 'http://notAvalid.uri',
                placeholder: (context, url) => CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                imageUrl: 'not a uri at all',
                placeholder: (context, url) => CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
            _sizedContainer(
              CachedNetworkImage(
                imageUrl: 'http://via.placeholder.com/350x200',
                placeholder: (context, url) => CircularProgressIndicator(),
                errorWidget: (context, url, error) => const Icon(Icons.error),
                fadeOutDuration: const Duration(seconds: 1),
                fadeInDuration: const Duration(seconds: 3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _listViewContent() {
    return ListView.builder(
      itemBuilder: (BuildContext context, int index) => Card(
        child: Column(
          children: <Widget>[
            CachedNetworkImage(
              imageUrl: 'https://loremflickr.com/320/240/music?lock=$index',
              placeholder: (BuildContext context, String url) => Container(
                width: 320,
                height: 240,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ),
      itemCount: 250,
    );
  }

  _gridView() {
    return GridView.builder(
      itemCount: 250,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
      itemBuilder: (BuildContext context, int index) => CachedNetworkImage(
        imageUrl: 'https://loremflickr.com/100/100/music?lock=$index',
        placeholder: _loader,
        errorWidget: _error,
      ),
    );
  }

  Widget _loader(BuildContext context, String url) => Center(
        child: CircularProgressIndicator(),
      );

  Widget _error(BuildContext context, String url, dynamic error) {
    return Center(child: const Icon(Icons.error));
  }

  Widget _sizedContainer(Widget child) => SizedBox(
        width: 300.0,
        height: 150.0,
        child: Center(child: child),
      );
}
