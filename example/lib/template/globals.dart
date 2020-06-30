import 'dart:core';

import 'package:example/plugin_example/basic_content.dart';
import 'package:example/plugin_example/grid_content.dart';
import 'package:example/plugin_example/list_content.dart';
import 'package:flutter/material.dart';

import 'info_page.dart';

class Globals {
  static const String pluginName = 'CachedNetworkImage';
  static const String githubURL =
      'https://github.com/Baseflow/flutter_cached_network_image/';
  static const String baseflowURL = 'https://baseflow.com';
  static const String pubDevURL =
      'https://pub.dev/packages/cached_network_image';

  static const EdgeInsets defaultHorizontalPadding =
      EdgeInsets.symmetric(horizontal: 24);
  static const EdgeInsets defaultVerticalPadding =
      EdgeInsets.symmetric(vertical: 24);

  static final icons = [
    Icons.image,
    Icons.list,
    Icons.grid_on,
    Icons.info_outline,
  ];

  static final pages = [
    BasicContent(),
    ListContent(),
    GridContent(),
    InfoPage(),
  ];
}
