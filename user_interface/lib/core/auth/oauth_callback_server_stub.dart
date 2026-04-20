// Stub for web - OAuth callback server is only used on desktop (Linux/Windows/macOS).

/// Callers should not use this on web; use deep link or site URL instead.
Future<Uri> startOAuthCallbackServer(int port) {
  throw UnsupportedError(
    'OAuth callback server is only supported on desktop (Linux/Windows/macOS). '
    'On web, OAuth redirects to the site URL.',
  );
}
