import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/language_service.dart';
import '../../auth/presentation/login_screen.dart';

import '../../../core/utils/responsive.dart';
import '../../steps/data/step_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _dailyReminderKey = 'settings_daily_reminder';
  static const _goalAlertKey = 'settings_goal_alert';
  static const _themeModeKey = 'settings_theme_mode';
  static const _bgTrackingKey = 'settings_bg_tracking';
  static const _stepGoalNotifKey = 'settings_step_goal_notif';
  static const _waterGoalNotifKey = 'settings_water_goal_notif';
  static const _calorieGoalNotifKey = 'settings_calorie_goal_notif';

  bool _dailyReminder = true;
  bool _goalAlert = true;
  bool _bgTracking = true;
  bool _stepGoalNotif = true;
  bool _waterGoalNotif = true;
  bool _calorieGoalNotif = true;
  bool _isSaving = false;
  ThemeMode _themeMode = ThemeMode.light;
  String? _currentEmail;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dailyReminder = prefs.getBool(_dailyReminderKey) ?? true;
      _goalAlert = prefs.getBool(_goalAlertKey) ?? true;
      _bgTracking = prefs.getBool(_bgTrackingKey) ?? true;
      _stepGoalNotif = prefs.getBool(_stepGoalNotifKey) ?? true;
      _waterGoalNotif = prefs.getBool(_waterGoalNotifKey) ?? true;
      _calorieGoalNotif = prefs.getBool(_calorieGoalNotifKey) ?? true;
      _themeMode = ThemeService.themeModeFromString(
        prefs.getString(_themeModeKey),
      );
      _currentEmail = FirebaseAuth.instance.currentUser?.email;
    });
  }

  Future<void> _updatePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (!mounted) return;
    setState(() {
      if (key == _dailyReminderKey) {
        _dailyReminder = value;
      } else if (key == _goalAlertKey) {
        _goalAlert = value;
      } else if (key == _bgTrackingKey) {
        _bgTracking = value;
        if (value) {
          StepRepository.instance.enableStepTracking();
        } else {
          StepRepository.instance.disableStepTracking();
        }
      } else if (key == _stepGoalNotifKey) {
        _stepGoalNotif = value;
      } else if (key == _waterGoalNotifKey) {
        _waterGoalNotif = value;
      } else if (key == _calorieGoalNotifKey) {
        _calorieGoalNotif = value;
      }
    });
  }

  Future<void> _updateThemeMode(ThemeMode? themeMode) async {
    if (themeMode == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeModeKey,
      ThemeService.themeModeToString(themeMode),
    );
    if (!mounted) return;
    setState(() {
      _themeMode = themeMode;
    });
    await ThemeService.setThemeMode(themeMode);
  }

  Future<void> _showResetPasswordDialog() async {
    final emailController = TextEditingController(text: _currentEmail);
    final email = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address',
              hintText: 'Enter your account email',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(emailController.text.trim()),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (email == null || email.isEmpty) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to send reset email: $e')));
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _handleLogout();
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _isSaving = true);
    try {
      await AuthService().logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text('Are you sure you want to permanently delete your account and all stored health data? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _handleDeleteAccount();
    }
  }

  Future<void> _handleDeleteAccount() async {
    setState(() => _isSaving = true);
    try {
      await AuthService().deleteAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account and data deleted successfully.')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete account failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showHelpDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Help & Support'),
          content: const Text(
            'Need help with Calorix? Send feedback to support@calorix.app or tap the button below to copy the support email.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Support email copied to clipboard.'),
                  ),
                );
              },
              child: const Text('Copy Email'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/images/logo.png', width: 40, height: 40, fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Calorix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Version 1.0.0', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Snap. Track. Thrive.',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF22C55E)),
              ),
              const SizedBox(height: 8),
              Text(
                'A world-class AI-powered nutrition and hydration platform designed to help you thrive every day.',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, _, child) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.tr('Settings')),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'Help & Support',
          ),
        ],
      ),
      body: ResponsiveContentConstrained(
        maxWidth: Responsive.maxFormWidth(context),
        enableScroll: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((0.22 * 255).round()),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.settings,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        LanguageService.tr('App Settings'),
                        style: textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        LanguageService.tr('Personalize your experience, privacy, and notifications.'),
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            LanguageService.tr('Notifications'),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 2,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(LanguageService.tr('Daily reminders')),
                  subtitle: Text(
                    LanguageService.tr('Receive reminders for water and meal goals'),
                  ),
                  value: _dailyReminder,
                  onChanged: (value) =>
                      _updatePreference(_dailyReminderKey, value),
                  activeThumbColor: colorScheme.primary,
                  activeTrackColor: colorScheme.primary.withAlpha(80),
                ),
                const Divider(height: 0),
                SwitchListTile(
                  title: Text(LanguageService.tr('Goal alerts')),
                  subtitle: Text(
                    LanguageService.tr('Get notified when you hit your daily targets'),
                  ),
                  value: _goalAlert,
                  onChanged: (value) => _updatePreference(_goalAlertKey, value),
                  activeThumbColor: colorScheme.primary,
                  activeTrackColor: colorScheme.primary.withAlpha(80),
                ),
                const Divider(height: 0),
                SwitchListTile(
                  title: Text(LanguageService.tr('Step Goal Notifications')),
                  subtitle: Text(
                    LanguageService.tr('Notify when 10,000 steps target is completed'),
                  ),
                  value: _stepGoalNotif,
                  onChanged: (value) => _updatePreference(_stepGoalNotifKey, value),
                  activeThumbColor: colorScheme.primary,
                  activeTrackColor: colorScheme.primary.withAlpha(80),
                ),
                const Divider(height: 0),
                SwitchListTile(
                  title: Text(LanguageService.tr('Water Goal Notifications')),
                  subtitle: Text(
                    LanguageService.tr('Notify when daily hydration target is met'),
                  ),
                  value: _waterGoalNotif,
                  onChanged: (value) => _updatePreference(_waterGoalNotifKey, value),
                  activeThumbColor: colorScheme.primary,
                  activeTrackColor: colorScheme.primary.withAlpha(80),
                ),
                const Divider(height: 0),
                SwitchListTile(
                  title: Text(LanguageService.tr('Calorie Goal Notifications')),
                  subtitle: Text(
                    LanguageService.tr('Notify when daily calorie target is reached'),
                  ),
                  value: _calorieGoalNotif,
                  onChanged: (value) => _updatePreference(_calorieGoalNotifKey, value),
                  activeThumbColor: colorScheme.primary,
                  activeTrackColor: colorScheme.primary.withAlpha(80),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            LanguageService.tr('Activity Tracking'),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 2,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(LanguageService.tr('Background Activity Tracking')),
                  subtitle: Text(
                    LanguageService.tr('Keep step tracking active when app is closed'),
                  ),
                  value: _bgTracking,
                  onChanged: (value) => _updatePreference(_bgTrackingKey, value),
                  activeThumbColor: colorScheme.primary,
                  activeTrackColor: colorScheme.primary.withAlpha(80),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            LanguageService.tr('Appearance'),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: DropdownButtonFormField<ThemeMode>(
                initialValue: _themeMode,
                decoration: InputDecoration(
                  labelText: LanguageService.tr('App theme'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withAlpha((0.12 * 255).round()),
                ),
                items: [
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text(LanguageService.tr('Light mode')),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text(LanguageService.tr('Dark mode')),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text(LanguageService.tr('System default')),
                  ),
                ],
                onChanged: _updateThemeMode,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            LanguageService.tr('Security'),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 2,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.lock_outline, color: colorScheme.primary),
                  title: Text(LanguageService.tr('Change password')),
                  subtitle: Text(LanguageService.tr('Send a reset link to your email')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showResetPasswordDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            LanguageService.tr('Support'),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 2,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.help_outline, color: colorScheme.primary),
                  title: Text(LanguageService.tr('Help & Support')),
                  subtitle: Text(LanguageService.tr('Contact support and app guidance')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showHelpDialog,
                ),
                const Divider(height: 0),
                ListTile(
                  leading: Icon(Icons.info_outline, color: colorScheme.primary),
                  title: Text(LanguageService.tr('About app')),
                  subtitle: Text(LanguageService.tr('Version and legal details')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showAboutDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _confirmLogout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    LanguageService.tr('Sign Out'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isSaving ? null : _confirmDeleteAccount,
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade400,
            ),
            child: Text(
              LanguageService.tr('Delete Account'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
