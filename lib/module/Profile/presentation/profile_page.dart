import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pawhub/module/Profile/model/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/colors.dart';
import '../../../core/utils/current_user_store.dart';
import '../../auth/model/auth_model.dart';
import '../../auth/service/auth_service.dart';
import '../service/profile_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String _avatarPathKey = 'profile_edit_avatar_path';

  UserModel? _userProfile;
  File? _localAvatarBackup;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Fetch the data from Supabase (primary) → fallback to SharedPreferences if error
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final localAvatarBackup = await _loadSavedLocalAvatar();

    UserModel? profileData;
    
    // Step 1: Try to fetch from Supabase (primary source)
    try {
      profileData = await ProfileService.getCurrentUserProfile();
    } catch (e) {
      print('Supabase sync error, falling back to local cache: $e');
      
      // Step 2: If Supabase fails, fallback to local SharedPreferences cache
      try {
        final cachedAuth = await CurrentUserStore.read();
        if (cachedAuth != null) {
          profileData = UserModel(
            id: cachedAuth.id,
            name: cachedAuth.name,
            email: cachedAuth.email,
            gender: '',
            contact: '',
            address: '',
            role: cachedAuth.role,
            onlineStatus: 'Online',
            isVolunteer: false,
            updatedAt: cachedAuth.createAt,
            avatarUrl: '',
          );
        }
      } catch (fallbackError) {
        print('Also failed to read local cache: $fallbackError');
      }
    }

    if (mounted) {
      setState(() {
        _userProfile = profileData;
        _localAvatarBackup = localAvatarBackup;
        _isLoading = false;
      });
    }
  }

  Future<File?> _loadSavedLocalAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(_avatarPathKey);
    if (savedPath == null || savedPath.isEmpty) return null;

    final backupFile = File(savedPath);
    if (await backupFile.exists()) {
      return backupFile;
    }

    await prefs.remove(_avatarPathKey);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "Profile",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        backgroundColor: AppColors.background,
      ),
      // Show a loading spinner while fetching data
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            // 1. Profile Picture & Name (Now Dynamic!)
            _buildProfileHeader(),
            const SizedBox(height: 32),

            // 2. Stats Row (Adopted & Favorites)
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    number: "2",
                    label: "ADOPTED",
                    numberColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    number: "14",
                    label: "FAVORITES",
                    numberColor: AppColors.textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 3. Account Section Header
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "ACCOUNT",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.textLight,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 4. Account Settings List
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSettingTile(
                    icon: Icons.person,
                    iconBgColor: AppColors.primary.withOpacity(0.1), // Made background lighter so icon pops!
                    iconColor: AppColors.primary,
                    title: "Edit Profile",
                    onTap: () {
                      // CHANGED: Use pushNamed instead of replacement so the back button works.
                      // The .then() ensures the page refreshes when you come back!
                      Navigator.pushNamed(context, '/edit_profile').then((_) {
                        _loadUserData();
                      });
                    },
                  ),
                  const Divider(height: 1, color: AppColors.borderGray),
                  _buildSettingTile(
                    icon: Icons.lock,
                    iconBgColor: Colors.orange.withOpacity(0.1),
                    iconColor: Colors.orange,
                    title: "Reset Password",
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/reset_password', // Or whatever your route is
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // 5. Sign Out Button
            TextButton.icon(
              onPressed: () async {
                await AuthService.logout();
                if (!context.mounted) return;

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                      (route) => false,
                );
              },
              icon: const Icon(Icons.logout, color: AppColors.textLight),
              label: const Text(
                "Sign Out",
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    // Safely grab the data from our model with fallbacks
    final name = _userProfile?.name ?? "Loading...";
    final email = _userProfile?.email ?? "Loading...";
    final avatarUrl = _userProfile?.avatarUrl;

    ImageProvider? avatarImage;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      // Primary source: Supabase URL
      avatarImage = NetworkImage(avatarUrl);
    } else if (_localAvatarBackup != null) {
      // Fallback source: local backup path
      avatarImage = FileImage(_localAvatarBackup!);
    }

    return Column(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.5),
                  width: 3,
                ),
              ),
              child: CircleAvatar(
                radius: 45,
                backgroundColor: AppColors.inputFill,
                backgroundImage: avatarImage,
                child: avatarImage == null
                    ? const Icon(Icons.person, size: 45, color: Colors.grey)
                    : null,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/edit_profile').then((_) {
                    _loadUserData();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          name, // DYNAMIC NAME
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          email, // DYNAMIC EMAIL
          style: const TextStyle(fontSize: 15, color: AppColors.textLight),
        ),
      ],
    );
  }

  // Helper for the Adopted/Favorites Cards
  Widget _buildStatCard({
    required String number,
    required String label,
    required Color numberColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            number,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: numberColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  // Helper for the Account List Tiles
  Widget _buildSettingTile({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
    );
  }
}