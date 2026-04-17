import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pawhub/module/pet/presentation/pet_details.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/local_file_service.dart';
import '../../../core/widgets/filterButton.dart';
import '../../../core/widgets/pet_card.dart';
import '../../../core/widgets/pet_info_cell.dart';
import '../../../core/widgets/search_field.dart';
import '../model/pet_model.dart';
import '../pet_routes.dart';
import '../service/pet_service.dart';
import 'create_edit_pet.dart';

class PetListPage extends StatefulWidget {
  const PetListPage({super.key});

  @override
  State<PetListPage> createState() => _PetListPageState();
}

class _PetListPageState extends State<PetListPage> {
  final PetService _petService = PetService();

  List<Pet> _pets = [];
  Map<String, File?> _petImages = {};
  bool _isLoading = true;
  bool selectAll = false;
  Set<String> _selectedPetIds = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _activeFilter = "All";
  List<String> filters = ["All", "Dog", "Cat", "Adopted"];

  List<Pet> get _filteredPets {
    return _pets.where((pet) {
      bool matchesFilter = true;

      if (_activeFilter == "Dog") {
        matchesFilter = pet.species.toLowerCase() == "dog";
      } else if (_activeFilter == "Cat") {
        matchesFilter = pet.species.toLowerCase() == "cat";
      } else if (_activeFilter == "Adopted") {
        matchesFilter = pet.adopted == true;
      }

      final query = _searchQuery.trim().toLowerCase();

      bool matchesSearch = query.isEmpty ||
          pet.name.toLowerCase().contains(query) ||
          pet.species.toLowerCase().contains(query) ||
          pet.gender.toLowerCase().contains(query);

      return matchesFilter && matchesSearch;
    }).toList();
  }

  void _toggleSelection(String petId) {
    setState(() {
      if (_selectedPetIds.contains(petId)) {
        _selectedPetIds.remove(petId);
      } else {
        _selectedPetIds.add(petId);
      }
    });
  }

  void _toggleSelectAll(bool? selected) {
    setState(() {
      selectAll = selected ?? false;
      if (selectAll) {
        _selectedPetIds = _filteredPets.map((p) => p.id).toSet();
      } else {
        _selectedPetIds.clear();
      }
    });
  }

  Future<void> _fetchPets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _petService.fetchAllPets();

      final pets = (data as List)
          .map((item) => Pet.fromJson(item as Map<String, dynamic>))
          .toList();

      Map<String, File?> imageMap = {};

      for (var p in pets) {
        String? firstImageName = (p.image.isNotEmpty)
            ? p.image.split(',').first.trim()
            : null;

        if (firstImageName != null && firstImageName.isNotEmpty) {
          final file = await LocalFileService.loadSavedImage(firstImageName);
          imageMap[p.id] = file;
        } else {
          imageMap[p.id] = null;
        }
      }

      setState(() {
        _pets = pets;
        _petImages = imageMap;
        _selectedPetIds.clear();
      });
    } catch (e) {
      log('Error fetching pets: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to fetch pets: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    _fetchPets();
    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    selectAll = false;
    _selectedPetIds.clear();
    _searchController.dispose();
    super.dispose();
  }

  void _showDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Pet(s)?"),
          content: Text(
            "Are you confirming to delete ${_selectedPetIds.length} pets?",
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "No, Discard",
                style: TextStyle(color: AppColors.textDark),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _petService.softDeletePets(_selectedPetIds.toList());

                  Navigator.pop(context);

                  setState(() {
                    _pets.removeWhere(
                      (pet) => _selectedPetIds.contains(pet.id),
                    );
                    _selectedPetIds.clear();
                    selectAll = false;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pet(s) deleted successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  log("Delete error: $e");
                }
              },
              child: const Text(
                "Yes, Delete",
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  Color getHealthColor(String health) {
    switch (health) {
      case "Good":
        return Colors.green;
      case "Fair":
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(title: Text("Pet List", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),), centerTitle: true),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search Bar
            CustomSearchField(
              controller: _searchController,
              hintText: "Search pet name, gender, species...",
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),

            // Filter Buttons
            Wrap(
              spacing: 20,
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

            Row(
              children: [
                Checkbox(value: selectAll, onChanged: _toggleSelectAll),
                const Text("Select All"),
                const Spacer(),

                if (_selectedPetIds.isEmpty)
                  IconButton(onPressed: () async {
                    // await Navigator.pushNamed(context, '/create_edit_pet');

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateEditPetPage(),
                      ),
                    );
                    await _fetchPets();
                  }, icon: const Icon(Icons.add)),

                if (_selectedPetIds.length == 1)
                  IconButton(
                    onPressed: () async {
                      final selectedPet = _pets.firstWhere(
                        (p) => _selectedPetIds.contains(p.id),
                      );
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateEditPetPage(petId: selectedPet.id),
                        ),
                      );
                      // await Navigator.pushNamed(
                      //   context,
                      //   '/create_edit_pet',
                      //   arguments: selectedPet.id,
                      // );
                      await _fetchPets();
                      log("Editing: ${selectedPet.name}");
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),

                if (_selectedPetIds.isNotEmpty)
                  IconButton(
                    onPressed: _showDialog,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),

            SizedBox(height: 10),

            // Pet List
            Expanded(
              child: ListView.builder(
                itemCount: _filteredPets.length,
                itemBuilder: (context, index) {
                  final pet = _filteredPets[index];
                  final imageFile = _petImages[pet.id];

                  return PetCard(
                    pet: pet,
                    file: imageFile,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ViewPetDetailsPage(petId: pet.id),
                        ),
                          // Navigator.pushNamed(context, '/pet_details');
                      );

                      _fetchPets();
                    },

                    showCheckbox: true,
                    isSelected: _selectedPetIds.contains(pet.id),
                    onSelect: () => _toggleSelection(pet.id),
                    trailingStatus: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: pet.gender == "Male"
                            ? Color(0xFFE8F0FF)
                            : Color(0xFFFFE8E8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        pet.gender,
                        style: TextStyle(
                          color: Colors.black,
                        ),
                      ),
                    ),
                    tableRows: [
                      TableRow(
                        children: [
                          InfoCell(
                            icon: Icons.cake,
                            text: "${pet.age} years",
                          ),
                          InfoCell(
                            icon: Icons.local_hospital,
                            text: pet.health,
                            textColor: getHealthColor(pet.health),
                          ),
                        ],
                      ),
                      const TableRow(
                        children: [SizedBox(height: 8), SizedBox(height: 8)],
                      ),
                      TableRow(
                        children: [
                          InfoCell(
                            icon: Icons.volunteer_activism,
                            text: pet.adopted ? "Adopted" : "Not yet",
                          ),
                          InfoCell(
                            icon: Icons.vaccines,
                            text: pet.vaccination ? "Vaccinated" : "Not yet",
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
