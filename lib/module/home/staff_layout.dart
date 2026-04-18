import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../Profile/presentation/peopleAndRoles_page.dart';
import '../Profile/presentation/profile_page.dart';
import '../pet/presentation/pet_list_page.dart';
import '../petAdoption/presentation/adoption_application_list.dart';
import 'admin_dashboard_page.dart';

class StaffLayout extends StatefulWidget {
  const StaffLayout({super.key});

  @override
  State<StaffLayout> createState() => StaffLayoutState();
}

class StaffLayoutState extends State<StaffLayout> {
  // Set default index to 2 (Home Tab)
  int _selectedIndex = 2;

  // List of all the screens for each tab
  // Make sure the order matches your BottomNavigationBarItems!
  final List<Widget> _pages = [
    const Center(child: Text("Event Page")),
    // const Center(child: Text("Community Page")),
    const PeopleAndRolesPage(),
    const AdminDashboardPage(),
    const PetListPage(),
    const AdoptionApplicationListPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final hasPages = _pages.isNotEmpty;
    final safeIndex = hasPages ? _selectedIndex.clamp(0, _pages.length - 1) : 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      // IndexedStack keeps the state of your pages alive even when you switch tabs!
      body: hasPages
          ? IndexedStack(index: safeIndex, children: _pages)
          : const SizedBox.shrink(),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: NavigationBar(
              backgroundColor: AppColors.white,
              surfaceTintColor: Colors.transparent,
              indicatorColor: Colors.transparent,
              selectedIndex: safeIndex,
              height: 70,
              labelTextStyle:
                  WidgetStateProperty.resolveWith<TextStyle>((states) {
                final isSelected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 11,
                  color: isSelected ? AppColors.primary : AppColors.iconColor,
                );
              }),
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              onDestinationSelected: (index) {
                if (index < 0 || index >= _pages.length) return;
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.calendar_today, color: AppColors.iconColor, size: 24),
                  selectedIcon: Icon(Icons.calendar_today, color: AppColors.primary, size: 24),
                  label: "Event",
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline, color: AppColors.iconColor, size: 24),
                  selectedIcon: Icon(Icons.people_outline, color: AppColors.primary, size: 24),
                  label: "Community",
                ),
                NavigationDestination(
                  icon: Icon(Icons.home_outlined, color: AppColors.iconColor, size: 24),
                  selectedIcon: Icon(Icons.home, color: AppColors.primary, size: 24),
                  label: "Home",
                ),
                NavigationDestination(
                  icon: Icon(Icons.pets_outlined, color: AppColors.iconColor, size: 24),
                  selectedIcon: Icon(Icons.pets, color: AppColors.primary, size: 24),
                  label: "Pet",
                ),
                NavigationDestination(
                  icon: Icon(Icons.badge_outlined, color: AppColors.iconColor, size: 24),
                  selectedIcon: Icon(Icons.badge, color: AppColors.primary, size: 24),
                  label: "Adoption",
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline, color: AppColors.iconColor, size: 24),
                  selectedIcon: Icon(Icons.person, color: AppColors.primary, size: 24),
                  label: "Account",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}