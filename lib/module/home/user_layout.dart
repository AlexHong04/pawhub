import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'package:pawhub/module/home/user_dashboard.dart';
import 'package:pawhub/module/petAdoption/presentation/pet_adoption.dart';

import '../../core/constants/colors.dart';
import '../Profile/presentation/profile_page.dart';
import '../Volunteer/service/volunteerService.dart';
import '../communityPost/presentation/community_feed_page.dart';
import '../communityPost/presentation/post_details_page.dart';
import '../communityPost/service/post_service.dart';
import '../../app.dart';
import '../history/history_page.dart';
import '../volunteer/presentation/event_details.dart';
import '../volunteer/presentation/volunteerList.dart';

class UserLayout extends StatefulWidget {
  const UserLayout({super.key});

  @override
  State<UserLayout> createState() => UserLayoutState();
}

class UserLayoutState extends State<UserLayout> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  // Default to Home tab
  int _selectedIndex = 2;

  // Order must match destinations
  final List<Widget> _pages = [
    const VolunteerEventsPage(),
    const CommunityFeedPage(),
    const PetAdoptionHome(),
    const UserCollectionsPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  // Sets up listeners for Deep Links (e.g., when a user clicks a shared URL).
  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Handle cold start (App was completely closed and opened via a link)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null && mounted) {
        _handleNavigation(uri);
      }
    });

    // Handle background/foreground links (App was already running in the background)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (mounted) {
        _handleNavigation(uri);
      }
    });
  }

  // Parses the incoming URI and navigates to the appropriate screen.
  void _handleNavigation(Uri uri) async {
    if (uri.path.startsWith('/post/')) {
      // Extract the post ID from the end of the URL
      String postId = uri.pathSegments.last.trim();

      if (postId.isEmpty && uri.pathSegments.length >= 2) {
        postId = uri.pathSegments[uri.pathSegments.length - 2];
      }

      debugPrint("[DeepLink] Received navigation request, ID: $postId");

      final postService = PostService();
      final postModel = await postService.fetchPostById(postId);

      if (postModel != null && mounted) {
        // If the post exists, use the global navigator key to push the details page
        // over the current bottom navigation layout.
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => PostDetailsPage(post: postModel),
          ),
        );
      } else {
        debugPrint("DeepLink] Unable to find post data, ID: $postId");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Post not found or has been deleted.")),
          );
        }
      }
    }

    if (uri.path.startsWith('/event/')) {
      String eventId = uri.pathSegments.last.trim();
      final eventData = await EventService.getEventById(eventId);
      if (eventData != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EventDetailsPage(event: eventData)),
        );
      }
    }
  }
  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

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
        icon: Icon(Icons.history, color: AppColors.iconColor, size: 24),
        selectedIcon: Icon(Icons.history, color: AppColors.primary, size: 24),
        label: "History",
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
        icon: Icon(Icons.history, color: AppColors.iconColor),
        selectedIcon: Icon(Icons.history, color: AppColors.primary),
        label: Text("History"),
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
      body: Row(
        children: [
          if (isLandscape)
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
                    labelType: NavigationRailLabelType.none,
                    minWidth: 72,
                    useIndicator: true,
                    indicatorColor: AppColors.primary.withOpacity(0.12),
                    groupAlignment: 0.0, // Centers icons vertically
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
                  fontSize: 12,
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