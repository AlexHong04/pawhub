import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../Profile/presentation/profile_page.dart';
import '../pet/presentation/pet_list_page.dart';
import '../petAdoption/presentation/adoption_application_list.dart';
import '../volunteer/presentation/admin_event_management.dart';
import 'admin_dashboard_page.dart';

class StaffLayout extends StatefulWidget {
  const StaffLayout({super.key});

  @override
  State<StaffLayout> createState() => StaffLayoutState();
}

class StaffLayoutState extends State<StaffLayout> {
  // Default to Home tab
  int _selectedIndex = 2;

  // Order must match destinations
  final List<Widget> _pages = [
    const AdminEventsPage(),
    const Center(child: Text("Community Page")),
    const Center(child: Text("Event Page")),
    const Center(child: Text("Community Page")),
    const AdminDashboardPage(),
    const PetListPage(),
    const AdoptionApplicationListPage(),
    const ProfilePage(),
  ];

  void _onDestinationSelected(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() => _selectedIndex = index);
  }

  List<NavigationDestination> _bottomDestinations() {
    return const [
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
    ];
  }

  List<NavigationRailDestination> _railDestinations() {
    return const [
      NavigationRailDestination(
        icon: Icon(Icons.calendar_today, color: AppColors.iconColor),
        selectedIcon: Icon(Icons.calendar_today, color: AppColors.primary),
        label: Text("Event"),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.people_outline, color: AppColors.iconColor),
        selectedIcon: Icon(Icons.people_outline, color: AppColors.primary),
        label: Text("Community"),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.home_outlined, color: AppColors.iconColor),
        selectedIcon: Icon(Icons.home, color: AppColors.primary),
        label: Text("Home"),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.pets_outlined, color: AppColors.iconColor),
        selectedIcon: Icon(Icons.pets, color: AppColors.primary),
        label: Text("Pet"),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.badge_outlined, color: AppColors.iconColor),
        selectedIcon: Icon(Icons.badge, color: AppColors.primary),
        label: Text("Adoption"),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.person_outline, color: AppColors.iconColor),
        selectedIcon: Icon(Icons.person, color: AppColors.primary),
        label: Text("Account"),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hasPages = _pages.isNotEmpty;
    final safeIndex = hasPages ? _selectedIndex.clamp(0, _pages.length - 1) : 0;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (!hasPages) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: isLandscape
          ? Row(
        children: [
          SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
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
                borderRadius: BorderRadius.circular(24),
                child: NavigationRail(
                  backgroundColor: AppColors.white,
                  selectedIndex: safeIndex,
                  onDestinationSelected: _onDestinationSelected,
                  labelType: NavigationRailLabelType.none, // icon-only in landscape
                  minWidth: 72,
                  useIndicator: true,
                  indicatorColor: AppColors.primary.withOpacity(0.12),
                  destinations: _railDestinations(),
                ),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: safeIndex,
              children: _pages,
            ),
          ),
        ],
      )
          : IndexedStack(
        index: safeIndex,
        children: _pages,
      ),
      bottomNavigationBar: isLandscape
          ? null
          : SafeArea(
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
              labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
                final isSelected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 11,
                  color: isSelected ? AppColors.primary : AppColors.iconColor,
                );
              }),
              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
              onDestinationSelected: _onDestinationSelected,
              destinations: _bottomDestinations(),
            ),
          ),
        ),
      ),
    );
  }
}