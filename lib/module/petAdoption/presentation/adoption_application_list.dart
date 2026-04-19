import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pawhub/module/petAdoption/presentation/pet_adoption_details.dart';

import '../../../core/constants/colors.dart';
import '../../../core/utils/local_file_service.dart';
import '../../../core/utils/qr_service.dart';
import '../../../core/widgets/filterButton.dart';
import '../../../core/widgets/search_field.dart';
import '../model/adoption_application_model.dart';
import '../service/pet_adoption_service.dart';

class AdoptionApplicationListPage extends StatefulWidget {
  const AdoptionApplicationListPage({super.key});

  @override
  State<AdoptionApplicationListPage> createState() =>
      _AdoptionApplicationListState();
}

class _AdoptionApplicationListState extends State<AdoptionApplicationListPage> {
  final AdoptionService _adoptionService = AdoptionService();

  List<Application> _applications = [];
  Map<String, File?> _petImages = {};
  bool _isLoading = true;
  bool selectAll = false;
  Set<String> _selectedApplicationIds = {};

  String _activeFilter = "All";
  List<String> filters = ["All", "Approved", "Rejected", "Completed"];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Application> get _filteredApplications {
    List<Application> list = _applications.where((a) {
      bool matchesFilter = true;

      final status = (a.adoptionStatuses.isNotEmpty)
          ? a.adoptionStatuses.first.toLowerCase()
          : "unknown";

      matchesFilter = _activeFilter == "All"
          ? true
          : _activeFilter == "Approved"
          ? status == "approved"
          : _activeFilter == "Rejected"
          ? status == "rejected"
          : _activeFilter == "Completed"
          ? status == "completed"
          : true;

      final query = _searchQuery.trim().toLowerCase();

      final matchesSearch =
          a.petName.toLowerCase().contains(query) ||
              a.petGender.toLowerCase().contains(query) ||
              a.adoptionId.toLowerCase().contains(query);

      return matchesFilter && matchesSearch;
    }).toList();

    // ✅ Custom status priority order
    int getPriority(String status) {
      switch (status) {
        case "pending":
          return 0;
        case "approved":
          return 1;
        case "pending pickup":
          return 2;
        case "completed":
          return 3;
        case "rejected":
          return 4;
        default:
          return 5;
      }
    }

    // ✅ Sort list
    list.sort((a, b) {
      final statusA = a.adoptionStatuses.isNotEmpty
          ? a.adoptionStatuses.first.toLowerCase()
          : "";
      final statusB = b.adoptionStatuses.isNotEmpty
          ? b.adoptionStatuses.first.toLowerCase()
          : "";

      return getPriority(statusA).compareTo(getPriority(statusB));
    });

    return list;
  }

  void _toggleSelection(String adoptionId) {
    final application = _applications.firstWhere(
          (a) => a.adoptionId == adoptionId,
    );

    final status = application.adoptionStatuses.isNotEmpty
        ? application.adoptionStatuses.first.toLowerCase()
        : "";

    if (status != "pending") return;

    setState(() {
      if (_selectedApplicationIds.contains(adoptionId)) {
        _selectedApplicationIds.remove(adoptionId);
      } else {
        _selectedApplicationIds.add(adoptionId);
      }
    });
  }

  void _toggleSelectAll(bool? selected) {
    setState(() {
      selectAll = selected ?? false;
      if (selectAll) {
        _selectedApplicationIds = _applications
            .where(
              (a) =>
          a.adoptionStatuses.isNotEmpty &&
              a.adoptionStatuses.first.toLowerCase() == "pending",
        )
            .map((a) => a.adoptionId)
            .toSet();
      } else {
        _selectedApplicationIds.clear();
      }
    });
  }

  Future<void> _fetchApplications() async {
    setState(() => _isLoading = true);

    try {
      final data = await _adoptionService.fetchApplications();

      Map<String, File?> imageMap = {};

      for (var application in data) {
        String? firstImageName = (application.petImage.isNotEmpty)
            ? application.petImage
            .split(',')
            .first
            .trim()
            : null;

        if (firstImageName != null && firstImageName.isNotEmpty) {
          final file = await LocalFileService.loadSavedImage(firstImageName);
          imageMap[application.petId] = file;
        } else {
          imageMap[application.petId] = null;
        }
      }

      setState(() {
        _applications = data;
        _petImages = imageMap;
      });

      log('${_applications.length}');
    } catch (e) {
      log('Error fetching adoptions: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "approved":
        return Colors.green;

      case "rejected":
        return Colors.red;

      case "completed":
        return Colors.grey;

      case "pending pickup":
        return Colors.orange;

      case "pending":
      default:
        return Colors.blue;
    }
  }

  String _formatStatus(String status) {
    if (status.isEmpty) return "Unknown";

    return status
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() + e.substring(1) : '')
        .join(' ');
  }

