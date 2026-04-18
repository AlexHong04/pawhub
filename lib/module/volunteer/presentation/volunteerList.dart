import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/module/volunteer/service/volunteerService.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pawhub/module/volunteer/presentation/share_helper.dart';
import 'dart:io';

import '../../../core/widgets/filterButton.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/sorting.dart';
import 'event_details.dart';

class VolunteerEventsPage extends StatefulWidget {
  const VolunteerEventsPage({super.key});

  @override
  State<VolunteerEventsPage> createState() => _VolunteerEventsPageState();
}

class _VolunteerEventsPageState extends State<VolunteerEventsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> _allEvents = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> events;
      if (_selectedCategory != 'All') {
        events = await EventService.getEventsByCategory(_selectedCategory);
      } else {
        events = await EventService.getAllEvents();
      }
      setState(() {
        _allEvents = events;
        _filteredEvents = events;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading events: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterEvents(String query) {
    setState(() {
      _filteredEvents = _allEvents.where((event) {
        final title = event['title']?.toLowerCase() ?? '';
        final address = event['address']?.toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();
        return searchQuery.isEmpty ||
            title.contains(searchQuery) ||
            address.contains(searchQuery);
      }).toList();
    });
  }

  void _selectCategory(String category) async {
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
    });
    await _loadEvents();
    _searchController.clear();
  }

  // --- Image Handlers ---

  Future<bool> _assetImageExists(String filename) async {
    try {
      await DefaultAssetBundle.of(context).load('assets/images/$filename');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> _getLocalImagePath(String filename, String folderName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final filePath = '${appDir.path}/$folderName/$filename';
      final file = File(filePath);
      return await file.exists() ? filePath : null;
    } catch (e) {
      return null;
    }
  }

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
            'Volunteer Events',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: CustomSearchField(
                    controller: _searchController,
                    onChanged: _filterEvents,
                    hintText: 'Search event or location',
                  ),
                ),

                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.sort, color: AppColors.primary),
                    onPressed: _showSortOptions,
                  ),
                ),
              ],
            ),
          ),
          _buildFilterRow(),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredEvents.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredEvents.length,
              itemBuilder: (context, index) {
                return _buildResponsiveEventCard(_filteredEvents[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final categories = ['All', 'Community Awareness', 'Medical Camps', 'Rescue Activities'];
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final c = categories[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterButton(
              text: c,
              isSelected: _selectedCategory == c,
              onPressed: () => _selectCategory(c),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResponsiveEventCard(Map<String, dynamic> event) {
    final int remainingSpots = event['spot_left'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EventDetailsPage(event: event)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 120, // Consistent fixed width for the side image
                  child: _buildImageHandler(event['flyer_url']),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 32),
                              child: Text(
                                event['title'] ?? 'Event Title',
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildIconText(Icons.location_on_outlined, event['address'] ?? 'Location'),
                            _buildIconText(Icons.calendar_today_outlined, _formatDate(event['event_date'])),
                            _buildIconText(Icons.access_time, _formatTime(event['start_time'], event['end_time'])),
                            const SizedBox(height: 10),
                            _buildSpotsBadge(remainingSpots),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.share_outlined, size: 20, color: AppColors.iconColor),
                          onPressed: () => ShareHelper.shareEvent(
                            event: event,
                            formattedDate: _formatDate(event['event_date']),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpotsBadge(int remainingSpots) {
    bool isLow = remainingSpots <= 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isLow ? Colors.red : AppColors.primary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$remainingSpots spots left',
        style: TextStyle(
          color: isLow ? Colors.redAccent : AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildIconText(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageHandler(String? filename) {
    if (filename == null || filename.isEmpty) return _buildPlaceholder();

    if (filename.startsWith('http')) {
      return Image.network(filename, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder());
    }

    return FutureBuilder<bool>(
      future: _assetImageExists(filename),
      builder: (context, assetSnapshot) {
        if (assetSnapshot.data == true) {
          return Image.asset('assets/images/$filename', fit: BoxFit.cover);
        }
        return FutureBuilder<String?>(
          future: _getLocalImagePath(filename, 'flyers'),
          builder: (context, localSnapshot) {
            if (localSnapshot.hasData && localSnapshot.data != null) {
              return Image.file(File(localSnapshot.data!), fit: BoxFit.cover);
            }
            return _buildPlaceholder();
          },
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.borderGray,
      child: const Icon(Icons.broken_image, color: Colors.white),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.event_busy, size: 50, color: AppColors.textPlaceholder),
          SizedBox(height: 10),
          Text('No events found', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // --- Formatting Helpers ---

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Date TBD';
    try {
      final date = DateTime.parse(dateString);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) { return dateString; }
  }

  String _formatTime(String? start, String? end) {
    if (start == null) return 'Time TBD';
    String s = start.length >= 5 ? start.substring(0, 5) : start;
    if (end == null) return s;
    String e = end.length >= 5 ? end.substring(0, 5) : end;
    return '$s - $e';
  }


  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            ListTile(
              leading: const Icon(Icons.new_releases),
              title: const Text("Newest First"),
              onTap: () {
                setState(() {
                  _filteredEvents = SortUtils.sort(
                    _filteredEvents,
                    by: 'created_at',
                    ascending: false,
                  );
                });
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text("Oldest First"),
              onTap: () {
                setState(() {
                  _filteredEvents = SortUtils.sort(
                    _filteredEvents,
                    by: 'created_at',
                    ascending: true,
                  );
                });
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.pets),
              title: const Text("Least Spots Left"),
              onTap: () {
                setState(() {
                  _filteredEvents = SortUtils.sort(
                    _filteredEvents,
                    by: 'spot_left',
                    ascending: true,
                  );
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}