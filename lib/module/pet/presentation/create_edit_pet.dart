import 'dart:developer';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/module/pet/service/pet_service.dart';

import '../../../core/utils/generatorId.dart';
import '../../../core/utils/local_file_service.dart';
import '../../../core/utils/supabase_file_service.dart';
import '../../../core/widgets/appDecorations.dart';
import '../../../core/widgets/custom_dropdown_field.dart';
import '../../../core/widgets/custom_text_field.dart';

class CreateEditPetPage extends StatefulWidget {
  final String? petId;

  const CreateEditPetPage({super.key, this.petId});

  @override
  State<CreateEditPetPage> createState() => _PetDetailsState();
}

class _PetDetailsState extends State<CreateEditPetPage> {
  final PetService _petService = PetService();

  bool _isLoading = false;

  bool get isEditMode => widget.petId != null;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  List<File> _newImageFiles = [];
  Map<int, File?> _localImages = {};

  List<String> _originalImageUrls = [];
  List<String> _currentImageUrls = [];
  Set<String> _deletedImageUrls = {};

  final ImagePicker _picker = ImagePicker();

  String _selectedGender = 'Male';
  String _selectedSpecies = 'Dog';
  String _selectedHealth = 'Good';
  String _selectedVaccination = 'Vaccinated';

  final _formKey = GlobalKey<FormState>();

  bool _isEdit = false;

  void _onFieldChanged() {
    if (!_isEdit) {
      setState(() => _isEdit = true);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.petId != null) {
      _fetchPetDetails();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    _colorCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? val) {
    if (val == null || val.trim().isEmpty) return 'Required';

    final regex = RegExp(r'^[a-zA-Z\s]+$');
    if (!regex.hasMatch(val.trim())) {
      return 'Only letters allowed';
    }

    return null;
  }

  String? _validateColor(String? val) {
    if (val == null || val.trim().isEmpty) return 'Required';

    final regex = RegExp(r'^[a-zA-Z\s]+$');
    if (!regex.hasMatch(val.trim())) {
      return 'Only letters allowed';
    }

    return null;
  }

  String? _validateNumber(String? val, {String field = 'Value'}) {
    if (val == null || val.trim().isEmpty) return 'Required';

    // prevent "..", ".", etc
    if (val.contains('..') || val == '.') {
      return 'Invalid number format';
    }

    final number = double.tryParse(val);
    if (number == null) {
      return 'Must be a number';
    }

    if (number <= 0) {
      return '$field must be > 0';
    }

    return null;
  }

  bool _hasAtLeastOneImage() {
    return _currentImageUrls.isNotEmpty;
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      try {
        final index = _currentImageUrls.length;

        final savedFile = await LocalFileService.storeImageLocally(
          widget.petId ?? 'temp',
          pickedFile.path,
          'pet_images',
          'pet_images',
          index: index,
        );

        if (savedFile != null) {
          setState(() {
            _newImageFiles.add(savedFile);
            _currentImageUrls.add(savedFile.path);
            _onFieldChanged();
          });
        }
      } catch (e) {
        debugPrint('Error picking image: $e');
      }
    }
  }

