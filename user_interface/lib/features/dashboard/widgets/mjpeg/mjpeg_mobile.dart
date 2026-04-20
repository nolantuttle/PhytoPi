import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

Widget buildMjpegView(String url, BoxFit fit) {
  return _MjpegNativeView(url: url, fit: fit);
}

class _MjpegNativeView extends StatefulWidget {
  final String url;
  final BoxFit fit;

  const _MjpegNativeView({required this.url, required this.fit});

  @override
  State<_MjpegNativeView> createState() => _MjpegNativeViewState();
}

class _MjpegNativeViewState extends State<_MjpegNativeView> {
  Uint8List? _frame;
  bool _error = false;
  StreamSubscription<List<int>>? _sub;
  http.Client? _client;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(_MjpegNativeView old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _disconnect();
      _connect();
    }
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  void _disconnect() {
    _sub?.cancel();
    _sub = null;
    _client?.close();
    _client = null;
  }

  void _connect() {
    if (!mounted) return;
    setState(() {
      _frame = null;
      _error = false;
    });

    final client = http.Client();
    _client = client;

    final request = http.Request('GET', Uri.parse(widget.url));
    client.send(request).then((response) {
      if (!mounted) {
        client.close();
        return;
      }

      // Accumulate raw bytes; extract JPEG frames by magic bytes.
      // JPEG start: 0xFF 0xD8  |  JPEG end: 0xFF 0xD9
      final buffer = <int>[];

      _sub = response.stream.listen(
        (chunk) {
          buffer.addAll(chunk);

          // Extract every complete JPEG frame that has arrived.
          while (true) {
            final start = _indexOf(buffer, 0xFF, 0xD8);
            if (start == -1) {
              if (buffer.length > 1) buffer.removeRange(0, buffer.length - 1);
              break;
            }
            final end = _indexOf(buffer, 0xFF, 0xD9, start + 2);
            if (end == -1) {
              // Incomplete frame — keep only from the JPEG start.
              if (start > 0) buffer.removeRange(0, start);
              break;
            }

            final jpeg = Uint8List.fromList(buffer.sublist(start, end + 2));
            buffer.removeRange(0, end + 2);

            if (mounted) setState(() => _frame = jpeg);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _error = true);
        },
        onDone: () {
          if (mounted) setState(() => _error = true);
        },
      );
    }).catchError((_) {
      if (mounted) setState(() => _error = true);
    });
  }

  /// Returns the index of the first occurrence of [b0, b1] in [data]
  /// starting at [from], or -1 if not found.
  int _indexOf(List<int> data, int b0, int b1, [int from = 0]) {
    final limit = data.length - 1;
    for (int i = from; i < limit; i++) {
      if (data[i] == b0 && data[i + 1] == b1) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              'Stream Error',
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 8),
            Text(
              'Ensure URL is reachable',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_frame == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    return Image.memory(
      _frame!,
      fit: widget.fit,
      gaplessPlayback: true,
    );
  }
}
