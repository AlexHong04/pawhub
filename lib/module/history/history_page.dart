import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/module/history/donation_history_page.dart';
import 'package:pawhub/module/history/my_posts_page.dart';
import 'package:pawhub/module/history/pet_adoption_history.dart';
import 'package:pawhub/module/donation/presentation/donation_page.dart';
import '../Volunteer/service/volunteerService.dart';
import 'my_events.dart';

class UserCollectionsPage extends StatelessWidget {
  const UserCollectionsPage({super.key});

  Future<String?> _getUserId() async {
    return await EventService.getCurrentUserId();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getUserId(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userId = snapshot.data!;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text("My Event", style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                children: [

                  _buildManagementCard(
                    context,
                    title: "My Events",
                    subtitle: "Manage your volunteer sign-ups",
                    icon: Icons.event_available,
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MyEventsPage(userId: userId),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildManagementCard(
                    context,
                    title: "My Donations",
                    subtitle: "View your contribution history",
                    icon: Icons.volunteer_activism,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => DonationHistoryPage()));
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
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AdoptionHistoryPage()));
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildManagementCard(
                    context,
                    title: "My Posts",
                    subtitle: "View and edit your community stories",
                    icon: Icons.dynamic_feed,
                    color: Colors.orangeAccent,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => MyPostsPage()));
                    },
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.push(context,MaterialPageRoute(builder: (context) => const DonationPage()),
              );
            },
            backgroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Icon(
              Icons.favorite,
              color: Colors.red,
              size: 32,
            ),
          ),
        );
      },
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
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}