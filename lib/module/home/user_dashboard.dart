import 'package:flutter/material.dart';
import 'package:pawhub/module/pet/presentation/pet_details.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/widgets/search_field.dart';
import '../../core/widgets/filterButton.dart';
import '../../core/widgets/sorting.dart';
import '../pet/service/pet_service.dart';
import '../../../core/utils/qr_service.dart';
import '../communityPost/model/post_model.dart';
import '../communityPost/service/post_service.dart';
import '../communityPost/presentation/post_details_page.dart';

class PetAdoptionHome extends StatefulWidget {
  const PetAdoptionHome({super.key});

  @override
  State<PetAdoptionHome> createState() => _PetAdoptionHomeState();
}

class _PetAdoptionHomeState extends State<PetAdoptionHome> {
  final supabase = Supabase.instance.client;
  final PetService _petService = PetService();
  final PostService _postService = PostService();

  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> allPets = [];
  List<Map<String, dynamic>> filteredPets = [];

  String selectedSpecies = 'All';
  String searchQuery = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPets();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchPets() async {
    try {
      setState(() => isLoading = true);

      final pets = await _petService.userDashboardFetchPets();

      setState(() {
        allPets = pets;
        filteredPets = pets;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void applyFilter() {
    setState(() {
      filteredPets = allPets.where((p) {
        final query = searchQuery.trim().toLowerCase();
        final matchSpecies =
            selectedSpecies == 'All' ||
            p['species'].toString().toLowerCase() ==
                selectedSpecies.toLowerCase();
        final matchSearch = query.isEmpty
            ? true
            : ((p['name'] ?? '').toString().toLowerCase().contains(query) ||
                  (p['species'] ?? '').toString().toLowerCase().contains(
                    query,
                  ) ||
                  (p['age'] ?? '').toString().toLowerCase().contains(query) ||
                  (p['gender'] ?? '').toString().toLowerCase().contains(
                    query,
                  ) ||
                  (p['health_status'] ?? '').toString().toLowerCase().contains(
                    query,
                  ) ||
                  (p['vaccination_status'] == true &&
                      'vaccinated'.contains(query)) ||
                  (query == 'urgent' &&
                      DateTime.now()
                              .difference(DateTime.parse(p['created_at']))
                              .inDays >=
                          30));
        return matchSpecies && matchSearch;
      }).toList();
    });
  }

  void _processScannedData(String? scannedValue) async {
    if (scannedValue == null || !scannedValue.startsWith("pawhub://post/")) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid PawHub QR Code"),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final String postId = scannedValue.replaceFirst("pawhub://post/", "");

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Loading post...")));
    }

    try {
      final CommunityPostModel? targetPost = await _postService.fetchPostById(
        postId,
      );

      if (!mounted) return;

      if (targetPost != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailsPage(post: targetPost),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Post not found or deleted"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error loading post"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.only(bottom: 30, top: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.blue.shade600,
                  size: 22,
                ),
              ),
              title: const Text(
                'Scan with Camera',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const QRScannerPage(id: 'user_dashboard'),
                  ),
                );
                _processScannedData(result as String?);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_library_rounded,
                  color: Colors.green.shade600,
                  size: 22,
                ),
              ),
              title: const Text(
                'Pick from Gallery',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onTap: () async {
                Navigator.pop(context);
                final ImagePicker picker = ImagePicker();
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                );

                if (image != null) {
                  final MobileScannerController controller =
                      MobileScannerController();
                  final BarcodeCapture? capture = await controller.analyzeImage(
                    image.path,
                  );

                  if (capture != null && capture.barcodes.isNotEmpty) {
                    _processScannedData(capture.barcodes.first.rawValue);
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("No QR Code found in the image"),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                  controller.dispose();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "User Dashboard",
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.textDark,
            ),
            onPressed: _showScanOptions,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                // SEARCH + SORT ROW
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomSearchField(
                          controller: searchController,
                          hintText:
                              "Search pets by name, species, age, status...",
                          labelText: "Search",
                          onChanged: (value) {
                            searchQuery = value;
                            applyFilter();
                          },
                        ),
                      ),

                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.sort,
                            color: AppColors.primary,
                          ),
                          onPressed: _showSortOption,
                        ),
                      ),
                    ],
                  ),
                ),

                // FILTER ROW
                _buildFilterRow(),

                const SizedBox(height: 16),
                Expanded(
                  child: filteredPets.isEmpty
                      ? _buildEmptyState()
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio:
                                    0.68, // Adjusted for image + text + tags
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemCount: filteredPets.length,
                          itemBuilder: (context, index) =>
                              _buildPetCard(filteredPets[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterRow() {
    final speciesOptions = ["All", "Dog", "Cat"];
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: speciesOptions.length,
        itemBuilder: (context, index) {
          final s = speciesOptions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilterButton(
              text: s,
              isSelected: selectedSpecies == s,
              onPressed: () {
                setState(() => selectedSpecies = s);
                applyFilter();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPetCard(Map<String, dynamic> pet) {
    // Calculate Urgency
    final createdAtStr = pet['created_at'];
    bool isUrgent = false;
    if (createdAtStr != null) {
      final createdAt = DateTime.parse(createdAtStr);
      isUrgent = DateTime.now().difference(createdAt).inDays >= 30;
    }

    // Gender styling
    final String gender = pet['gender']?.toString() ?? 'Unknown';
    final bool isMale = gender.toLowerCase() == 'male';
    final Color genderColor = isMale ? Colors.blue : Colors.pink;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewPetDetailsPage(petId: pet['pet_id']),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // 👈 THIS is what you want
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  // 1. The Pet Image
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Image.network(
                        pet['image_url'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.inputFill,
                          child: const Icon(
                            Icons.pets,
                            color: AppColors.textPlaceholder,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. Urgent Banner Overlay
                  if (isUrgent)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.priority_high,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "URGENT",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 3. Gender Icon Overlay
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: Icon(
                        isMale ? Icons.male : Icons.female,
                        size: 16,
                        color: genderColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet['name'] ?? 'Unknown',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${pet['gender']} • ${pet['age']} yrs",
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 4, runSpacing: 4, children: _buildPetTags(pet)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPetTags(Map<String, dynamic> pet) {
    List<Widget> tags = [];
    if (pet['vaccination_status'] == true) {
      tags.add(_tagChip("Vaccinated", Colors.green, icon: Icons.verified_user));
    }

    final String status = pet['health_status']?.toString().toLowerCase() ?? '';
    if (status == "good") {
      tags.add(_tagChip("Good Health", Colors.teal, icon: Icons.check_circle));
    } else if (status == "fair") {
      tags.add(
        _tagChip("Fair Health", Colors.orange, icon: Icons.info_outline),
      );
    } else if (status == "poor") {
      tags.add(_tagChip("Needs Care", Colors.redAccent, icon: Icons.healing));
    }

    return tags;
  }

  Widget _tagChip(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 48,
            color: AppColors.textPlaceholder,
          ),
          const SizedBox(height: 12),
          const Text(
            "No pet match your search",
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showSortOption() {
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
                  filteredPets = SortUtils.sort(
                    filteredPets,
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
                  filteredPets = SortUtils.sort(
                    filteredPets,
                    by: 'created_at',
                    ascending: true,
                  );
                });
                Navigator.pop(context);
              },
            ),

            ListTile(
              leading: const Icon(Icons.pets),
              title: const Text("Age (Young → Old)"),
              onTap: () {
                setState(() {
                  filteredPets = SortUtils.sort(
                    filteredPets,
                    by: 'age',
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
