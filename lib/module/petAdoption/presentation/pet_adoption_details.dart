import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/module/Profile/model/user_model.dart';
import 'package:pawhub/module/petAdoption/presentation/schedule_pickup_page.dart';

import '../../../core/utils/current_user_store.dart';
import '../../../core/utils/local_file_service.dart';
import '../../../core/utils/qr_service.dart';
import '../../../core/widgets/pet_card.dart';
import '../../../core/widgets/pet_info_cell.dart';
import '../../auth/model/auth_model.dart';
import '../../pet/model/pet_model.dart';
import '../model/adoption_application_model.dart';
import '../service/pet_adoption_service.dart';

class AdoptionDetailsPage extends StatefulWidget {
  final String adoptionId;

  const AdoptionDetailsPage({super.key, required this.adoptionId});

  @override
  State<AdoptionDetailsPage> createState() => _AdoptionDetailsState();
}

class _AdoptionDetailsState extends State<AdoptionDetailsPage> {
  final AdoptionService _adoptionService = AdoptionService();

  Application? _application;
  Pet? _pet;
  UserModel? _adoptionUser;
  File? _localImage;
  bool _isLoading = true;
  AuthModel? _user;
  DateTime? _pickup;

  @override
  void initState() {
    super.initState();
    _fetchAdoption();
    _fetchCurrentUser();
  }

  Future<AuthModel?> _fetchCurrentUser() async {
    try {
      final AuthModel? user = await CurrentUserStore.read();
      if (!mounted) return null;
      setState(() {
        _user = user;
      });
    } catch (e) {
      log('Error fetching current user: $e');
      setState(() => _isLoading = false);
    }
    return null;
  }

