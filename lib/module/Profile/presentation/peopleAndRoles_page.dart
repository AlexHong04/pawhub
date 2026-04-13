import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';

import '../model/user_model.dart';
import '../service/profile_service.dart';
// import 'user_model.dart'; // Make sure to import your UserModel file here!

class PeopleAndRolesPage extends StatefulWidget {
  const PeopleAndRolesPage({super.key});

  @override
  State<PeopleAndRolesPage> createState() => _PeopleAndRolesPageState();
}

class _PeopleAndRolesPageState extends State<PeopleAndRolesPage> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['All', 'Volunteers', 'User', 'Admin'];

  // Mock data using your EXACT UserModel structure
  // final List<UserModel> _users = [
  //   UserModel(
  //     id: "1",
  //     name: "Sarah Jenkins",
  //     gender: "Female",
  //     contact: "555-0101",
  //     address: "123 Main St",
  //     role: "Admin",
  //     onlineStatus: "Active 2m ago",
  //     isVolunteer: false,
  //     updatedAt: DateTime.now(),
  //     avatarUrl: "assets/images/profile_placeholder.png",
  //     // Or a network URL
  //     email: "sarah.j@shelter.org",
  //   ),
  //   UserModel(
  //     id: "2",
  //     name: "David Torres",
  //     gender: "Male",
  //     contact: "555-0102",
  //     address: "456 Oak Ave",
  //     role: "Volunteer",
  //     onlineStatus: "Inactive (3mo)",
  //     isVolunteer: true,
  //     updatedAt: DateTime.now(),
  //     avatarUrl: "",
  //     // Empty URL forces it to show Initials automatically!
  //     email: "david.t@example.com",
  //   ),
  //   UserModel(
  //     id: "3",
  //     name: "Jessica Alba",
  //     gender: "Female",
  //     contact: "555-0103",
  //     address: "789 Pine Rd",
  //     role: "User",
  //     onlineStatus: "Active 2m ago",
  //     isVolunteer: false,
  //     updatedAt: DateTime.now(),
  //     avatarUrl: "assets/images/profile_placeholder.png",
  //     email: "jess.alba88@outlook.com",
  //   ),
  // ];

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

    // 1. Apply Chip Filter (Case-insensitive & space-trimmed)
    String selectedFilter = _filters[_selectedFilterIndex];
    if (selectedFilter != 'All') {
      String targetRole = '';

      // Map to the database roles, but use strictly lowercase for safe comparing
      if (selectedFilter == 'Volunteers') targetRole = 'volunteer';
      if (selectedFilter == 'User') targetRole = 'user';
      if (selectedFilter == 'Admin') targetRole = 'admin';

      results = results.where((u) {
        // .trim() removes accidental spaces, .toLowerCase() makes it ignore capitals
        return u.role.trim().toLowerCase() == targetRole;
      }).toList();
    }

    // 2. Apply Text Search (Case-insensitive & space-trimmed)
    if (_searchQuery.trim().isNotEmpty) {
      final searchLower = _searchQuery.trim().toLowerCase();

      results = results.where((u) {
        final nameLower = u.name.trim().toLowerCase();
        final emailLower = u.email.trim().toLowerCase();
        final roleLower = u.role.trim().toLowerCase();

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

  // Helper to extract "DT" from "David Torres"
  String _getInitials(String name) {
    if (name.isEmpty) return "?";
    List<String> nameParts = name.trim().split(" ");
    if (nameParts.length > 1) {
      return (nameParts[0][0] + nameParts[1][0]).toUpperCase();
    }
    return nameParts[0][0].toUpperCase();
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
          _buildFilterChips(),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(_filters.length, (index) {
          final isSelected = _selectedFilterIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => {
                setState(() => _selectedFilterIndex = index),
                _applyFilters(),
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.borderGray,
                  ),
                ),
                child: Text(
                  _filters[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textBody,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

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
                    _buildRoleBadge(user.role),
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
                _buildStatusBadge(user.onlineStatus),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.more_vert, color: AppColors.textLight),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(UserModel user) {
    // Check if URL exists and is not empty
    bool hasImage = user.avatarUrl.isNotEmpty;

    return Stack(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.background,
          // Light Orange background for initials
          // If has image, show it. Otherwise, show nothing so the child text shows.
          backgroundImage: hasImage ? AssetImage(user.avatarUrl) : null,
          child: !hasImage
              ? Text(
                  _getInitials(user.name), // Dynamically generates initials!
                  style: const TextStyle(
                    color: Color(0xFFD92D20),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                )
              : null,
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

  Widget _buildRoleBadge(String role) {
    Color bgColor;
    Color textColor;
    switch (role) {
      case 'Admin':
        bgColor = const Color(0xFFD1E9FF);
        textColor = const Color(0xFF026AA2);
        break;
      case 'Volunteer':
        bgColor = const Color(0xFFF4EBFF);
        textColor = const Color(0xFF6941C6);
        break;
      default:
        bgColor = const Color(0xFFF2F4F7);
        textColor = const Color(0xFF344054);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    bool isActive =
        status.toLowerCase().contains('active') &&
        !status.toLowerCase().contains('inactive');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[
            const Icon(Icons.access_time, size: 12, color: AppColors.textLight),
            const SizedBox(width: 4),
          ],
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isActive ? AppColors.textSecondary : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
