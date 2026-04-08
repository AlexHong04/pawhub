import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../auth/service/auth_service.dart';
// import 'package:pawhub/core/constants/colors.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        // Prevents color change on scroll
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            // 1. Profile Picture & Name
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
                    iconBgColor: AppColors.primary,
                    iconColor: AppColors.primary,
                    title: "Edit Profile",
                    onTap: () {
                      // Handle Edit Profile
                      Navigator.pushReplacementNamed(context, '/edit_profile');
                    },
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  _buildSettingTile(
                    icon: Icons.lock,
                    iconBgColor: Colors.orange,
                    iconColor: Colors.orange,
                    title: "Reset Password",
                    onTap: () {
                      // Handle Reset Password
                      Navigator.pushReplacementNamed(
                        context,
                        '/reset_password',
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
            // Extra space for scrolling above bottom nav
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  // Helper for Profile Picture and Name
  Widget _buildProfileHeader() {
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
              child: const CircleAvatar(
                radius: 45,
                backgroundColor: AppColors.inputFill,
                // Replace with NetworkImage when connected to backend
                // backgroundImage: AssetImage(
                //   'assets/images/profile_placeholder.png',
                // ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          "Sarah Jenkins",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "sarah.j@example.com",
          style: TextStyle(fontSize: 15, color: AppColors.textLight),
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
