import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/auth/oauth_callback_server_stub.dart' if (dart.library.io) '../../../core/auth/oauth_callback_server_io.dart' as oauth_server;

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() {
    if (!SupabaseConfig.isInitialized) {
      debugPrint('AuthProvider: Supabase not initialized - running in demo mode');
      _user = null;
      return;
    }
    
    try {
      // Restore existing session if available
      final session = SupabaseConfig.client?.auth.currentSession;
      _user = session?.user;
      debugPrint('AuthProvider: Initial user state: ${_user?.email}');
      
      // Listen to auth state changes
      SupabaseConfig.client?.auth.onAuthStateChange.listen((data) {
        debugPrint('AuthProvider: Auth state change: ${data.event}');
        _user = data.session?.user;
        notifyListeners();
      });
    } catch (e) {
      // Supabase not initialized, app running in demo mode
      debugPrint('AuthProvider: Error setting up auth listener - $e');
      _user = null;
    }
  }

  Future<void> signIn(String email, String password) async {
    if (!SupabaseConfig.isInitialized) {
      _error = 'Supabase is not configured';
      notifyListeners();
      return;
    }
    
    try {
      debugPrint('AuthProvider: Starting sign in for $email');
      _isLoading = true;
      _error = null;
      notifyListeners();

      await SupabaseConfig.client?.auth.signInWithPassword(
        email: email,
        password: password,
      );
      debugPrint('AuthProvider: Sign in successful');
    } catch (e) {
      debugPrint('AuthProvider: Sign in error: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password) async {
    if (!SupabaseConfig.isInitialized) {
      _error = 'Supabase is not configured';
      notifyListeners();
      return;
    }
    
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await SupabaseConfig.client?.auth.signUp(
        email: email,
        password: password,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Port and URL for desktop OAuth callback. Add this URL to:
  /// - Supabase Dashboard → Authentication → URL Configuration → Redirect URLs
  /// - Google Cloud Console → OAuth 2.0 Client → Authorized redirect URIs
  static const int _oauthCallbackPort = 43828;
  static const String _oauthCallbackUrl = 'http://127.0.0.1:$_oauthCallbackPort/callback';

  Future<void> signInWithOAuth(OAuthProvider provider) async {
    if (!SupabaseConfig.isInitialized) {
      _error = 'Supabase is not configured';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (kIsWeb) {
        await SupabaseConfig.client?.auth.signInWithOAuth(
          provider,
          redirectTo: null,
        );
        return;
      }

      // Mobile: deep link brings user back to the app
      if (PlatformDetector.isMobile) {
        await SupabaseConfig.client?.auth.signInWithOAuth(
          provider,
          redirectTo: 'com.example.phytopidashboard://login-callback',
        );
        return;
      }

      // Desktop (Linux/Windows/macOS) including kiosk: localhost callback server
      // Start server first so it is ready when the browser redirects after login
      final callbackFuture = oauth_server.startOAuthCallbackServer(_oauthCallbackPort);
      await SupabaseConfig.client?.auth.signInWithOAuth(
        provider,
        redirectTo: _oauthCallbackUrl,
      );
      final callbackUri = await callbackFuture;
      await SupabaseConfig.client?.auth.getSessionFromUrl(callbackUri);
    } catch (e) {
      _error = e.toString();
      debugPrint('OAuth error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (!SupabaseConfig.isInitialized) {
      _user = null;
      notifyListeners();
      return;
    }
    
    try {
      _isLoading = true;
      notifyListeners();

      await SupabaseConfig.client?.auth.signOut();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
