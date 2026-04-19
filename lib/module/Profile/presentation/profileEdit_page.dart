import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/core/widgets/app_snackbar.dart';
import 'package:pawhub/core/utils/local_file_service.dart';
import 'package:pawhub/core/widgets/appDecorations.dart';
import 'package:pawhub/module/Profile/model/user_model.dart';
import 'package:pawhub/module/Profile/service/profile_service.dart';
import 'package:pawhub/module/auth/service/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../volunteer/model/OSMPlace.dart';
import '../../volunteer/service/OSMService.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  static const List<String> _genderOptions = <String>[
    'Male',
    'Female',
  ];

  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  // final genderController = TextEditingController();
  final contactController = TextEditingController();
  final locationController = TextEditingController();
  File? _selectedImage;
  String? _selectedGender;
  String? _currentAvatarUrl;
  String? _userId;
  bool loading = false;
  List<OSMPlace> _suggestions = [];
  OSMPlace? _selectedPlace;
  String _initialLocation = '';
  bool _locationEdited = false;
  Timer? _debounce;

  Future<void> _exitEditPage() async {
    bool reachedLayoutRoute = false;
    Navigator.popUntil(context, (route) {
      final routeName = route.settings.name;
      if (routeName == '/user_layout' || routeName == '/staff_layout') {
        reachedLayoutRoute = true;
        return true;
      }
      return route.isFirst;
    });

    if (!reachedLayoutRoute) {
      final currentUser = await AuthService.getStoredCurrentUser();
      final targetRoute = currentUser?.role == 'Admin' ? '/staff_layout' : '/user_layout';
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, targetRoute, (route) => false);
    }
  }
  Future<void> _onSearchChanged(String value) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 800), () async {
      if (value.isEmpty) {
        setState(() => _suggestions.clear());
        return;
      }

      try {
        final results = await OSMService.searchPlaces(value);

        if (!mounted) return;

        setState(() {
          _suggestions = results;
        });
      } catch (e) {
        print("Search error: $e");
      }
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    // genderController.dispose();
    contactController.dispose();
    locationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      setState(() => loading = false);
      return;
    }

    final userId = currentUser.id;
    final avatarStorageKey = profileAvatarStorageKey(userId);

    final UserModel? profileData = await ProfileService.getCurrentUserProfile();

    if (!mounted) return;

    if (profileData != null) {
      if (profileData.avatarUrl.isNotEmpty) {
        await LocalFileService.cacheRemoteUrl(avatarStorageKey, profileData.avatarUrl);
      }

      setState(() {
        _userId = profileData.id;
        nameController.text = profileData.name;
        emailController.text = profileData.email;
        _selectedGender = profileData.gender.isEmpty ? null : profileData.gender;
        contactController.text = profileData.contact;
        locationController.text = profileData.address;
        _initialLocation = profileData.address.trim();
        _locationEdited = false;
        _selectedPlace = null;

        _currentAvatarUrl = profileData.avatarUrl;
        _selectedImage = null;
        loading = false;
      });
    } else {
      setState(() {
        _userId = userId;
        _currentAvatarUrl = null;
        loading = false;
      });

      AppSnackBar.show(context, message: 'Network error. Loading offline avatar.', backgroundColor: Colors.orange);
    }
  }
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        if (_userId == null) {
          if (!mounted) return;
          AppSnackBar.error(context, 'Profile is still loading, please try again.');
          return;
        }

        final userId = _userId!;
        final avatarStorageKey = profileAvatarStorageKey(userId);
        final localAvatar = await LocalFileService.storeImageLocally(
          userId,
          pickedFile.path,
          avatarStorageKey,
          'profile_avatar',
        );

        if (!mounted) return;

        setState(() {
          // Show the preview instantly from local storage when possible
          final pickedLocal = localAvatar ?? File(pickedFile.path);
          _selectedImage = pickedLocal;
        });
      }
    } catch (e) {
      // If it fails, print the error and show a SnackBar!
      if (!mounted) return;
      debugPrint("Image picker error: $e");
      AppSnackBar.error(context, 'Error opening image picker: $e');
    }
  }

  void updateProfile() async{
    if (!formKey.currentState!.validate()) return;
    setState(() => loading = true);

    String? newAvatarUrl = _currentAvatarUrl;

    // Upload to Supabase first, keep local file as fallback.
    if (_selectedImage != null) {
      final uploadedAvatarUrl = await ProfileService.uploadAvatar(_selectedImage!);
      if (!mounted) return;
      if (uploadedAvatarUrl == null) {
        setState(() => loading = false);
        AppSnackBar.error(context, 'Failed to upload image to Supabase.');
        return;
      }
      newAvatarUrl = uploadedAvatarUrl;

      if (_userId != null) {
        final avatarStorageKey = profileAvatarStorageKey(_userId!);
        await LocalFileService.cacheRemoteUrl(avatarStorageKey, uploadedAvatarUrl);
      }
    }

    bool success = await ProfileService.updateProfile(
      nameController.text.trim(),
      emailController.text.trim(),
      _selectedGender ?? '',
      contactController.text.trim(),
      locationController.text.trim(),
      newAvatarUrl
    );
    if (mounted) {
      setState(() => loading = false);
      if (success) {
        _currentAvatarUrl = newAvatarUrl;
        _selectedImage = null;
        _initialLocation = locationController.text.trim();
        _locationEdited = false;
        AppSnackBar.success(context, 'Profile updated successfully!');
      } else {
        AppSnackBar.error(context, 'Failed to update profile. Try again.');
      }
    }
  }
  void _showImageSourceOptions() {
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.only(bottom: 30, top: 12),
        decoration: const BoxDecoration(
          color: AppColors.white,
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
                'Take a Photo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
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
                'Choose from Gallery',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Start with a loading state so the UI knows we are fetching
    loading = true;
    _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.arrow_back, color: AppColors.iconColor),
        ),
        title: const Text(
          "Edit Profile",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.borderGray, height: 1.0),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                _buildAvatarSection(),
                const SizedBox(height: 32),
                TextFormField(
                  controller: nameController,
                  decoration: AppDecorations.outlineInputDecoration(
                    hintText: "Enter your full name",
                    labelText: "Full Name",
                    prefixIcon: Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: AppDecorations.outlineInputDecoration(
                    hintText: "Enter your email",
                    labelText: "Email Address",
                    prefixIcon: Icons.mail_outline,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedGender),
                  initialValue: _selectedGender,
                  decoration: AppDecorations.outlineInputDecoration(
                    hintText: "Select your gender",
                    labelText: "Gender",
                    prefixIcon: Icons.wc,
                  ),
                  items: <String>{
                    ..._genderOptions,
                    if (_selectedGender != null && _selectedGender!.isNotEmpty)
                      _selectedGender!,
                  }.map((gender) {
                    return DropdownMenuItem<String>(
                      value: gender,
                      child: Text(gender),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value ?? '';
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: contactController,
                  keyboardType: TextInputType.phone,
                  decoration: AppDecorations.outlineInputDecoration(
                    hintText: "Enter your phone number",
                    labelText: "Contact",
                    prefixIcon: Icons.phone_outlined,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: locationController,
                  decoration: AppDecorations.outlineInputDecoration(
                    hintText: "Enter your location",
                    labelText: "Location",
                    prefixIcon: Icons.location_on_outlined,
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    // Keep existing saved location valid when user did not edit it.
                    if (!_locationEdited && value == _initialLocation) {
                      return null;
                    }

                    if (_selectedPlace == null) {
                      return "Please select a location from the search results";
                    }
                    return null;
                  },
                  onFieldSubmitted: _onSearchChanged,
                  onChanged: (val) {
                    final trimmed = val.trim();
                    _locationEdited = trimmed != _initialLocation;
                    if (_selectedPlace != null) {
                      setState(() => _selectedPlace = null);
                    }
                    _onSearchChanged(val);
                  },
                ),

                if (_suggestions.isNotEmpty)
                  Container(
                    height: 200,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListView.builder(
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final place = _suggestions[index];

                        return ListTile(
                          title: Text(
                            place.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            setState(() {
                              _selectedPlace = place;
                              locationController.text = place.displayName;
                              _locationEdited = false;
                              _suggestions.clear();
                            });
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: loading ? null : updateProfile,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          loading
                              ? "Saving ..."
                              : "Save Changes",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                      side: const BorderSide(color: AppColors.border),
                      // Using your border color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await _exitEditPage();
                    },
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _showImageSourceOptions,
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderGray, width: 2),
                ),
                child: ProfileAvatar(
                  userId: _userId ?? '',
                  name: nameController.text,
                  avatarUrl: _currentAvatarUrl,
                  previewFile: _selectedImage,
                  radius: 45,
                  backgroundColor: AppColors.inputFill,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _showImageSourceOptions,
          child: const Text(
            "Change Photo",
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

