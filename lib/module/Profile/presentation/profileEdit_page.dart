import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/core/utils/local_file_service.dart';
import 'package:pawhub/core/widgets/appDecorations.dart';
import 'package:pawhub/module/Profile/model/user_model.dart';
import 'package:pawhub/module/Profile/service/profile_service.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  static const String _avatarPathKey = 'profile_edit_avatar_path';
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
  File? _localBackupImage;
  String? _selectedGender;
  String? _currentAvatarUrl;
  String? _userId;
  bool loading = false;

  void _exitEditPage() {
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
      Navigator.pushNamedAndRemoveUntil(context, '/user_layout', (route) => false);
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

  // Future<File?> _loadSavedLocalAvatar() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final savedPath = prefs.getString(_avatarPathKey);
  //
  //   if (savedPath == null || savedPath.isEmpty) {
  //     return null;
  //   }
  //
  //   final savedFile = File(savedPath);
  //   if (await savedFile.exists()) {
  //     return savedFile;
  //   }
  //
  //   await prefs.remove(_avatarPathKey);
  //   return null;
  // }

  // Future<File?> _storeAvatarLocally(XFile pickedFile) async {
  //   try {
  //     final appDir = await getApplicationDocumentsDirectory();
  //     final profileDir = Directory('${appDir.path}${Platform.pathSeparator}profile',);
  //     if (!await profileDir.exists()) {
  //       await profileDir.create(recursive: true);
  //     }
  //
  //     final fileExtension = pickedFile.path.contains('.') ? pickedFile.path.split('.').last : 'jpg';
  //     final localFileName ='profile_avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
  //     final localFile = await File(pickedFile.path).copy('${profileDir.path}${Platform.pathSeparator}$localFileName',);
  //
  //     final prefs = await SharedPreferences.getInstance();
  //     await prefs.setString(_avatarPathKey, localFile.path);
  //
  //     return localFile;
  //   } catch (e) {
  //     debugPrint('Error saving avatar locally: $e');
  //     return null;
  //   }
  // }

  Future<void> _loadUserData() async{
    final UserModel? profileData = await ProfileService.getCurrentUserProfile();

    if(profileData != null){
      final localAvatar = await LocalFileService.loadSavedImage(_avatarPathKey);

      if (!mounted) return;

      setState(() {
        _userId = profileData.id;
        nameController.text = profileData.name;
        emailController.text = profileData.email;
        _selectedGender = profileData.gender.isEmpty ? null : profileData.gender;
        contactController.text = profileData.contact;
        locationController.text = profileData.address;

        _currentAvatarUrl = profileData.avatarUrl;
        _selectedImage = null;
        _localBackupImage = localAvatar;
        loading = false;
      });
    }else{
      if (!mounted) return;
      setState(() {
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load profile data.')),
      );
    }
  }
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        final localAvatar = await LocalFileService.storeImageLocally(_userId ?? 'profile',pickedFile, _avatarPathKey, 'profile_avatar');

        if (!mounted) return;

        setState(() {
          // Show the preview instantly from local storage when possible
          final pickedLocal = localAvatar ?? File(pickedFile.path);
          _selectedImage = pickedLocal;
          _localBackupImage = pickedLocal;
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
                    onPressed: () {
                      _exitEditPage();
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
    // Determine what image to show
    ImageProvider? imageProvider;
    if (_selectedImage != null) {
      imageProvider = FileImage(_selectedImage!); // Show newly picked image
    } else if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_currentAvatarUrl!); // Primary source: Supabase
    } else if (_localBackupImage != null) {
      imageProvider = FileImage(_localBackupImage!); // Fallback: local backup
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _showImageSourceOptions, // Tap the avatar to change it
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderGray, width: 2),
                ),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: AppColors.inputFill,
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? const Icon(Icons.person, size: 45, color: Colors.grey)
                      : null,
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
          onTap: _showImageSourceOptions, // Tap the text to change it
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