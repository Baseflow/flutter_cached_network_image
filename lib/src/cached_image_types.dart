import 'package:flutter/material.dart';

typedef Widget ImageWidgetBuilder(
    BuildContext context, ImageProvider imageProvider);
typedef Widget PlaceholderWidgetBuilder(BuildContext context, String url);
typedef Widget LoadingErrorWidgetBuilder(
    BuildContext context, String url, Object error);

