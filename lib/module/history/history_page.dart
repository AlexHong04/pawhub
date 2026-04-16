import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';

class UserCollectionsPage extends StatelessWidget {
  const UserCollectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView( // Added scroll view in case screen is small
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // My Donations
              _buildManagementCard(
                context,
                title: "My Donations",
                subtitle: "View your contribution history",
                icon: Icons.volunteer_activism, // Heart-hand icon
                color: Colors.teal,
                onTap: () {
                  // Navigator.push(context, MaterialPageRoute(builder: (_) => MyDonationPage()));
                },
              ),

              const SizedBox(height: 16),

              // My Events
              _buildManagementCard(
                context,
                title: "My Events",
                subtitle: "Manage your volunteer sign-ups",
                icon: Icons.event_available,
                color: Colors.blueAccent,
                onTap: () {
                  // Navigator.push(context, MaterialPageRoute(builder: (_) => MyEventsPage()));
                },
              ),

              const SizedBox(height: 16),

              // 3. My Pets
              _buildManagementCard(
                context,
                title: "My Pets",
                subtitle: "Track your pet listings and status",
                icon: Icons.pets,
                color: AppColors.primary,
                onTap: () {
                  // Navigator.push(context, MaterialPageRoute(builder: (_) => MyPetsPage()));
                },
              ),

              const SizedBox(height: 16),

              //My Posts
              _buildManagementCard(
                context,
                title: "My Posts",
                subtitle: "View and edit your community stories",
                icon: Icons.dynamic_feed,
                color: Colors.orangeAccent,
                onTap: () {
                  // Navigator.push(context, MaterialPageRoute(builder: (_) => MyPostsPage()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagementCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.textDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.border),
      ),
    );
  }
}