  Future<void> _fetchAdoption() async {
    setState(() => _isLoading = true);

    try {
      final result = await _adoptionService.fetchAdoptionDetails(
        widget.adoptionId,
      );

      if (result == null) {
        debugPrint('No adoption found');
        return;
      }

      final user = await _adoptionService.fetchAdoptionUser(
        result.application.userId,
      );

      String? firstImageName;

      if (result.pet.image.trim().isNotEmpty) {
        firstImageName = result.pet.image.split(',').first.trim();
      }

      File? file;

      if (firstImageName != null && firstImageName.isNotEmpty) {
        file = await LocalFileService.loadSavedImage(firstImageName);
      }

      final pickupDate = await _adoptionService.fetchPickupDate(
        result.application.adoptionId,
      );

      if (!mounted) return;

      setState(() {
        _application = result.application;
        _pet = result.pet;
        _adoptionUser = user;
        _localImage = file;
        _pickup = pickupDate;
      });
    } catch (e) {
      debugPrint('Error fetching adoption: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to fetch adoption: $e')));
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveApplication() async {
    try {
      final id = _application!.adoptionId;

      await _adoptionService.approveSingleApplication(id);

      await _fetchAdoption();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Applications approved successfully')),
      );
    } catch (e) {
      log('Approve error: $e');
    }
  }

  Future<void> _rejectApplication() async {
    try {
      final id = _application!.adoptionId;

      await _adoptionService.rejectSingleApplication(id);

      await _fetchAdoption();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Applications rejected')));
    } catch (e) {
      log('Reject error: $e');
    }
  }

  void _showDialog(String action) {
    final isApprove = action == 'Approve';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isApprove ? "Approve Application" : "Reject Application"),
          content: Text(
            isApprove
                ? "Are you sure you want to approve this application?"
                : "Are you sure you want to reject this application?",
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: AppColors.textLight),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);

                if (isApprove) {
                  await _approveApplication();
                } else {
                  await _rejectApplication();
                }
              },
              child: Text(
                isApprove ? "Approve" : "Reject",
                style: TextStyle(color: isApprove ? Colors.green : Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_application == null) {
      return const Scaffold(body: Center(child: Text("No adoption found")));
    }

    final lastStatus = _application!.adoptionStatuses.isNotEmpty
        ? _application!.adoptionStatuses.last.trim()
        : "";

    final today = DateTime.now();

    final isPickupToday =
        _pickup != null &&
        _pickup!.year == today.year &&
        _pickup!.month == today.month &&
        _pickup!.day == today.day;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          "Adoption Details",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_user?.role == 'Admin') _buildUserInfoCard(_adoptionUser!),
            _buildPetInfoCard(_pet!),
            const SizedBox(height: 10),
            _buildStatusTrackingCard(_application!.adoptionStatuses, _pickup),
            const SizedBox(height: 20),
            // ✅ FIXED: Only show Approve/Reject buttons if status is "Pending"
            if (_user?.role == 'Admin' &&
                lastStatus == 'Pending')  // ✅ Changed from .last to lastStatus
              _buildActionButtons()

            // ✅ Show Schedule button if user and status is "Approved"
            else if (_user?.role == 'User' &&
                lastStatus == 'Approved')  // ✅ Changed from .last to lastStatus
              _buildScheduleButton(),

            // ✅ Show QR button if user and status is "Pending Pickup" and today is pickup day
            if (_user?.role == 'User' &&
                lastStatus == "Pending Pickup" &&  // ✅ Changed from lastStatus to check against lastStatus
                isPickupToday)
              _buildGenerateQRButton(_application!.adoptionId),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTrackingCard(List<String> statuses, DateTime? pickup) {
    final pickupText = pickup != null
        ? DateFormat('yyyy-MM-dd').format(pickup)
        : 'Not scheduled yet';

    final Map<String, String> adoptionStatusDescriptions = {
      'Pending':
          "Your adoption application request submitted successfully. Waiting for admin approval.",
      'Approved':
          "Your adoption application has been approved, please schedule pickup.",
      'Rejected':
          "Unfortunately, your adoption application has been rejected, please try again.",
      'Pending Pickup':
          "Your pick up booking has been made.\n"
          "Pickup Schedule: $pickupText",
      'Completed': "Your pet has been picked up. Thanks!",
    };

    final Map<String, String> adminAdoptionStatusDescriptions = {
      'Pending':
          "User's adoption application request submitted successfully. Waiting for your approval.",
      'Approved':
          "User's adoption application has been approved, pending user schedule pickup.",
      'Rejected':
          "User's adoption application has been rejected.",
      'Pending Pickup': "User's pick up booking has been made.",
      'Completed': "Pet has been picked up. Thanks!",
    };

    final Map<String, Color> timelineStepColors = {
      'Pending': Color(0xFF74A9FF), // applied
      'Approved': Color(0xFF5F99F9), // approved
      'Pending Pickup': Color(0xFF2171F1), // pickup scheduled
      'Completed': Color(0xFF0047B9), // completed
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "Status Tracking",
            style: TextStyle(
              color: Colors.blueAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ...statuses.asMap().entries.map((entry) {
            final i = entry.key;
            final status = entry.value.trim(); // remove extra spaces
            final desc =
                (_user?.role == 'Admin'
                    ? adminAdoptionStatusDescriptions
                    : adoptionStatusDescriptions)[status] ??
                "";
            final formattedDate = DateFormat(
              'dd/MM/yyyy',
            ).format(DateTime.parse(_application!.createdAt));
            final color = timelineStepColors[status] ?? Colors.grey;

            return _buildTimelineStep(
              status,
              desc,
              formattedDate, // date (can be enhanced if you fetch created_at)
              color,
              true,
              isLast: i == statuses.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(UserModel user) {
    final avatarUrl = user.avatarUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 85,
              height: 85,
              child: (avatarUrl.isNotEmpty)
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.person, size: 40),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.person, size: 40),
                    ),
            ),
          ),

          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),

                Row(
                  children: [
                    const Icon(Icons.phone, size: 16),
                    const SizedBox(width: 6),
                    Text(user.contact),
                  ],
                ),

                const SizedBox(height: 4),

                Row(
                  children: [
                    const Icon(Icons.transgender, size: 16),
                    const SizedBox(width: 6),
                    Text(user.gender),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetInfoCard(Pet pet) {
    return PetCard(
      pet: pet,
      file: _localImage,
      onTap: null,
      showCheckbox: false,
      tableRows: [
        TableRow(
          children: [
            InfoCell(icon: Icons.cake, text: "${pet.age}"),
            InfoCell(icon: Icons.transgender, text: pet.gender),
          ],
        ),
        const TableRow(children: [SizedBox(height: 8), SizedBox(height: 8)]),
        TableRow(
          children: [
            InfoCell(icon: Icons.scale, text: "${pet.weight.toString()} kg"),
            InfoCell(icon: Icons.palette, text: pet.color),
          ],
        ),
        const TableRow(children: [SizedBox(height: 8), SizedBox(height: 8)]),
        TableRow(
          children: [
            InfoCell(
              icon: Icons.apartment,
              text: pet.health,
              textColor: Colors.green,
            ),
            InfoCell(
              icon: Icons.vaccines,
              text: pet.vaccination == true ? "Vaccinated" : "Not yet",
              textColor: Colors.blue,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimelineStep(
    String title,
    String desc,
    String date,
    Color color,
    bool isPassed, {
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: Colors.grey.shade300),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(
                      color: AppColors.textBody,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              _showDialog('Reject');
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Reject",
              style: TextStyle(color: Colors.black45),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              _showDialog('Approve');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Approve", style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SchedulePickupPage(adoptionId: _application!.adoptionId),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          "Schedule Pick Up",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildGenerateQRButton(String adoptionId) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => QRDialog(data: adoptionId, title: 'Pickup QR'),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        icon: const Icon(Icons.qr_code),
        label: const Text("Generate QR"),
      ),
    );
  }
}
