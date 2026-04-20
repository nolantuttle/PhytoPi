import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/theme_controller.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    await authProvider.signUp(_emailController.text, _passwordController.text);
    
    if (mounted && authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error!)),
      );
    } else if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful! Please check your email for confirmation.')),
      );
       Navigator.pop(context);
    }
  }

  Future<void> _handleSocialAuth(OAuthProvider provider) async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.signInWithOAuth(provider);
     if (mounted && authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authProvider.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();

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
                        fontFamily: 'Cursive', 
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Icon(
                      Icons.eco,
                      size: 64,
                    ),
                    const SizedBox(height: 32),
                    
                    // Register Card
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
                            'Create Account',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Username Field
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              hintText: 'Username',
                              suffixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Email Field
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'Email',
                              suffixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Password Field
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                          ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Confirm Password Field
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              hintText: 'Confirm Password',
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Register Button
                          ElevatedButton(
                            onPressed: authProvider.isLoading ? null : _handleRegister,
                            child: authProvider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2)
                                )
                              : const Text(
                                  'Register',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Social Login
                          const Text(
                            'Or Sign Up Using',
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
                                onTap: () => _handleSocialAuth(OAuthProvider.twitter),
                                child: const Icon(Icons.close, size: 20, color: Colors.white), // X icon (Twitter)
                                color: const Color(0xFF000000), // X uses black
                              ),
                              const SizedBox(width: 16),
                              _buildSocialButton(
                                onTap: () => _handleSocialAuth(OAuthProvider.facebook),
                                child: const Icon(Icons.facebook, color: Colors.white, size: 24),
                                color: const Color(0xFF1877F2),
                              ),
                              const SizedBox(width: 16),
                              _buildSocialButton(
                                onTap: () => _handleSocialAuth(OAuthProvider.google),
                                child: const Icon(Icons.g_mobiledata, color: Colors.white, size: 32), // Placeholder for Google G
                                color: const Color(0xFFDB4437),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Login Link
                          Column(
                            children: [
                              const Text(
                                'Already have an account?',
                                style: TextStyle(color: Colors.grey),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  'Login',
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
