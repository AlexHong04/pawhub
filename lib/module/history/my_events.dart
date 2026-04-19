import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/module/Volunteer/service/volunteerService.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/local_file_service.dart';
import '../../core/utils/qr_service.dart';
import '../../core/widgets/appDecorations.dart';
import '../../core/widgets/filterButton.dart';

class MyEventsPage extends StatefulWidget {
  final String userId;

  const MyEventsPage({super.key, required this.userId});

  @override
  State<MyEventsPage> createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  List<Map<String, dynamic>> _allJoinedEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    _fetchMyEvents();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchMyEvents();
    }
  }

  Future<void> _fetchMyEvents() async {
    final data = await EventService.getMyJoinedEvents(widget.userId);

    List<String> eventsToMarkIncomplete = [];
    DateTime now = DateTime.now();

    for (var item in data) {
      if (item['joinned_status'] == 'Upcoming' &&
          item['check_in_time'] == null) {

        final event = item['Event'];

        if (event != null && event['event_date'] != null) {
          try {
            DateTime eventDate =
            DateTime.parse(event['event_date']).toLocal();

            String endTimeStr = event['end_time'] ?? "23:59:59";

            List<String> timeParts = endTimeStr.split(':');
            int hour = int.parse(timeParts[0]);
            int minute = int.parse(timeParts[1]);
            int second = timeParts.length > 2
                ? int.parse(timeParts[2].split('.')[0])
                : 0;

            DateTime eventEndTime = DateTime(
              eventDate.year,
              eventDate.month,
              eventDate.day,
              hour,
              minute,
              second,
            );

            print("NOW: $now");
            print("EVENT END: $eventEndTime");

            if (now.isAfter(eventEndTime)) {
              eventsToMarkIncomplete.add(item['event_id'].toString());
            }

          } catch (e) {
            debugPrint("Error processing event ${item['event_id']}: $e");
          }
        }
      }
    }

    if (eventsToMarkIncomplete.isNotEmpty) {
      await EventService.bulkUpdateStatus(
        userId: widget.userId,
        eventIds: eventsToMarkIncomplete,
        newStatus: 'Incomplete',
      );

      final updatedData =
      await EventService.getMyJoinedEvents(widget.userId);

      if (mounted) {
        setState(() {
          _allJoinedEvents = updatedData;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _allJoinedEvents = data;
          _isLoading = false;
        });
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  // ==========================================
  // ADDED: CANCEL REGISTRATION LOGIC
  // ==========================================
  void _confirmCancelRegistration(String eventId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Registration"),
        content: Text("Are you sure you want to cancel your registration for '$title'? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close the dialog
              _showLoadingDialog(); // Show loader while processing

              bool success = await EventService.cancelRegistration(eventId, widget.userId);

              if (mounted) Navigator.pop(context); // Hide loader

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Registration cancelled successfully"), backgroundColor: Colors.green),
                );
                _fetchMyEvents(); // Refresh the list to remove it
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Failed to cancel registration"), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCertificatePreview({String? url, File? file}) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER SECTION
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
                child: Row(
                  children: [
                    const Text(
                      "Certificate Preview",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),

              // IMAGE CONTAINER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: file != null
                        ? Image.file(file, fit: BoxFit.contain)
                        : Image.network(
                      url!,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator.adaptive())),
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        child: const Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),

              // BUTTON ROW
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    // SHARE BUTTON (SECONDARY)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final File? target = file ?? await EventService.downloadFromUrl(url!);
                          if (target != null) {
                            await Share.shareXFiles([XFile(target.path)]);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text("Share"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // PDF BUTTON (PRIMARY)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final File? target = file ?? await EventService.downloadFromUrl(url!);
                          if (target != null) {
                            await EventService.exportAsPDF(target);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: const Text("Export PDF"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("My Event", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildStatsHeader(),
          const SizedBox(height: 10),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEventList('Upcoming'),
                _buildEventList('Completed'),
                _buildEventList('Incomplete'),
                _buildEventList('Cancelled'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    int totalEvents =
        _allJoinedEvents.where((e) => e['check_in_time'] != null).length;
    int totalHours =
        _allJoinedEvents.where((e) => e['check_in_time'] != null).length * 2;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _statCard("Total Events Joined", totalEvents.toString(),
              Icons.calendar_today, Colors.blue),
          const SizedBox(width: 16),
          _statCard("Hours Contributed", totalHours.toString(),
              Icons.access_time, Colors.blue),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color.withOpacity(0.6)),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value,
                style:
                const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: 45,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildFilterButtonItem("Upcoming", 0),
            const SizedBox(width: 8),
            _buildFilterButtonItem("Completed", 1),
            const SizedBox(width: 8),
            _buildFilterButtonItem("Incomplete", 2),
            const SizedBox(width: 8),
            _buildFilterButtonItem("Cancelled", 3),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButtonItem(String title, int index) {
    return FilterButton(
      text: title,
      isSelected: _tabController.index == index,
      onPressed: () {
        setState(() {
          _tabController.animateTo(index);
        });
      },
    );
  }

  Widget _buildEventList(String tabType) {
    List<Map<String, dynamic>> filtered = _allJoinedEvents.where((item) {
      if (tabType == 'Upcoming') {
        return item['check_in_time'] == null &&
            item['joinned_status'] == 'Upcoming';
      }
      if (tabType == 'Completed') {
        return item['check_in_time'] != null;
      }
      if (tabType == 'Incomplete') {
        return item['joinned_status'] == 'Incomplete';
      }
      if (tabType == 'Cancelled') {
        return item['joinned_status'] == 'Cancelled';
      }
      return false;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "No $tabType events found.",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final data = filtered[index];
        final event = data['Event'];
        bool isCompleted = tabType == 'Completed';
        final String eventId = data['event_id'].toString();
        final String eventTitle = event?['title'] ?? 'Event';

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: _buildImageHandler(event?['flyer_url']),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (event?['location_name'] != null)
                      _iconInfo(Icons.location_on, event['location_name']),
                    if (event?['event_date'] != null)
                      _iconInfo(
                          Icons.calendar_month, _formatDate(event['event_date'])),
                    if (event?['start_time'] != null &&
                        event?['end_time'] != null)
                      _iconInfo(
                        Icons.access_time,
                        _formatTime(event['start_time'], event['end_time']),
                      ),
                    if (!isCompleted) ...[
                      const Divider(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Registration Date",
                              style: TextStyle(color: Colors.grey)),
                          Text(
                            data['rigistration_datetime'] != null
                                ? _formatDate(
                                data['rigistration_datetime'].toString())
                                : 'Not registered',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Registration Status",
                              style: TextStyle(color: Colors.grey)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: data['joinned_status'] == 'Upcoming'
                                  ? Colors.orange.withOpacity(0.2)
                                  : data['joinned_status'] == 'Incomplete'
                                  ? Colors.red.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              data['joinned_status'] ?? 'Pending',
                              style: TextStyle(
                                color: data['joinned_status'] == 'Upcoming'
                                    ? Colors.orange
                                    : data['joinned_status'] == 'Incomplete'
                                    ? Colors.red
                                    : Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (tabType == 'Upcoming') ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: data['check_in_time'] != null
                                ? null
                                : () {
                              _openCheckInScanner(eventId);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: data['check_in_time'] != null
                                  ? Colors.grey
                                  : Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  data['check_in_time'] != null
                                      ? Icons.check_circle
                                      : Icons.qr_code_scanner,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  data['check_in_time'] != null
                                      ? "Checked In: ${_formatCheckInTime(data['check_in_time'])}"
                                      : "Scan to Check In",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ==========================================
                        // ADDED: CANCEL REGISTRATION BUTTON
                        // ==========================================
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _confirmCancelRegistration(eventId, eventTitle),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text(
                              "Cancel Registration",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      // Completed section
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Check-in Time",
                              style: TextStyle(color: Colors.grey)),
                          Text(
                            data['check_in_time'] != null
                                ? _formatCheckInTime(data['check_in_time'])
                                : 'N/A',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            if (data['certificate_url'] != null && data['certificate_url'].toString().isNotEmpty) {
                              _showCertificatePreview(url: data['certificate_url']);
                            }
                            else {
                              _showLoadingDialog();
                              try {
                                String? newUrl = await EventService.generateAndUploadCertificate(
                                  userId: widget.userId,
                                  eventId: eventId,
                                  eventTitle: eventTitle,
                                );

                                if (mounted) Navigator.pop(context); // close dialog

                                if (newUrl != null) {
                                  setState(() { data['certificate_url'] = newUrl; });
                                  _showCertificatePreview(url: newUrl);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Failed to generate or upload certificate.")),
                                  );
                                }
                              } catch (e) {
                                if (mounted) Navigator.pop(context); // close dialog on error
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.blue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            data['certificate_url'] != null ? "View Certificate" : "Generate Certificate",
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ),
                      )
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageHandler(String? filename) {
    if (filename == null || filename.isEmpty) {
      return const Icon(Icons.pets, color: Colors.grey, size: 30);
    }

    return Image.network(
      filename.startsWith('http') ? filename : 'assets/images/$filename',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: const Icon(Icons.broken_image, color: Colors.grey, size: 50),
    );
  }

  Widget _iconInfo(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Date TBD';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day} ${_getMonthAbbreviation(date.month)} ${date.year}';
    } catch (_) {
      return dateString;
    }
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  String _formatCheckInTime(String? timeString) {
    if (timeString == null) return 'N/A';
    try {
      final time = DateTime.parse(timeString);
      int hour = time.hour;
      int minute = time.minute;
      String ampm = hour >= 12 ? 'PM' : 'AM';

      hour = hour % 12;
      if (hour == 0) hour = 12; // Handle midnight and noon

      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return timeString;
    }
  }

  String _formatTime(String? start, String? end) {
    String formatSingleTime(String t) {
      try {
        final parts = t.split(':');
        if (parts.length >= 2) {
          int h = int.parse(parts[0]);
          int m = int.parse(parts[1]);
          String ampm = h >= 12 ? 'PM' : 'AM';

          h = h % 12;
          if (h == 0) h = 12;

          return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
        }
      } catch (_) {}
      return t.length >= 5 ? t.substring(0, 5) : t;
    }

    if (start == null) return 'Time TBD';
    String s = formatSingleTime(start);
    if (end == null) return s;
    String e = formatSingleTime(end);

    return '$s - $e';
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _openCheckInScanner(String eventId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerPage(id: eventId),
      ),
    );

    if (result == null) return;

    final qrCode = result.toString();

    if (qrCode != eventId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid QR code for this event"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate check-in
    final validation = await EventService.validateCheckIn(eventId, widget.userId);

    if (!(validation['canCheckIn'] as bool)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation['message'])),
      );
      return;
    }

    final now = DateTime.now().toIso8601String();

    final success = await EventService.updateJoinedEventAttendance(
      userId: widget.userId,
      eventId: eventId,
      checkInTime: now,
      joinedStatus: 'completed',
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Check-in successful"),
          backgroundColor: Colors.green,
        ),
      );

      _fetchMyEvents();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Check-in failed")),
      );
    }
  }
}