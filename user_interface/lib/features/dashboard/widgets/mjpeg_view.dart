import 'package:flutter/material.dart';

// Conditional import
import 'mjpeg/mjpeg_mobile.dart' if (dart.library.html) 'mjpeg/mjpeg_web.dart';

class MjpegView extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const MjpegView({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return buildMjpegView(url, fit);
  }
}

