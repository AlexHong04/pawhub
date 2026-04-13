import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../Profile/presentation/profile_page.dart';

class UserLayout extends StatefulWidget {
  const UserLayout({super.key});

  @override
  State<UserLayout> createState() => UserLayoutState();
}

class UserLayoutState extends State<UserLayout> {
  // Set default index to 2 (Home Tab)
  int _selectedIndex = 2;

  // List of all the screens for each tab
  // Make sure the order matches your BottomNavigationBarItems!
  final List<Widget> _pages = [
    const Center(child: Text("Event Page")),
    const Center(child: Text("Community Page")),
    const Center(child: Text("Home Page")),
    const Center(child: Text("History Page")),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final hasPages = _pages.isNotEmpty;
    final safeIndex = hasPages ? _selectedIndex.clamp(0, _pages.length - 1) : 0;

    return Scaffold(
      // IndexedStack keeps page state alive when switching tabs.
      body: hasPages
          ? IndexedStack(index: safeIndex, children: _pages)
          : const SizedBox.shrink(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.iconColor,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        onTap: (index) {
          if (index < 0 || index >= _pages.length) return;
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: "Event",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: "Community",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "Account",
          ),
        ],
      ),
    );
  }
}
