import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config/supabase_config.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _emailEnabled = true;
  bool _smsEnabled = false;
  final _phoneController = TextEditingController();
  bool _hasRow = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (!SupabaseConfig.isInitialized) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await SupabaseConfig.client!
          .from('alert_notification_settings')
          .select()
          .maybeSingle();
      if (res != null) {
        _hasRow = true;
        _emailEnabled = res['email_enabled'] as bool? ?? true;
        _smsEnabled = res['sms_enabled'] as bool? ?? false;
        _phoneController.text = res['phone_e164'] as String? ?? '';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!SupabaseConfig.isInitialized) return;
    final userId = SupabaseConfig.client!.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _error = 'Not signed in');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final phone = _phoneController.text.trim();
      final data = {
        'email_enabled': _emailEnabled,
        'sms_enabled': _smsEnabled,
        'phone_e164': phone.isEmpty ? null : phone,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (_hasRow) {
        await SupabaseConfig.client!
            .from('alert_notification_settings')
            .update(data)
            .eq('user_id', userId);
      } else {
        await SupabaseConfig.client!.from('alert_notification_settings').insert({
          ...data,
          'user_id': userId,
        });
        _hasRow = true;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification settings saved')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            // User info card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.person, size: 28, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.email ?? 'Not signed in',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user != null ? 'Account ID: ${user.id.substring(0, 8)}…' : 'Sign in to manage notifications',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                          ),
                        ],
                      ),
                    ),
                    if (user != null)
                      TextButton(
                        onPressed: () => authProvider.signOut(),
                        child: const Text('Sign out'),
                      ),
                  ],
                ),
              ),
            ),

            if (user != null) ...[
              const SizedBox(height: 24),
              Text('Alert Notifications', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Choose how you want to be notified when a sensor threshold is breached.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 16),

              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Email notifications'),
                        subtitle: Text(user.email ?? ''),
                        value: _emailEnabled,
                        onChanged: (v) => setState(() => _emailEnabled = v),
                        secondary: const Icon(Icons.email_outlined),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('SMS notifications'),
                        subtitle: const Text('Requires phone number below'),
                        value: _smsEnabled,
                        onChanged: (v) => setState(() => _smsEnabled = v),
                        secondary: const Icon(Icons.sms_outlined),
                      ),
                      if (_smsEnabled) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                          child: TextField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone number',
                              hintText: '+1234567890',
                              helperText: 'E.164 format, e.g. +1 555 000 0000',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],

              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Email delivery requires a Database Webhook on alerts INSERT → notify-alert, plus RESEND_API_KEY and a verified Resend domain. Alerts created earlier can be sent with a one-time POST to notify-alert containing {"process_pending":true} (same auth as the webhook). SMS requires Twilio credentials and a verified phone number.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveSettings,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save notification settings'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
