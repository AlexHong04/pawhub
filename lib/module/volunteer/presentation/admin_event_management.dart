import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/core/widgets/appDecorations.dart';
import 'package:pawhub/core/widgets/filterButton.dart';
import 'package:pawhub/core/utils/qr_service.dart';
import 'package:pawhub/module/Volunteer/service/volunteerService.dart';
import '../../../core/widgets/search_field.dart';
import '../Model/event.dart';
import 'add_event.dart';

class AdminEventsPage extends StatefulWidget {
  const AdminEventsPage({super.key});

  @override
  State<AdminEventsPage> createState() => _AdminEventsPageState();
}

class _AdminEventsPageState extends State<AdminEventsPage> {
  // Data State
  List<Map<String, dynamic>> _allEvents = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  bool _isLoading = true;

  // Filter & Search State
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All';
  String _sortOption = 'Newest';

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  // ================= DATA LOADING & FILTERING =================

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> events = await EventService.getAllEvents();

      bool requiresRefresh = false;
      final DateTime now = DateTime.now();

      // Check for expired events
      for (var event in events) {
        if (event['event_status'] == 'Available' &&
            event['event_date'] != null &&
            event['start_time'] != null) {

          try {
            // Parse Date
            DateTime eventDate = DateTime.parse(event['event_date']);

            // Parse Time
            List<String> timeParts = event['start_time'].toString().split(':');
            int hour = int.parse(timeParts[0]);
            int minute = int.parse(timeParts[1]);

            DateTime eventStartDateTime = DateTime(
              eventDate.year,
              eventDate.month,
              eventDate.day,
              hour,
              minute,
            );

            if (now.isAfter(eventStartDateTime)) {
              await EventService.updateEvent(event['event_id'].toString(), {
                'event_status': 'Expired'
              });
              requiresRefresh = true;
            }
          } catch (e) {
            debugPrint("Error checking event expiration for ID ${event['event_id']}: $e");
          }
        }
      }

      if (requiresRefresh) {
        events = await EventService.getAllEvents();
      }

      if (mounted) {
        setState(() {
          _allEvents = events;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading events: $e', isError: true);
      }
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> results = List.from(_allEvents);

    // 1. Search Logic
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      results = results.where((e) {
        final title = (e['title'] ?? '').toLowerCase();
        final addr = (e['address'] ?? '').toLowerCase();
        return title.contains(query) || addr.contains(query);
      }).toList();
    }

    // 2. Status Filter Logic
    if (_selectedStatus != 'All') {
      results = results.where((e) => e['event_status'] == _selectedStatus).toList();
    }

    // 3. Sorting Logic
    switch (_sortOption) {
      case 'Soonest':
        results.sort((a, b) => DateTime.parse(a['event_date']).compareTo(DateTime.parse(b['event_date'])));
        break;
      case 'Oldest':
        results.sort((a, b) => DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));
        break;
      case 'Most Volunteers':
        results.sort((a, b) => (b['volunteer_capacity'] ?? 0).compareTo(a['volunteer_capacity'] ?? 0));
        break;
      case 'Newest':
      default:
        results.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
        break;
    }

