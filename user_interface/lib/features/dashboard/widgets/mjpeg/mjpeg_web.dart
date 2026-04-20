import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget buildMjpegView(String url, BoxFit fit) {
  // Unique ID for this view based on URL to allow multiple cameras if needed
  // but unique enough to re-register if URL changes? 
  // Ideally we register a factory for a type, and pass params, but for simple usage:
  final String viewId = 'mjpeg-view-${url.hashCode}';

  // Register the view factory
  // Note: In production code, we should only register once per viewId.
  // platformViewRegistry is idempotent for same viewId usually, but let's be safe.
  
  // Using ignore for undefined_prefixed_name because platformViewRegistry is not in standard dart:ui
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
    final element = html.ImageElement()
      ..src = url
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = _getObjectFit(fit)
      ..style.border = 'none'; // Remove border
      
    return element;
  });

  return HtmlElementView(viewType: viewId);
}

String _getObjectFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.contain: return 'contain';
    case BoxFit.cover: return 'cover';
    case BoxFit.fill: return 'fill';
    case BoxFit.fitHeight: return 'contain';
    case BoxFit.fitWidth: return 'contain';
    case BoxFit.none: return 'none';
    case BoxFit.scaleDown: return 'scale-down';
  }
}

