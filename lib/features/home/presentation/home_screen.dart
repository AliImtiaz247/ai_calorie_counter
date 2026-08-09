import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/language_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../ai_scan/services/image_picker_service.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../health_calculator/presentation/health_calculator_screen.dart';
import '../../history/presentation/history_screen.dart';
import '../../meals/presentation/meals_screen.dart';
import '../../profile/data/profile_repository.dart';
import '../../progress/presentation/progress_screen.dart';
import '../../scan/presentation/scan_food_screen.dart';
import '../../sync/presentation/sync_center_modal.dart';
import '../../water/presentation/water_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  final ProfileRepository _profileRepository = ProfileRepository();
  final ImagePickerService _imagePickerService = ImagePickerService();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  UserProfile? profile;
  bool isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    SyncService.instance.init();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      _loadError = null;
    });

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _loadError = 'No authenticated user found. Please log in again.';
      });
      return;
    }

    // Retry up to 3 times with a short delay
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (!doc.exists) {
          final defaultProfile = UserProfile(
            uid: firebaseUser.uid,
            name: firebaseUser.displayName?.isNotEmpty == true
                ? firebaseUser.displayName!
                : (firebaseUser.email?.split('@').first ?? 'User'),
            email: firebaseUser.email ?? '',
            age: 25,
            height: 170,
            currentWeight: 70,
            targetWeight: 65,
            gender: 'Male',
            activityLevel: 'Moderate',
            goal: 'Maintain Weight',
            createdAt: DateTime.now(),
          );
          await _profileRepository.saveProfile(defaultProfile);
          profile = defaultProfile;
          break;
        } else {
          profile = await _profileRepository.getProfile(forceRefresh: true);
          if (profile != null) break;
        }
      } catch (e) {
        debugPrint("Profile load error (attempt $attempt): $e");
      }
      if (attempt < 3) await Future.delayed(const Duration(seconds: 1));
    }

    // Fallback if profile is still null
    if (profile == null) {
      if (_profileRepository.hasCache) {
        profile = _profileRepository.cachedProfile;
      } else {
        profile = UserProfile(
          uid: firebaseUser.uid,
          name: firebaseUser.displayName?.isNotEmpty == true
              ? firebaseUser.displayName!
              : (firebaseUser.email?.split('@').first ?? 'User'),
          email: firebaseUser.email ?? '',
          age: 25,
          height: 170,
          currentWeight: 70,
          targetWeight: 65,
          gender: 'Male',
          activityLevel: 'Moderate',
          goal: 'Maintain Weight',
          createdAt: DateTime.now(),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      isLoading = false;
      if (profile == null) {
        _loadError = 'Could not load your profile. Please check your connection.';
      }
    });
  }
  List<Widget> get pages => [
    DashboardScreen(profile: profile!),
    const MealsScreen(),
    const WaterScreen(),
    _buildProfilePage(),
  ];

  Widget _buildProfilePage() {
    final currentProfile = profile!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF22C55E);

    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, currentLanguage, _) {
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.horizontalPadding(context),
            vertical: 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dribbble Header Profile Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar Circle with gradient border
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, const Color(0xFF10B981)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            foregroundImage: currentProfile.hasCustomAvatar
                                ? NetworkImage(currentProfile.avatarUrl!) as ImageProvider
                                : AssetImage(currentProfile.defaultAvatarAsset) as ImageProvider,
                          ),
                        ),
                        GestureDetector(
                          onTap: _showAvatarPicker,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  currentProfile.name.isNotEmpty
                                      ? currentProfile.name
                                      : 'Calorix User',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.verified_rounded,
                                color: primaryColor,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentProfile.email,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _editProfileField(
                              title: 'Name',
                              initialValue: currentProfile.name,
                              onSave: _updateName,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_outlined, size: 13, color: primaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Edit Profile",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Metrics Card Row (3 Columns: Weight, Height, Target)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricCol(
                      label: LanguageService.tr("Weight"),
                      value: "${currentProfile.currentWeight.toStringAsFixed(1)} kg",
                      icon: Icons.monitor_weight_outlined,
                      color: const Color(0xFF0EA5E9),
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProgressScreen(userProfile: currentProfile),
                          ),
                        );
                      },
                    ),
                    Container(height: 36, width: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                    _buildMetricCol(
                      label: LanguageService.tr("Height"),
                      value: "${currentProfile.height.toStringAsFixed(0)} cm",
                      icon: Icons.height_rounded,
                      color: const Color(0xFF8B5CF6),
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HealthCalculatorScreen(userProfile: currentProfile),
                          ),
                        );
                      },
                    ),
                    Container(height: 36, width: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                    _buildMetricCol(
                      label: LanguageService.tr("Target"),
                      value: "${currentProfile.targetWeight.toStringAsFixed(1)} kg",
                      icon: Icons.track_changes_rounded,
                      color: primaryColor,
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProgressScreen(userProfile: currentProfile),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Menu Section Label
              Text(
                "ACCOUNT & PREFERENCES",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),

              // Dribbble Menu List Items
              _buildDribbbleMenuItem(
                icon: Icons.person_outline_rounded,
                iconBgColor: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                iconColor: const Color(0xFF0EA5E9),
                title: LanguageService.tr("Personal Information"),
                subtitle: "Manage account details, email & gender",
                isDark: isDark,
                onTap: _showPersonalInfoModal,
              ),

              _buildDribbbleMenuItem(
                icon: Icons.history_toggle_off_rounded,
                iconBgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                iconColor: const Color(0xFF8B5CF6),
                title: LanguageService.tr("User History"),
                subtitle: "View meal logs, weight milestones & activity",
                isDark: isDark,
                onTap: _showUserHistoryModal,
              ),

              _buildDribbbleMenuItem(
                icon: Icons.sync_rounded,
                iconBgColor: const Color(0xFF22C55E).withValues(alpha: 0.15),
                iconColor: const Color(0xFF22C55E),
                title: LanguageService.tr("Data Synchronization"),
                subtitle: LanguageService.tr("Manage offline queue & sync status"),
                isDark: isDark,
                onTap: () => SyncCenterModal.show(context),
              ),

              _buildDribbbleMenuItem(
                icon: Icons.show_chart_rounded,
                iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                iconColor: const Color(0xFF10B981),
                title: LanguageService.tr("Progress & Analytics"),
                subtitle: "Track weight changes & historical graphs",
                isDark: isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProgressScreen(userProfile: currentProfile),
                    ),
                  );
                },
              ),

              _buildDribbbleMenuItem(
                icon: Icons.calculate_outlined,
                iconBgColor: const Color(0xFFEC4899).withValues(alpha: 0.15),
                iconColor: const Color(0xFFEC4899),
                title: LanguageService.tr("Health Calculator"),
                subtitle: "Compute BMR, TDEE & macro targets",
                isDark: isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HealthCalculatorScreen(userProfile: currentProfile),
                    ),
                  );
                },
              ),

              _buildDribbbleMenuItem(
                icon: Icons.settings_outlined,
                iconBgColor: const Color(0xFF64748B).withValues(alpha: 0.15),
                iconColor: const Color(0xFF64748B),
                title: LanguageService.tr("Settings & Appearance"),
                subtitle: "Notifications, Dark Mode & Security",
                isDark: isDark,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),

              _buildDribbbleMenuItem(
                icon: Icons.logout_rounded,
                iconBgColor: Colors.red.withValues(alpha: 0.15),
                iconColor: Colors.redAccent,
                title: LanguageService.tr("Log Out"),
                subtitle: "Sign out of your account",
                isDark: isDark,
                onTap: _confirmLogout,
              ),

              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAvatarPicker() async {
    final selected = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.of(context).pop(true),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove avatar'),
                onTap: () => Navigator.of(context).pop(null),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null) {
      await _showRemoveAvatarDialog();
      return;
    }
    if (selected != true) return;
    await _chooseAvatar();
  }

  Future<void> _showRemoveAvatarDialog() async {
    if (profile == null) return;

    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove avatar'),
        content: const Text(
          'Do you want to remove your avatar and use the gender default?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (remove != true) return;

    final updatedProfile = profile!.copyWith(avatarUrl: null);
    await _profileRepository.saveProfile(updatedProfile);

    if (!mounted) return;
    setState(() => profile = updatedProfile);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Avatar removed. Gender default applied.')),
    );
  }

  Future<void> _chooseAvatar() async {
    final File? pickedFile = await _imagePickerService.pickFromGallery();
    if (pickedFile == null || profile == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Uploading avatar...'),
          ],
        ),
        duration: Duration(seconds: 5),
      ),
    );

    final uid = profile!.uid;
    final destination = 'avatars/$uid.jpg';

    try {
      final ref = _storage.ref(destination);
      final uploadTask = ref.putFile(pickedFile);
      final snapshot = await uploadTask;
      final avatarUrl = await snapshot.ref.getDownloadURL();
      final updatedProfile = profile!.copyWith(avatarUrl: avatarUrl);
      await _profileRepository.saveProfile(updatedProfile);

      if (!mounted) return;
      setState(() {
        profile = updatedProfile;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload avatar: $e')));
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out from the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _handleLogout();
    }
  }

  Future<void> _editProfileField({
    required String title,
    required String initialValue,
    required Future<void> Function(String) onSave,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Enter new $title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (value == null || value.isEmpty || value == initialValue) return;
    await onSave(value);
  }

  Future<void> _updateName(String name) async {
    final updatedProfile = profile!.copyWith(name: name);

    try {
      await _profileRepository.saveProfile(updatedProfile);
      await AuthService().updateDisplayName(name);
      if (!mounted) return;
      setState(() {
        profile = updatedProfile;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update name: $e')));
    }
  }

  Future<void> _editGender() async {
    final currentGender = profile?.gender ?? '';
    final selectedGender = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Select Gender'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('Male'),
              child: const Text('Male'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('Female'),
              child: const Text('Female'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop('Other'),
              child: const Text('Other'),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(currentGender),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selectedGender == null || selectedGender == currentGender) return;
    final updatedProfile = profile!.copyWith(
      avatarUrl: null,
      gender: selectedGender,
    );
    try {
      await _profileRepository.saveProfile(updatedProfile);
      if (!mounted) return;
      setState(() {
        profile = updatedProfile;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gender changed to $selectedGender')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update gender: $e')));
    }
  }

  Future<void> _updateEmail(String email) async {
    final updatedProfile = profile!.copyWith(email: email);

    try {
      await AuthService().updateEmail(email);
      await _profileRepository.saveProfile(updatedProfile);
      if (!mounted) return;
      setState(() {
        profile = updatedProfile;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update email: $e')));
    }
  }

  Future<void> _handleLogout() async {
    try {
      await AuthService().logout();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (profile == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _loadError ?? 'Could not load your profile.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _loadProfile,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Log Out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = Responsive.isTabletOrDesktop(context);

    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, currentLanguage, _) {
        return Directionality(
          textDirection: LanguageService.textDirection,
          child: isTablet
              ? Scaffold(
                  body: Row(
                    children: [
                      NavigationRail(
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        selectedIndex: currentIndex,
                        onDestinationSelected: (index) {
                          setState(() => currentIndex = index);
                        },
                        labelType: NavigationRailLabelType.all,
                        leading: Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 24),
                          child: FloatingActionButton.small(
                            elevation: 2,
                            backgroundColor: const Color(0xFF22C55E),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ScanFoodScreen(mealType: 'Lunch'),
                                ),
                              );
                            },
                            child: const Icon(Icons.add_rounded, color: Colors.white),
                          ),
                        ),
                        destinations: [
                          NavigationRailDestination(
                            icon: const Icon(Icons.home_outlined),
                            selectedIcon: const Icon(Icons.home_rounded, color: Color(0xFF22C55E)),
                            label: Text(LanguageService.tr('Home')),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.restaurant_menu_outlined),
                            selectedIcon: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF22C55E)),
                            label: Text(LanguageService.tr('Meals')),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.water_drop_outlined),
                            selectedIcon: const Icon(Icons.water_drop_rounded, color: Color(0xFF22C55E)),
                            label: Text(LanguageService.tr('Water')),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.person_outline),
                            selectedIcon: const Icon(Icons.person_rounded, color: Color(0xFF22C55E)),
                            label: Text(LanguageService.tr('Profile')),
                          ),
                        ],
                      ),
                      VerticalDivider(
                        thickness: 1,
                        width: 1,
                        color: isDark ? Colors.white12 : Colors.grey.shade200,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const OfflineBanner(),
                            Expanded(child: pages[currentIndex]),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Scaffold(
                  extendBody: true,
                  body: Column(
                    children: [
                      const OfflineBanner(),
                      Expanded(child: pages[currentIndex]),
                    ],
                  ),
                  bottomNavigationBar: _buildCustomBottomNavBar(isDark),
                ),
        );
      },
    );
  }

  Widget _buildCustomBottomNavBar(bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: isDark
                  ? Colors.white12
                  : Colors.black.withValues(alpha: 0.06),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                activeIcon: Icons.home_rounded,
                inactiveIcon: Icons.home_outlined,
                label: LanguageService.tr('Home'),
                isDark: isDark,
              ),
              _buildNavItem(
                index: 1,
                activeIcon: Icons.restaurant_menu_rounded,
                inactiveIcon: Icons.restaurant_menu_outlined,
                label: LanguageService.tr('Meals'),
                isDark: isDark,
              ),
              _buildCenterPlusButton(primaryColor),
              _buildNavItem(
                index: 2,
                activeIcon: Icons.water_drop_rounded,
                inactiveIcon: Icons.water_drop_outlined,
                label: LanguageService.tr('Water'),
                isDark: isDark,
              ),
              _buildNavItem(
                index: 3,
                activeIcon: Icons.person_rounded,
                inactiveIcon: Icons.person_outline_rounded,
                label: LanguageService.tr('Profile'),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = currentIndex == index;
    final primaryColor = const Color(0xFF22C55E);

    return InkWell(
      onTap: () {
        setState(() {
          currentIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 12 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected
                  ? primaryColor
                  : (isDark ? Colors.white60 : Colors.grey.shade600),
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCenterPlusButton(Color primaryColor) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ScanFoodScreen(mealType: 'Lunch'),
          ),
        );
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF22C55E), Color(0xFF0F766E)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22C55E).withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
  Widget _buildMetricCol({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDribbbleMenuItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailingWidget,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
        trailing: trailingWidget ??
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
      ),
    );
  }

  Future<void> _showPersonalInfoModal() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Personal Information",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.person_rounded, color: Color(0xFF0EA5E9)),
                  title: const Text("Full Name"),
                  subtitle: Text(profile?.name.isNotEmpty == true ? profile!.name : "Not set"),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () {
                    Navigator.pop(context);
                    _editProfileField(
                      title: 'Name',
                      initialValue: profile?.name ?? '',
                      onSave: _updateName,
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.email_rounded, color: Color(0xFF8B5CF6)),
                  title: const Text("Email Address"),
                  subtitle: Text(profile?.email ?? "Not set"),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () {
                    Navigator.pop(context);
                    _editProfileField(
                      title: 'Email',
                      initialValue: profile?.email ?? '',
                      onSave: _updateEmail,
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.wc_rounded, color: Color(0xFF22C55E)),
                  title: const Text("Gender"),
                  subtitle: Text(profile?.gender.isNotEmpty == true ? profile!.gender : "Not set"),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () {
                    Navigator.pop(context);
                    _editGender();
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUserHistoryModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "User History & Activity",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _historyTile(
                  icon: Icons.restaurant_menu_rounded,
                  color: Colors.purple,
                  title: "Logged Meals History",
                  subtitle: "Tracked daily breakfast, lunch, dinner & snacks",
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HistoryScreen(initialTabIndex: 0),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _historyTile(
                  icon: Icons.monitor_weight_rounded,
                  color: const Color(0xFF22C55E),
                  title: "Weight Milestone Logs",
                  subtitle: "Recorded body weight entries & BMI calculations",
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HistoryScreen(initialTabIndex: 1),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _historyTile(
                  icon: Icons.directions_walk_rounded,
                  color: const Color(0xFFF59E0B),
                  title: "Steps Tracker History",
                  subtitle: "Daily step counts, active distance & calorie burn logs",
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HistoryScreen(initialTabIndex: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _historyTile(
                  icon: Icons.water_drop_rounded,
                  color: const Color(0xFF0EA5E9),
                  title: "Hydration History",
                  subtitle: "Daily water consumption target completions",
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HistoryScreen(initialTabIndex: 3),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _historyTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

}
