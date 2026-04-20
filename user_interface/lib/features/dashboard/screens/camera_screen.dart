import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/mjpeg_view.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // Default to a placeholder or a local IP if known. 
  // In a real app, this should be stored in the device config or settings.
  final TextEditingController _urlController = TextEditingController(text: 'http://phytopi.local:8000/stream.mjpg');
  bool _isPlaying = false;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _currentUrl = _urlController.text;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_isPlaying) {
        _isPlaying = false;
      } else {
        _updateUrlWithTimestamp();
        _isPlaying = true;
      }
    });
  }

  void _updateUrlWithTimestamp() {
    final baseUrl = _urlController.text;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Append timestamp to force reload and bypass cache
    final separator = baseUrl.contains('?') ? '&' : '?';
    _currentUrl = '$baseUrl${separator}_t=$timestamp';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Camera',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Monitor your plant in real-time.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            
            // Camera Viewport
            Expanded(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_isPlaying)
                          MjpegView(
                            url: _currentUrl,
                            fit: BoxFit.contain,
                          )
                        else
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam_off, color: Colors.white.withOpacity(0.5), size: 64),
                                const SizedBox(height: 16),
                                Text(
                                  'Camera Paused',
                                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                                ),
                              ],
                            ),
                          ),
                          
                        // Overlay Controls
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: FloatingActionButton(
                            onPressed: _togglePlay,
                            backgroundColor: theme.primaryColor,
                            child: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Settings / URL Input
            Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stream Configuration', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            labelText: 'Stream URL',
                            hintText: 'http://<IP>:8000/stream.mjpg',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      FilledButton.tonal(
                        onPressed: _isPlaying ? null : () {
                          setState(() {
                            _updateUrlWithTimestamp();
                            _isPlaying = true;
                          });
                        },
                        child: const Text('Connect'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Note: For remote access (Vercel), ensure the camera URL is publicly accessible or use a tunnel (e.g., ngrok).',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

