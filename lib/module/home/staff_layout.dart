import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import 'admin_home_page.dart';

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
    const Center(child: Text("Community Page")),
    const AdminHomePage(),
    const Center(child: Text("Pet Page")),
    const Center(child: Text("Adoption Page")),
    const Center(child: Text("Account Page")),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps the state of your pages alive even when you switch tabs!
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.iconColor,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: "Event"),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: "Community"),
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Home"),
          // BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.pets_outlined), activeIcon: Icon(Icons.pets), label: "Pet"),
          BottomNavigationBarItem(icon: Icon(Icons.badge_outlined), activeIcon: Icon(Icons.badge), label: "Adoption"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: "Account"),
        ],
      ),
    );
  }
}