  Future<void> _approveApplication() async {
    try {
      await _adoptionService.approveApplications(_selectedApplicationIds);

      await _fetchApplications();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Applications approved successfully')),
      );
      debugPrint("APPROVE IDS: $_selectedApplicationIds");

      setState(() {
        _selectedApplicationIds.clear();
        selectAll = false;
      });
    } catch (e) {
      log('Approve error: $e');
    }
  }

  Future<void> _rejectApplication() async {
    try {
      await _adoptionService.rejectApplications(_selectedApplicationIds);

      await _fetchApplications();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Applications rejected')));

      setState(() {
        _selectedApplicationIds.clear();
        selectAll = false;
      });
    } catch (e) {
      log('Reject error: $e');
    }
  }

  Future<void> _showApproveDialog() async {
    if (_selectedApplicationIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text("Approve Applications?"),
            content: Text(
              "Are you sure you want to approve ${_selectedApplicationIds
                  .length} application(s)?",
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            backgroundColor: Colors.white,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: AppColors.textLight),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                    "Approve", style: TextStyle(color: Colors.green)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _approveApplication();
    }
  }

  Future<void> _showRejectDialog() async {
    if (_selectedApplicationIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text("Reject Applications?"),
            content: Text(
              "Are you sure you want to reject ${_selectedApplicationIds
                  .length} application(s)? This action cannot be undone.",
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            backgroundColor: Colors.white,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: AppColors.textLight),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                    "Reject", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _rejectApplication();
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _fetchApplications();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    selectAll = false;
    _selectedApplicationIds.clear();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool hasPendingSelected = _selectedApplicationIds.any((id) {
      final app = _applications
          .where((a) => a.adoptionId == id)
          .firstOrNull;
      if (app == null) return false;
      final status = app.adoptionStatuses.isNotEmpty
          ? app.adoptionStatuses.first.toLowerCase()
          : "";
      return status == "pending";
    });

    if (_isLoading) {
      return const Scaffold(backgroundColor: AppColors.background,
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Adoption Application List",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16),
        child: Column(
          children: [
            _buildSearchBar(),
            _buildFilterSection(),
            const SizedBox(height: 6),
            _buildSelectionBar(hasPendingSelected),
            const SizedBox(height: 6),
            _buildApplicationList(),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationCard(Application application) {
    final imageUrl = application.petImage.isNotEmpty
        ? application.petImage
        .split(',')
        .first
        .trim()
        : null;

    final file = _petImages[application.petId];
    final status = application.adoptionStatuses.isNotEmpty
        ? application.adoptionStatuses.first.toLowerCase()
        : "";
    final isPending = status == "pending";

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AdoptionDetailsPage(adoptionId: application.adoptionId),
          ),
        );

        await _fetchApplications();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status + ID
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusBadge(status),
                  Text(
                    "#${application.adoptionId
                        .split('-')
                        .last}",
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selection Checkbox
                  Transform.scale(
                    scale: 0.9,
                    child: Checkbox(
                      value: _selectedApplicationIds.contains(
                        application.adoptionId,
                      ),
                      onChanged: isPending
                          ? (_) => _toggleSelection(application.adoptionId)
                          : null, // disables checkbox
                    ),
                  ),

                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 70,
                          height: 70,
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              if (file != null) {
                                return Image.file(
                                  file,
                                  fit: BoxFit.cover,
                                );
                              }
                              return Container(
                                color: Colors.grey[100],
                                child: const Icon(
                                  Icons.pets,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                              : file != null
                              ? Image.file(file, fit: BoxFit.cover)
                              : Container(
                            color: Colors.grey[100],
                            child: const Icon(
                              Icons.pets,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Details Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.petName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              application.petGender.toLowerCase() == 'male'
                                  ? Icons.male
                                  : Icons.female,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              application.petGender,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Applicant Info Row
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Applicant: ${application.userName}",
                              // Or application.userName
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              const Divider(height: 24, thickness: 0.5),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "APPLICATION DATE",
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textLight,
                          letterSpacing: 1,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(application.createdAt),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (status == "pending pickup")
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                QRScannerPage(id: application.adoptionId),
                          ),
                        );

                        if (result != null) {
                          debugPrint("Scanned QR: $result");

                          final success = await _adoptionService.confirmPickup(
                            data: result,
                          );

                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Pickup successfully"),
                              ),
                            );

                            await _fetchApplications();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Invalid QR / Adoption not found",
                                ),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text("SCAN QR"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return CustomSearchField(
      controller: _searchController,
      hintText: "Search pet name, gender, adoption id...",
      onChanged: (value) {
        setState(() => _searchQuery = value.toLowerCase());
      },
    );
  }

  Widget _buildFilterSection() {
    return SizedBox(
      width: double.infinity,
      child: RefreshIndicator(
        onRefresh: _fetchApplications,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((filter) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                child: FilterButton(
                  text: filter,
                  isSelected: _activeFilter == filter,
                  onPressed: () {
                    setState(() => _activeFilter = filter);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionBar(bool hasPendingSelected) {
    return Row(
      children: [
        Checkbox(value: selectAll, onChanged: _toggleSelectAll),
        const Text("Select All"),
        const Spacer(),

        if (hasPendingSelected) ...[
          _buildApproveButton(),
          const SizedBox(width: 12),
          _buildRejectButton(),
        ],
      ],
    );
  }

  Widget _buildApproveButton() {
    return ElevatedButton.icon(
      onPressed: _showApproveDialog,
      icon: const Icon(Icons.check_box_outlined, color: Colors.green),
      label: const Text(
        'Approve',
        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildRejectButton() {
    return ElevatedButton.icon(
      onPressed: _showRejectDialog,
      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
      label: const Text(
        'Reject',
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildApplicationList() {
    if (_isLoading) {
      return const Expanded(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_filteredApplications.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text("No applications found"),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        itemCount: _filteredApplications.length,
        itemBuilder: (context, index) {
          final application = _filteredApplications[index];
          return _buildApplicationCard(application);
        },
      ),
    );
  }

  Widget _buildCardHeader(Application application, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatusBadge(status),
        Text(
          "#${application.adoptionId
              .split('-')
              .last}",
          style: TextStyle(
            color: AppColors.textLight,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPetImage(String? imageUrl, File? file) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 70,
        height: 70,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            if (file != null) {
              return Image.file(file, fit: BoxFit.cover);
            }
            return _buildPlaceholder();
          },
        )
            : file != null
            ? Image.file(file, fit: BoxFit.cover)
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: const Icon(Icons.pets, color: Colors.grey),
    );
  }

  Widget _buildPetInfo(Application application) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            application.petName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              Icon(
                application.petGender.toLowerCase() == 'male'
                    ? Icons.male
                    : Icons.female,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(application.petGender),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(Icons.person_outline, size: 14),
              const SizedBox(width: 4),
              Text("Applicant: ${application.userName}"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardFooter(Application application, String status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("APPLICATION DATE", style: TextStyle(fontSize: 10)),
            const SizedBox(height: 4),
            Text(_formatDate(application.createdAt)),
          ],
        ),

        if (status == "pending pickup") _buildQRButton(application),
      ],
    );
  }

  Widget _buildQRButton(Application application) {
    return ElevatedButton.icon(
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QRScannerPage(id: application.adoptionId),
          ),
        );

        if (result != null) {
          final success = await _adoptionService.confirmPickup(data: result);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? "Pickup successfully"
                    : "Invalid QR / Adoption not found",
              ),
            ),
          );

          if (success) await _fetchApplications();
        }
      },
      icon: const Icon(Icons.qr_code_scanner, size: 18),
      label: const Text("SCAN QR"),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);

    // Define icons for each status
    IconData statusIcon;
    switch (status) {
      case "approved":
        statusIcon = Icons.check_circle_outline;
        break;
      case "rejected":
        statusIcon = Icons.highlight_off;
        break;
      case "completed":
        statusIcon = Icons.task_alt;
        break;
      case "pending pickup":
        statusIcon = Icons.local_shipping_outlined;
        break;
      default:
        statusIcon = Icons.hourglass_empty_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        // Subtle background
        borderRadius: BorderRadius.circular(8),
        // Modern slightly rounded corners
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            _formatStatus(status).toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
