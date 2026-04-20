import 'dart:async';
import 'dart:io';

/// Starts a local HTTP server that listens for the OAuth redirect (e.g. from Google sign-in).
/// Used on desktop (Linux/Windows/macOS) where the browser redirects to localhost after login.
///
/// Returns a [Future<Uri>] that completes with the full callback URI (including query params
/// like `code=...` for PKCE) when the redirect is received. The server is closed automatically.
///
/// Add `http://127.0.0.1:<port>/callback` to:
/// - Supabase Dashboard → Authentication → URL Configuration → Redirect URLs
/// - Google Cloud Console → OAuth 2.0 → Authorized redirect URIs
Future<Uri> startOAuthCallbackServer(int port) async {
  final completer = Completer<Uri>();
  HttpServer? server;

  void completeWith(Uri uri) {
    if (!completer.isCompleted) {
      completer.complete(uri);
    }
    server?.close(force: true);
  }

  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  } on SocketException catch (e) {
    throw OAuthCallbackServerException(
      'Could not bind to 127.0.0.1:$port. Is another app using it? ${e.message}',
    );
  }

  server.listen((HttpRequest request) {
    // Build full callback URI (getSessionFromUrl expects a full URL; request.uri is path+query only)
    final pathAndQuery = request.uri.toString();
    final uri = Uri.parse('http://127.0.0.1:$port$pathAndQuery');
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write('''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Sign in</title></head>
<body style="font-family:sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;">
  <p style="color:#2E7D32;">✓ Sign-in successful. You can close this window and return to the app.</p>
</body>
</html>''')
      ..close();

    completeWith(uri);
  });

  // Timeout so we don't hang forever if user never completes login
  return completer.future.timeout(
    const Duration(minutes: 5),
    onTimeout: () {
      server?.close(force: true);
      throw TimeoutException(
        'OAuth sign-in timed out. Please try again.',
        const Duration(minutes: 5),
      );
    },
  );
}

class OAuthCallbackServerException implements Exception {
  final String message;
  OAuthCallbackServerException(this.message);
  @override
  String toString() => 'OAuthCallbackServerException: $message';
}