  Future<void> _fetchPetDetails() async {
    setState(() => _isLoading = true);

    try {
      final data = await _petService.fetchPetDetails(widget.petId!);

      _nameCtrl.text = data.name;
      _weightCtrl.text = data.weight.toString();
      _ageCtrl.text = data.age.toString();
      _colorCtrl.text = data.color;
      _descCtrl.text = data.description;

      _selectedGender = data.gender;
      _selectedSpecies = data.species;
      _selectedHealth = data.health;

      _selectedVaccination = data.vaccination ? 'Vaccinated' : 'Not Yet Vaccinated';

      final urls = data.image
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
      setState(() {
        _originalImageUrls = List.from(urls);
        _currentImageUrls = List.from(urls);
        _localImages = localMap;
        _newImageFiles.clear();
        _deletedImageUrls.clear();
      });

      log('Image url $_currentImageUrls');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e'))
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePetDetails() async {
    if (widget.petId == null) return;
    if (!_formKey.currentState!.validate()) return;
    if (!_hasAtLeastOneImage()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please keep at least one photo')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      List<String> finalImages = [];

      // compare with original and current to identify the removed one
      final removedImages = _originalImageUrls
          .where((url) => !_currentImageUrls.contains(url))
          .toList();

      for (final url in removedImages) {
        try {
          String fileName;

          if (url.startsWith('http')) {
            // removes everything after ?
            final cleanUrl = url.split('?').first;

            // get the last part after the last /
            fileName = cleanUrl.split('/').last;

          } else {
            fileName = url.split('/').last;
          }

          await SupabaseFileService.deleteImage(
            bucketName: 'documents',
            folderPath: 'pet_images',
            fileName: fileName,
          );

          debugPrint('Successfully deleted from storage: $fileName');
        } catch (e) {
          debugPrint('Error deleting $url: $e');
        }
      }

      // keep only images that are in both current AND original
      finalImages.addAll(
          _currentImageUrls.where((url) => _originalImageUrls.contains(url))
      );

      // upload new images
      int startIndex = _originalImageUrls.length;

      for (int i = 0; i < _newImageFiles.length; i++) {
        try {
          final fileName = '${widget.petId}-${startIndex + i}';

          debugPrint('Uploading image $i as: $fileName');

          final result = await SupabaseFileService.uploadImage(
            imageFile: _newImageFiles[i],
            bucketName: 'documents',
            folderPath: 'pet_images',
            fileNamePrefix: fileName,
          );

          if (result != null) {
            finalImages.add(result);
            debugPrint('Uploaded: $fileName -> $result');
          }
        } catch (e) {
          debugPrint('Error uploading image $i: $e');
          rethrow;
        }
      }

      // update to db
      await _petService.updatePet(
        petId: widget.petId!,
        name: _nameCtrl.text,
        age: double.tryParse(_ageCtrl.text) ?? 0,
        weight: double.tryParse(_weightCtrl.text) ?? 0,
        color: _colorCtrl.text,
        gender: _selectedGender,
        species: _selectedSpecies,
        healthStatus: _selectedHealth,
        vaccinationStatus: _selectedVaccination == 'Vaccinated',
        images: finalImages,
        description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pet updated successfully!'))
      );

      setState(() {
        _currentImageUrls = finalImages;
        _originalImageUrls = List.from(finalImages);
        _newImageFiles.clear();
        _deletedImageUrls.clear();
        _isEdit = false;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating: $e'))
      );
      debugPrint('Update error: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createPet() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasAtLeastOneImage()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one photo')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String newPetId = await GeneratorId.generateId(
        tableName: 'Pet',
        idColumnName: 'pet_id',
        prefix: 'P',
        numberLength: 5,
      );

      List<String> uploadedImages = [];

      if (_newImageFiles.isNotEmpty) {
        for (int i = 0; i < _newImageFiles.length; i++) {
          final originalName = path.basenameWithoutExtension(_newImageFiles[i].path);
          final extension = path.extension(_newImageFiles[i].path);

          final fileName = '${newPetId}-$i\_$originalName$extension';

          final result = await SupabaseFileService.uploadImage(
            imageFile: _newImageFiles[i],
            bucketName: 'documents',
            folderPath: 'pet_images',
            fileNamePrefix: fileName,
          );

          uploadedImages.add(result!);
        }
      }

      await _petService.createPet(
        petId: newPetId,
        name: _nameCtrl.text,
        species: _selectedSpecies,
        gender: _selectedGender,
        age: double.tryParse(_ageCtrl.text) ?? 0,
        weight: double.tryParse(_weightCtrl.text) ?? 0,
        color: _colorCtrl.text,
        healthStatus: _selectedHealth,
        vaccinationStatus: _selectedVaccination == 'Vaccinated',
        images: uploadedImages,
        description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pet created successfully!'))
      );

      setState(() {
        _isEdit = false;
        _currentImageUrls = uploadedImages;
        _originalImageUrls = List.from(uploadedImages);
        _newImageFiles.clear();
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating pet: $e'))
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showDiscardDialog() async {
    if (!_isEdit) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Keep Editing',
              style: TextStyle(color: Colors.black45),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _currentImageUrls.length + 1,
            itemBuilder: (context, index) {
              // ADD BUTTON
              if (index == _currentImageUrls.length) {
                return GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                  ),
                );
              }

              final image = _currentImageUrls[index];
              final file = _localImages[index];
              final isOriginal = _originalImageUrls.contains(image);

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 85,
                        height: 85,
                        child: image.startsWith('http')
                            ? Image.network(
                          image,
                          fit: BoxFit.cover,
                        )
                            : Image.file(
                          File(image),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    if (isOriginal)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(200),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Original',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            final removedUrl = _currentImageUrls[index];

                            if (isOriginal) {
                              _deletedImageUrls.add(removedUrl);  // ✅ Track deletion
                              debugPrint('Marking for deletion: $removedUrl');
                            }

                            _currentImageUrls.removeAt(index);
                            _localImages.remove(index);

                            _localImages = {
                              for (int i = 0; i < _currentImageUrls.length; i++)
                                i: _localImages[i]
                            };

                            _onFieldChanged();
                          });
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () async {
            if (await _showDiscardDialog()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          isEditMode ? 'Update Pet' : 'Add New Pet',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Pet Information',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildImageSection(),
                _buildBasicInfoSection(),
                _buildAttributesSection(),
                _buildDescriptionSection(),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      children: [
        CustomTextField(
          controller: _nameCtrl,
          onChanged: (_) => _onFieldChanged(),
          label: "Name",
          hint: "e.g. Paul",
          icon: Icons.badge_outlined,
          validator: _validateName,
        ),

        CustomTextField(
          controller: _ageCtrl,
          onChanged: (_) => _onFieldChanged(),
          label: "Age (years)",
          hint: "e.g. 0.5",
          icon: Icons.history_toggle_off_outlined,
          keyboardType: TextInputType.number,
          validator: (val) => _validateNumber(val, field: 'Age'),
        ),
      ],
    );
  }

  Widget _buildAttributesSection() {
    return Column(
      children: [
        CustomDropdownField(
          label: 'Gender',
          icon: Icons.transgender,
          value: _selectedGender,
          items: const ['Male', 'Female'],
          onChanged: (val) {
            setState(() => _selectedGender = val!);
            _onFieldChanged();
          },
        ),

        CustomDropdownField(
          label: 'Species',
          icon: Icons.pets_outlined,
          value: _selectedSpecies,
          items: const ['Dog', 'Cat'],
          onChanged: (val) {
            setState(() => _selectedSpecies = val!);
            _onFieldChanged();
          },
        ),

        CustomTextField(
          controller: _weightCtrl,
          onChanged: (_) => _onFieldChanged(),
          label: "Weight (kg)",
          hint: "e.g. 18",
          icon: Icons.scale_outlined,
          keyboardType: TextInputType.number,
          validator: (val) => _validateNumber(val, field: 'Weight'),
        ),

        CustomTextField(
          controller: _colorCtrl,
          onChanged: (_) => _onFieldChanged(),
          label: "Color",
          hint: "e.g. Brown",
          icon: Icons.palette_outlined,
          validator: _validateColor,
        ),

        CustomDropdownField(
          label: 'Health Status',
          icon: Icons.health_and_safety_outlined,
          value: _selectedHealth,
          items: const ['Good', 'Fair', 'Poor'],
          onChanged: (val) {
            setState(() => _selectedHealth = val!);
            _onFieldChanged();
          },
        ),

        CustomDropdownField(
          label: 'Vaccination Status',
          icon: Icons.vaccines_outlined,
          value: _selectedVaccination,
          items: const ['Vaccinated', 'Not Yet Vaccinated'],
          onChanged: (val) {
            setState(() => _selectedVaccination = val!);
            _onFieldChanged();
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return CustomTextField(
      controller: _descCtrl,
      onChanged: (_) => _onFieldChanged(),
      label: "Description",
      hint: "Tell us about the pet...",
      icon: Icons.description_outlined,
      maxLines: 3,
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () async {
            if (await _showDiscardDialog()) {
              Navigator.of(context).pop();
            }
          },
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.black45),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _currentImageUrls.isEmpty
              ? null
              : (isEditMode ? _updatePetDetails : _createPet),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            isEditMode ? 'Update' : 'Create',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}