import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/core/utils/local_file_service.dart';
import 'package:pawhub/core/widgets/appDecorations.dart';
import 'package:pawhub/module/Profile/model/user_model.dart';
import 'package:pawhub/module/Profile/service/profile_service.dart';
import 'package:pawhub/module/auth/service/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/widgets/profile_avatar.dart';

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Loading offline avatar.')),
      );
    }
  }
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        if (_userId == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile is still loading, please try again.')),
          );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening image picker: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload image to Supabase.')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile. Try again.')),
        );
      }
    }
  }
  void _showImageSourceOptions() {
    // Hide the keyboard if it's open
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context); // Close the menu
                  _pickImage(ImageSource.camera); // Open Camera!
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context); // Close the menu
                  _pickImage(ImageSource.gallery); // Open Gallery!
                },
              ),
            ],
          ),
        );
      },
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



