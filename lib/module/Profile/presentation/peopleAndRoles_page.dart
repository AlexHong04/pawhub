import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/core/widgets/filterButton.dart';
import 'package:pawhub/module/Profile/model/user_model.dart';
import 'package:pawhub/module/Profile/service/profile_service.dart';

import '../../../core/widgets/profile_avatar.dart';
// import 'user_model.dart'; // Make sure to import your UserModel file here!

class PeopleAndRolesPage extends StatefulWidget {
  const PeopleAndRolesPage({super.key});

  @override
  State<PeopleAndRolesPage> createState() => _PeopleAndRolesPageState();
}

class _PeopleAndRolesPageState extends State<PeopleAndRolesPage> {
  static const Color _unbanCyan = Color(0xFF06B6D4);
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['All', 'Volunteers', 'User', 'Admin'];
  final List<String> _roleChoices = ['Admin', 'Volunteer', 'User'];

  List<UserModel> _allUsers = []; // Stores the master list from DB
  List<UserModel> _filteredUsers = []; // Stores what is currently on screen
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // 1. Fetch data from Supabase
  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);

    // Call the new service function
    final users = await ProfileService.getAllUsers();

    if (mounted) {
      setState(() {
        _allUsers = users;
        _filteredUsers = users; // Initially, show everyone
        _isLoading = false;
      });
    }
  }

  // 2. Filter Logic (Handles both Search typing AND Chip clicking)
  void _applyFilters() {
    // Start with all users
    List<UserModel> results = List.from(_allUsers);

    // 1. Apply Chip Filter
    final selectedFilter = _filters[_selectedFilterIndex];
    if (selectedFilter == 'Volunteers') {
      results = results.where((u) => u.isVolunteer).toList();
    } else if (selectedFilter == 'User') {
      results = results.where((u) {
        final role = u.role.trim().toLowerCase();
        return role == 'user' && !u.isVolunteer;
      }).toList();
    } else if (selectedFilter == 'Admin') {
      results = results
          .where((u) => u.role.trim().toLowerCase() == 'admin')
          .toList();
    }

    // 2. Apply Text Search (Case-insensitive & space-trimmed)
    if (_searchQuery.trim().isNotEmpty) {
      final searchLower = _searchQuery.trim().toLowerCase();

      results = results.where((u) {
        final nameLower = u.name.trim().toLowerCase();
        final emailLower = u.email.trim().toLowerCase();
        final roleLower = _resolveDisplayRole(u).toLowerCase();

        return nameLower.contains(searchLower) ||
            emailLower.contains(searchLower) ||
            roleLower.contains(searchLower);
      }).toList();
    }

    // 3. Update the UI
    setState(() {
      _filteredUsers = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.arrow_back, color: AppColors.iconColor),
        ),
        title: const Text(
          "People & Roles",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.borderGray, height: 1.0),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: _buildSearchBar(),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24),
            child: _buildFilterChips(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                ? const Center(child: Text("No users found."))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    itemCount: _filteredUsers.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildUserCard(_filteredUsers[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        onChanged: (value) {
          _searchQuery = value;
          _applyFilters();
        },
        decoration: InputDecoration(
          hintText: "Search name, email or role...",
          hintStyle: TextStyle(color: AppColors.textLight, fontSize: 15),
          prefixIcon: Icon(Icons.search, color: AppColors.textLight),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_filters.length, (index) {
            final isSelected = _selectedFilterIndex == index;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilterButton(
                text: _filters[index],
                isSelected: isSelected,
                onPressed: () {
                  setState(() => _selectedFilterIndex = index);
                  _applyFilters();
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  // Widget _buildFilterChips() {
  //   return SingleChildScrollView(
  //     scrollDirection: Axis.horizontal,
  //     padding: const EdgeInsets.symmetric(horizontal: 24),
  //     child: Row(
  //       children: List.generate(_filters.length, (index) {
  //         final isSelected = _selectedFilterIndex == index;
  //         return Padding(
  //           padding: const EdgeInsets.only(right: 12),
  //           child: FilterButton(
  //             text: _filters[index],
  //             isSelected: isSelected,
  //             onPressed: () {
  //               setState(() => _selectedFilterIndex = index);
  //               _applyFilters();
  //             },
  //           ),
  //         );
  //       }),
  //     ),
  //   );
  // }

  Widget _buildUserCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(user),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildRoleBadge(user),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStatusBadge(user),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => _showUserActionsSheet(user),
                child: const Icon(
                  Icons.more_vert,
                  color: AppColors.textLight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserActionsSheet(UserModel user) {
    final resolvedRole = _resolveDisplayRole(user);

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.88;
        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderGray,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'User Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildUserInfoCard(user),
                const SizedBox(height: 12),
                ..._buildRoleBasedActions(
                  user: user,
                  resolvedRole: resolvedRole,
                  sheetContext: sheetContext,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserInfoCard(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ProfileAvatar(
            userId: user.id,
            name: user.name,
            avatarUrl: user.avatarUrl,
            radius: 22,
            backgroundColor: AppColors.inputFill,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRoleBasedActions({
    required UserModel user,
    required String resolvedRole,
    required BuildContext sheetContext,
  }) {
    final actions = <Widget>[
      _buildActionTile(
        icon: Icons.admin_panel_settings_outlined,
        iconColor: AppColors.primary,
        title: 'Change Role',
        onTap: () {
          Navigator.pop(sheetContext);
          _showChangeRoleSheet(user);
        },
      ),
      _buildActionTile(
        icon: Icons.lock_reset,
        iconColor: AppColors.primary,
        title: 'Reset Password',
        onTap: () {
          Navigator.pop(sheetContext);
          Navigator.pushNamed(context, '/reset_password');
        },
      ),
    ];

    if (resolvedRole != 'Admin') {
      actions.add(const Divider(height: 24, color: AppColors.borderGray));
      actions.add(
        _buildActionTile(
          icon: user.isBanned ? Icons.check_circle_outline : Icons.block,
          iconColor: user.isBanned ? _unbanCyan : Colors.red,
          title: user.isBanned
              ? 'Unban ${resolvedRole == 'Volunteer' ? 'Volunteer' : 'User'}'
              : 'Ban ${resolvedRole == 'Volunteer' ? 'Volunteer' : 'User'}',
          titleColor: user.isBanned ? _unbanCyan : Colors.red,
          onTap: () async {
            Navigator.pop(sheetContext);

            final shouldBan = !user.isBanned;
            final success = await ProfileService.updateUserBanStatus(
              user.id,
              shouldBan,
            );

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? (shouldBan
                            ? '${resolvedRole == 'Volunteer' ? 'Volunteer' : 'User'} ${user.name} has been banned'
                            : '${resolvedRole == 'Volunteer' ? 'Volunteer' : 'User'} ${user.name} has been unbanned')
                      : 'Failed to update ban status for ${user.name}',
                ),
                backgroundColor: success ? null : Colors.red,
              ),
            );

            if (success) {
              await _fetchUsers();
            }
          },
        ),
      );
    }

    return actions;
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = AppColors.textLight,
    Color titleColor = AppColors.textDark,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: titleColor,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showChangeRoleSheet(UserModel user) {
    String selectedRole = _resolveDisplayRole(user);
    bool saving = false;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (roleSheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> saveRole() async {
              if (saving) return;
              setModalState(() => saving = true);

              final success = await ProfileService.updateUserRole(
                user.id,
                selectedRole,
              );

              if (!mounted) return;
              if (roleSheetContext.mounted) {
                Navigator.pop(roleSheetContext);
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Role updated to $selectedRole for ${user.name}'
                        : 'Failed to update role for ${user.name}',
                  ),
                  backgroundColor: success ? null : Colors.red,
                ),
              );

              if (success) {
                await _fetchUsers();
              }
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.borderGray,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'System Role',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._roleChoices.map((role) {
                      final isSelected = selectedRole == role;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildRoleOptionCard(
                          role: role,
                          isSelected: isSelected,
                          onTap: () => setModalState(() => selectedRole = role),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: saving ? null : saveRole,
                        child: Text(
                          saving ? 'Saving...' : 'Save User',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(roleSheetContext),
                        child: const Text(
                          'Discard Changes',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRoleOptionCard({
    required String role,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    IconData icon;
    String description;

    switch (role) {
      case 'Admin':
        icon = Icons.admin_panel_settings;
        description = 'Full access to all system features';
        break;
      case 'Volunteer':
        icon = Icons.volunteer_activism;
        description = 'Limited access to pet & event records';
        break;
      default:
        icon = Icons.person_outline;
        description = 'Standard access to user features';
        break;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          color: isSelected ? AppColors.primary.withAlpha(12) : AppColors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.inputFill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ],
        ),
      ),
    );
  }

  String _resolveDisplayRole(UserModel user) {
    final rawRole = user.role.trim().toLowerCase();
    if (rawRole == 'admin') return 'Admin';
    if (user.isVolunteer || rawRole == 'volunteer' || rawRole == 'volunteers') {
      return 'Volunteer';
    }
    return 'User';
  }

  Widget _buildAvatar(UserModel user) {
    return Stack(
      children: [
        ProfileAvatar(
          userId: user.id,
          name: user.name,
          avatarUrl: user.avatarUrl,
          radius: 28,
          backgroundColor: AppColors.background,
        ),
        if (user.role == "Admin")
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Text(
                "AD",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRoleBadge(UserModel user) {
    final normalizedRole = _resolveDisplayRole(user);
    Color bgColor;
    Color textColor;
    switch (normalizedRole) {
      case 'Admin':
        bgColor = AppColors.adminBadgeBg;
        textColor = AppColors.adminBadgeText;
        break;
      case 'Volunteer':
        bgColor = AppColors.volunteerBadgeBg;
        textColor = AppColors.volunteerBadgeText;
        break;
      default:
        bgColor = AppColors.defaultBadgeBg;
        textColor = AppColors.defaultBadgeText;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        normalizedRole,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(UserModel user) {
    final isOnline = ProfileService.isOnlineFromHeartbeat(
      status: user.onlineStatus,
      updatedAt: user.updatedAt,
    );
    final statusLabel = isOnline ? 'Online' : 'Offline';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline ? AppColors.primary.withAlpha(20) : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline ? AppColors.primary.withAlpha(70) : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 12,
            color: isOnline ? AppColors.primary : AppColors.textLight,
          ),
          const SizedBox(width: 4),
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isOnline ? AppColors.primary : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
