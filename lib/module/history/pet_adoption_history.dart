import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pawhub/core/utils/local_file_service.dart';
import 'package:pawhub/module/petAdoption/presentation/pet_adoption_details.dart';
import 'package:pawhub/module/petAdoption/presentation/schedule_pickup_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/colors.dart';
import '../../core/utils/current_user_store.dart';
import '../../core/utils/qr_service.dart';
import '../../core/widgets/filterButton.dart';
import '../../core/widgets/pet_card.dart';
import '../../core/widgets/pet_info_cell.dart';
import '../../core/widgets/search_field.dart';
import '../auth/model/auth_model.dart';
import '../pet/model/pet_model.dart';
import '../petAdoption/model/adoption_application_model.dart';
import '../petAdoption/service/pet_adoption_service.dart';

class AdoptionHistoryPage extends StatefulWidget {
  // final String userId;

  // const AdoptionHistoryPage({super.key, required this.userId});
  const AdoptionHistoryPage({super.key});

  @override
  State<AdoptionHistoryPage> createState() => _AdoptionHistoryState();
}

class _AdoptionHistoryState extends State<AdoptionHistoryPage> {
  final AdoptionService _adoptionService = AdoptionService();

  List<PetAdoption> _pets = [];
  Map<String, File?> _petImages = {};
  Map<String, DateTime?> _pickupDates = {};

  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _activeFilter = "All";
  List<String> filters = ["All", "Applied", "Approved", "Past"];

  List<PetAdoption> get _filteredPetAdoptions {
    return _pets.where((adoption) {
      bool matchesFilter = true;

      if (_activeFilter == "Applied") {
        matchesFilter = adoption.adoptionStatus == "Pending";
      } else if (_activeFilter == "Approved") {
        matchesFilter =
            adoption.adoptionStatus == "Approved" ||
            adoption.adoptionStatus == "Pending Pickup";
      } else if (_activeFilter == "Past") {
        matchesFilter = adoption.adoptionStatus == "Completed";
      }

      final query = _searchQuery.toLowerCase();

      bool matchesSearch =
          query.isEmpty ||
          adoption.pet.name.toLowerCase().contains(query) ||
          adoption.adoptionId.toLowerCase().contains(query);

      return matchesFilter && matchesSearch;
    }).toList();
  }

  Future<void> _fetchPetAdoptions() async {
    setState(() => _isLoading = true);

    try {
      final AuthModel? user = await CurrentUserStore.read();
      if (!mounted) return null;
      final pets = await _adoptionService.fetchUserPetAdoptions(user!.id);

      Map<String, File?> imageMap = {};

      for (var application in pets) {
        String? firstImageName = (application.pet.image.isNotEmpty)
            ? application.pet.image.split(',').first.trim()
            : null;

        if (firstImageName != null && firstImageName.isNotEmpty) {
          try {
            final file = await LocalFileService.loadSavedImage(firstImageName);
            imageMap[application.pet.id] = file;
          } catch (e) {
            imageMap[application.pet.id] = null;
          }
        } else {
          imageMap[application.pet.id] = null;
        }

        try {
          final date = await _adoptionService.getPickupDate(
            adoptionId: application.adoptionId,
          );
          log("AdoptionId: ${application.adoptionId}");
          log("PickupDate RAW: $date");

          if (date != null) {
            log("PickupDate LOCAL: ${date.toLocal()}");
          }

          _pickupDates[application.adoptionId] = date;
        } catch (e) {
          _pickupDates[application.adoptionId] = null;
        }
      }

      setState(() {
        _pets = pets;
        _petImages = imageMap;
      });
    } catch (e) {
      log('Error fetching pet adoptions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _fetchPetAdoptions();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _activeFilter = 'All';
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          "Adoption Application History",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16),
        child: Column(
          children: [
            // Search Bar
            CustomSearchField(
              controller: _searchController,
              hintText: "Search pet name, adoption id...",
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),

            // Filter Buttons
            Wrap(
              spacing: 10,
              children: filters.map((filter) {
                return FilterButton(
                  text: filter,
                  isSelected: _activeFilter == filter,
                  onPressed: () {
                    setState(() => _activeFilter = filter);
                  },
                );
              }).toList(),
            ),

            SizedBox(height: 10),

            // Pet List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchPetAdoptions,
                child: ListView.builder(
                  itemCount: _filteredPetAdoptions.length,
                  itemBuilder: (context, index) {
                    final pet = _filteredPetAdoptions[index];

                    String normalizedStatus = pet.adoptionStatus.trim();

                    Map<String, String> adoptionStatusColor = {
                      'Pending': '0xFF2B85EC',
                      'Approved': '0xFF36D43E',
                      'Pending Pickup': '0xFF36D43E',
                      'Completed': '0xFF36D43E',
                    };

                    String? colorHex =
                        adoptionStatusColor[normalizedStatus] ?? '0xFFB0B0B0';
                    Color statusColor = Color(int.parse(colorHex));

                    final pickupDate = _pickupDates[pet.adoptionId];
                    final today = DateTime.now();

                    return PetCard(
                      pet: pet.pet,
                      file: _petImages[pet.pet.id],
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AdoptionDetailsPage(adoptionId: pet.adoptionId),
                          ),
                        );

                        await _fetchPetAdoptions();
                      },
                      trailingStatus: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              pet.adoptionStatus,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),
                        ],
                      ),
                      tableRows: [
                        TableRow(
                          children: [
                            InfoCell(
                              icon: Icons.cake,
                              text: "${pet.pet.age} years",
                            ),
                            InfoCell(
                              icon: Icons.transgender_outlined,
                              text: pet.pet.gender,
                            ),
                          ],
                        ),
                        const TableRow(
                          children: [SizedBox(height: 8), SizedBox(height: 8)],
                        ),
                        TableRow(
                          children: [
                            InfoCell(
                              icon: Icons.scale,
                              text: "${pet.pet.weight} kg",
                            ),
                            InfoCell(icon: Icons.palette, text: pet.pet.color),
                          ],
                        ),
                        const TableRow(
                          children: [SizedBox(height: 8), SizedBox(height: 8)],
                        ),
                        TableRow(
                          children: [
                            InfoCell(
                              icon: Icons.local_hospital_outlined,
                              text: pet.pet.health,
                              textColor: pet.pet.health == "Good"
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            InfoCell(
                              icon: Icons.vaccines,
                              text: pet.pet.vaccination
                                  ? "Vaccinated"
                                  : "Not yet",
                              textColor: pet.pet.vaccination
                                  ? Colors.blue
                                  : Colors.orange,
                            ),
                          ],
                        ),
                      ],
                      bottomWidget: Column(
                        children: [
                          const SizedBox(height: 20),

                          if (pet.adoptionStatus.trim() == "Approved")
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SchedulePickupPage(
                                        adoptionId: pet.adoptionId,
                                      ),
                                    ),
                                  );

                                  await _fetchPetAdoptions();
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.calendar_month,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      "Schedule pickup",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 12,
                                      color: Colors.blue,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          if (pet.adoptionStatus.trim() == "Pending Pickup" &&
                              pickupDate != null &&
                              isSameDate(pickupDate, today))
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await showDialog(
                                    context: context,
                                    builder: (_) => QRDialog(
                                      data: pet.adoptionId,
                                      title: 'Pickup QR',
                                    ),
                                  );

                                  await _fetchPetAdoptions();
                                },
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
                                icon: const Icon(Icons.qr_code),
                                label: const Text("Generate QR"),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
