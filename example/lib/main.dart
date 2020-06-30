import 'package:example/template/globals.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

void main() {
  runApp(BaseflowPluginExample());
}

class BaseflowPluginExample extends StatelessWidget {
  final MaterialColor themeMaterialColor =
      createMaterialColor(const Color.fromRGBO(48, 49, 60, 1));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baseflow ${Globals.pluginName}',
      theme: ThemeData(
        accentColor: Colors.white60,
        backgroundColor: const Color.fromRGBO(48, 49, 60, 0.8),
        buttonTheme: ButtonThemeData(
          buttonColor: themeMaterialColor.shade500,
          disabledColor: themeMaterialColor.withRed(200),
          splashColor: themeMaterialColor.shade50,
          textTheme: ButtonTextTheme.primary,
        ),
        bottomAppBarColor: const Color.fromRGBO(57, 58, 71, 1),
        hintColor: themeMaterialColor.shade500,
        primarySwatch: createMaterialColor(const Color.fromRGBO(48, 49, 60, 1)),
        textTheme: TextTheme(
          bodyText1: TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.3,
          ),
          bodyText2: TextStyle(
            color: Colors.white,
            fontSize: 18,
            height: 1.2,
          ),
          button: TextStyle(color: Colors.white),
          headline1: TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        inputDecorationTheme: const InputDecorationTheme(
          fillColor: Color.fromRGBO(37, 37, 37, 1),
          filled: true,
        ),
      ),
      home: MyHomePage(title: 'Baseflow ${Globals.pluginName} example app'),
    );
  }

  static MaterialColor createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map swatch = <int, Color>{};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    strengths.forEach((strength) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    });
    return MaterialColor(color.value, swatch);
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static final PageController _pageController = PageController(initialPage: 0);
  int currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).bottomAppBarColor,
        title: Center(
          child: Image.asset(
            'res/images/baseflow_logo_def_light-02.png',
            width: 140,
          ),
        ),
      ),
      backgroundColor: Theme.of(context).backgroundColor,
      body: PageView(
        controller: _pageController,
        children: Globals.pages,
        onPageChanged: (page) {
          setState(() {
            currentPage = page;
          });
        },
      ),
      bottomNavigationBar: _bottomAppBar(),
    );
  }

  BottomAppBar _bottomAppBar() {
    return BottomAppBar(
      elevation: 5,
      color: Theme.of(context).bottomAppBarColor,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.unmodifiable(() sync* {
          for (int i = 0; i < Globals.pages.length; i++) {
            yield Expanded(
              child: IconButton(
                iconSize: 30,
                icon: Icon(Globals.icons.elementAt(i)),
                color: _bottomAppBarIconColor(i),
                onPressed: () => _animateToPage(i),
              ),
            );
          }
        }()),
      ),
    );
  }

  void _animateToPage(int page) {
    _pageController.animateToPage(page,
        duration: const Duration(milliseconds: 200), curve: Curves.linear);
  }

  Color _bottomAppBarIconColor(int page) {
    return currentPage == page ? Colors.white : Theme.of(context).accentColor;
  }
}
