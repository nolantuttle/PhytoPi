import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/platform/platform_detector.dart';
import '../../../core/theme/theme_controller.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

import '../../dashboard/screens/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _rememberMe = false;
  final _usernameController = TextEditingController(); // Used as email/username
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final authProvider = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Theme Toggle
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: Icon(
                  isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                  size: 28,
                ),
                onPressed: () {
                  themeController.toggleTheme();
                },
              ),
            ),
            
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    const Text(
                      'PhytoPi',
                      style: TextStyle(
                        fontFamily: 'Cursive', // Placeholder for the script font in image
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Icon(
                      Icons.eco, // Placeholder for the plant/gear logo
                      size: 64,
                    ),
                    const SizedBox(height: 48),
                    
                    // Login Card
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                        ],
                        border: isDark 
                          ? Border.all(color: Colors.white.withOpacity(0.1))
                          : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Login',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          if (authProvider.error != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Text(
                                authProvider.error!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          // Username Field
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              hintText: 'Email',
                              suffixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          
                          // Password Field
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Password',
                              suffixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Remember Me & Forgot Password
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Remember me'),
                              const Spacer(),
                              TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: Colors.grey,
                                ),
                                child: const Text('Forgot password?'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Login Button
                          ElevatedButton(
                            onPressed: authProvider.isLoading ? null : () async {
                              if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
                                return;
                              }
                              debugPrint('LoginScreen: Attempting sign in...');
                              await authProvider.signIn(
                                _usernameController.text,
                                _passwordController.text,
                              );
                              debugPrint('LoginScreen: Sign in complete. Auth: ${authProvider.isAuthenticated}, Web: ${PlatformDetector.isWeb}');

                              if (context.mounted && 
                                  authProvider.isAuthenticated && 
                                  PlatformDetector.isWeb) {
                                debugPrint('LoginScreen: Auth successful. Checking navigation stack.');
                                // Use Future.delayed to ensure any background rebuilds are processed
                                Future.delayed(const Duration(milliseconds: 200), () {
                                  if (context.mounted) {
                                    // Just pop to reveal the Dashboard that main.dart renders
                                    if (Navigator.canPop(context)) {
                                      Navigator.pop(context);
                                    }
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Login Successful')),
                                    );
                                  }
                                });
                              }
                            },
                            child: authProvider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                          ),
                          
                          const SizedBox(height: 32),
                          
                          // Social Login
                          const Text(
                            'Or Sign In Using',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSocialButton(
                                onTap: () => authProvider.signInWithOAuth(OAuthProvider.twitter),
                                child: const Icon(Icons.close, size: 20), // X icon
                                color: const Color(0xFF333333),
                              ),
                              const SizedBox(width: 16),
                              _buildSocialButton(
                                onTap: () => authProvider.signInWithOAuth(OAuthProvider.facebook),
                                child: const Icon(Icons.facebook, color: Colors.white, size: 24),
                                color: const Color(0xFF1877F2),
                              ),
                              const SizedBox(width: 16),
                              _buildSocialButton(
                                onTap: () => authProvider.signInWithOAuth(OAuthProvider.google),
                                child: const Icon(Icons.g_mobiledata, color: Colors.white, size: 32),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFDB4437), Color(0xFF4285F4)],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Register Link
                          Column(
                            children: [
                              const Text(
                                'Or',
                                style: TextStyle(color: Colors.grey),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                  );
                                },
                                child: const Text(
                                  'Register',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required VoidCallback onTap,
    Widget? child,
    Color? color,
    Gradient? gradient,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}
