import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/core/utils/current_user_store.dart';
import 'package:pawhub/module/auth/model/auth_model.dart';
import 'package:pawhub/module/petAdoption/presentation/pet_adoption.dart';

import '../../../core/utils/local_file_service.dart';
import '../model/pet_model.dart';
import '../service/pet_service.dart';
import 'create_edit_pet.dart';

class ViewPetDetailsPage extends StatefulWidget {
  final String petId;

  const ViewPetDetailsPage({super.key, required this.petId});

  @override
  State<ViewPetDetailsPage> createState() => _ViewPetDetailsPageState();
}

class _ViewPetDetailsPageState extends State<ViewPetDetailsPage> {
  final PetService _petService = PetService();

  Pet? _pet;
  AuthModel? _user;
  bool _isLoading = true;
  Map<int, File?> _localImages = {};
  List<String> _imageUrls = [];

  @override
  void initState() {
    super.initState();
    _fetchPet();
    _fetchCurrentUser();
  }

  Future<void> _fetchPet() async {
    setState(() => _isLoading = true);

    try {
      final pet = await _petService.fetchPetDetails(widget.petId);

      final urls = pet.image
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      Map<int, File?> localMap = {};

      for (int i = 0; i < urls.length; i++) {
        try {
          final file = await LocalFileService.loadSavedImage(
            urls[i].split('/').last,
          );
          localMap[i] = file;
        } catch (_) {
          localMap[i] = null;
        }
      }

      if (!mounted) return;

      setState(() {
        _pet = pet;
        _imageUrls = urls;
        _localImages = localMap;
        _isLoading = false;
      });
    } catch (e) {
      log('Error fetching pet: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<AuthModel?> _fetchCurrentUser() async {
    try {
      final AuthModel? user = await CurrentUserStore.read();
      if (!mounted) return null;
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      log('Error fetching current user: $e');
      setState(() => _isLoading = false);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _pet == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(),
                      const SizedBox(height: 24),
                      _buildAttributeGrid(),
                      const SizedBox(height: 24),
                      const Text(
                        "About Me",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _pet!.description.isEmpty
                            ? "No description provided."
                            : _pet!.description,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 100), // Space for bottom button
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 350,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: (_imageUrls.isNotEmpty)
            ? PageView.builder(
                itemCount: _imageUrls.length,
                itemBuilder: (context, index) {
                  final imageName = _imageUrls[index];
                  final file = _localImages[index];
                  return Image.network(
                    imageName,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },

                    errorBuilder: (context, error, stackTrace) {
                      // fallback → local storage
                      if (file != null && file.existsSync()) {
                        return Image.file(file, fit: BoxFit.cover);
                      }

                      // final fallback
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.pets, size: 80),
                      );
                    },
                  );
                },
              )
            : Container(
                color: Colors.grey[200],
                child: const Icon(Icons.pets, size: 80, color: Colors.grey),
              ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _pet!.name,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Icon(
                  Icons.pets_outlined,
                  size: 16,
                  color: Colors.blueAccent[100],
                ),
                const SizedBox(width: 4),
                Text(
                  _pet!.species,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          ],
        ),
        _buildHealthBadge(),
      ],
    );
  }

  Widget _buildHealthBadge() {
    Color color = _pet!.health == "Good" ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        _pet!.health,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAttributeGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.2,
      // adjust for size
      children: [
        _attributeTile(Icons.cake, "Age", "${_pet!.age} yrs"),
        _attributeTile(Icons.transgender, "Gender", _pet!.gender),
        _attributeTile(Icons.scale, "Weight", "${_pet!.weight} kg"),
        _attributeTile(Icons.palette_outlined, "Color", _pet!.color),
        _attributeTile(Icons.local_hospital, "Health", _pet!.health),
        _attributeTile(
          Icons.vaccines,
          "Vaccinated",
          _pet!.vaccination ? "Yes" : "No",
        ),
      ],
    );
  }

  Widget _attributeTile(IconData icon, String label, String value) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () async{
            if (_user?.role == 'Admin') {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateEditPetPage(petId: _pet!.id),
                ),
              );
              await _fetchPet();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PetAdoptionPage(petId: _pet!.id, userId: _user!.id,),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: Text(
            _user?.role == 'Admin' ? "Edit Pet Profile" : "Adopt Me Now",
            // _isAdmin ? "Edit Pet Profile" : "Adopt Me Now",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