    setState(() => _filteredEvents = results);
  }

  // ================= UI BUILDERS =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Event Management',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
      body: Column(
        children: [
          // Search & Sort Bar
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: CustomSearchField(
                    controller: _searchController,
                    onChanged: (_) => _applyFilters(),
                    hintText: 'Search event or location',
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
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

          // Status Filter Row
          _buildFilterRow(),

          // Listview
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filteredEvents.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _filteredEvents.length,
              itemBuilder: (context, index) => _buildEventCard(_filteredEvents[index]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddEventScreen()),
        ).then((_) => _loadEvents()),
        icon: const Icon(Icons.add, color: Colors.blue),
        label: const Text(
          "New Event",
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryLight,
        elevation: 0,
      ),
    );
  }

  Widget _buildFilterRow() {
    final statuses = ['All', 'Available', 'Expired'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: statuses.length,
          itemBuilder: (context, index) {
            final s = statuses[index];
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilterButton(
                text: s,
                isSelected: _selectedStatus == s,
                onPressed: () {
                  setState(() => _selectedStatus = s);
                  _applyFilters();
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // ================= MINIMALIST POPUP =================

  // ================= MINIMALIST POPUP =================

  void _showEventPopup(Map<String, dynamic> event) {
    final String eventId = event['event_id'] ?? '';
    final String title = event['title'] ?? '';
    final bool isExpired = event['event_status'] == 'Expired'; // ✅ Check if expired

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildMinimalRow(Icons.calendar_today_outlined, "Date", event['event_date']),
                      _buildMinimalRow(Icons.category_outlined, "Category", event['event_category']),
                      _buildMinimalRow(Icons.location_on_outlined, "Location", event['address']),
                      _buildMinimalRow(Icons.people_outline, "Capacity", "${event['volunteer_capacity']}"),
                    ],
                  ),
                ),
                const Divider(height: 32, indent: 24, endIndent: 24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      // ✅ Hide QR Generation if Expired
                      if (!isExpired) ...[
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => QRDialog(data: eventId, title: 'Event QR'),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: AppColors.primary),
                              foregroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                            label: const Text(
                              "Generate Event QR",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Volunteers still visible
                          _buildSmallAction(Icons.group, "Volunteers", Colors.blue, () {}),

                          // ✅ Hide Edit Button if Expired
                          if (!isExpired)
                            _buildSmallAction(Icons.edit, "Edit", Colors.orange, () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AddEventScreen(eventId: eventId)),
                              ).then((_) => _loadEvents());
                            }),

                          // Delete still visible
                          _buildSmallAction(Icons.delete, "Delete", Colors.red, () {
                            Navigator.pop(context);
                            _showDeleteConfirmation(eventId, title);
                          }),
                        ],
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

  // ================= HELPERS & COMPONENTS =================

  Widget _buildMinimalRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text("$label:", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? "-",
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    final options = ['Newest', 'Oldest', 'Soonest', 'Most Volunteers'];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: options
            .map(
              (o) => ListTile(
            leading: Icon(
              Icons.check,
              color: _sortOption == o ? AppColors.primary : Colors.transparent,
            ),
            title: Text(o),
            onTap: () {
              setState(() => _sortOption = o);
              _applyFilters();
              Navigator.pop(context);
            },
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final int capacity = event['volunteer_capacity'] ?? 0;
    final int spotLeft = event['spot_left'] ?? 0;
    final int joined = capacity - spotLeft;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showEventPopup(event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= IMAGE =================
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: _buildFlyerPreview(event['flyer_url']),
            ),

            // ================= CONTENT =================
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE + STATUS
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event['title'] ?? 'No Title',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(event['event_status']),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // CATEGORY + DATE
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _infoChip(Icons.category, event['event_category'] ?? 'Event'),
                      _infoChip(Icons.calendar_today, _formatDate(event['event_date'])),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ADDRESS
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event['address'] ?? 'No address',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ================= STATS =================
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _statItem("Joined", "$joined"),
                        _divider(),
                        _statItem("Capacity", "$capacity"),
                        _divider(),
                        _statItem("Left", "$spotLeft"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    final isAvailable = status == 'Available';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status ?? 'Expired',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isAvailable ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.grey[300],
    );
  }

  String _formatDate(String date) {
    try {
      final d = DateTime.parse(date);
      return DateFormat('dd MMM yyyy').format(d);
    } catch (_) {
      return date;
    }
  }

  Widget _buildFlyerPreview(String? flyerUrl) {
    if (flyerUrl == null || flyerUrl.trim().isEmpty) {
      return Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
      );
    }

    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.black.withOpacity(0.03),
      child: Image.network(
        flyerUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          height: 160,
          width: double.infinity,
          color: Colors.grey[100],
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 160,
            width: double.infinity,
            color: Colors.grey[100],
            child: const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_note, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text("No events match your criteria", style: TextStyle(color: Colors.grey[600])),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() => _selectedStatus = 'All');
              _applyFilters();
            },
            child: const Text("Clear Filters"),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String eventId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Event"),
        content: Text("Confirm deletion of '$title'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              bool success = await EventService.deleteEvent(eventId);
              if (success) _loadEvents();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}