import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/local_file_service.dart';
import '../../../core/utils/supabase_file_service.dart';
import '../model/post_model.dart';
import '../service/post_service.dart';

class ManagePostPage extends StatefulWidget {
  final CommunityPostModel? post;

  const ManagePostPage({super.key, this.post});

  @override
  State<ManagePostPage> createState() => _ManagePostPageState();
}

class _ManagePostPageState extends State<ManagePostPage> {
  final TextEditingController _contentController = TextEditingController();
  final PostService _service = PostService();
  final ImagePicker _picker = ImagePicker();

  bool _isAnonymous = false;
  List<String> _existingUrls = [];
  List<File> _selectedImages = [];
  bool _isSubmitting = false;
  bool _isLoadingImages = false;
  bool _hasContent = false;
  String _privacyStatus = "Public";

  String _userName = "Loading...";
  String? _userAvatar;
  String _userRole = "user";

  static const int _maxImages = 10;

  bool get isEditMode => widget.post != null;

  bool get _isAdmin => _userRole.toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _contentController.text = widget.post!.content;
      _isAnonymous = widget.post!.isAnonymous;
      _privacyStatus = widget.post!.isPrivate ? "Private" : "Public";
      _existingUrls = List.from(widget.post!.fullImageUrls);
      _hasContent = _contentController.text.trim().isNotEmpty;
    }
    _contentController.addListener(() {
      setState(() => _hasContent = _contentController.text.trim().isNotEmpty);
    });

    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final String activeUserId = await _service.getCurrentUserId();
      final String activeUserName = await _service.getCurrentUserName();
      final supabase = Supabase.instance.client;

      final userData = await supabase
          .from('User')
          .select('avatar_url, role')
          .eq('user_id', activeUserId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userName = activeUserName;
          _userAvatar = userData?['avatar_url'];
          _userRole = userData?['role']?.toString() ?? 'user';
        });
      }
    } catch (e) {
      debugPrint("User Fetch Error: $e");
      if (mounted) {
        setState(() {
          _userName = "User";
          _userRole = "user";
        });
      }
    }
  }

  // Shows the bottom sheet to select Camera or Gallery
  void _showImageSourceActionSheet() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                "Take a Photo",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                "Choose from Gallery",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Capture photo via camera
  Future<void> _takePhoto() async {
    int currentTotal = _existingUrls.length + _selectedImages.length;
    if (currentTotal >= _maxImages) return;

    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() => _isLoadingImages = true);
      _selectedImages.add(File(pickedFile.path));
      setState(() => _isLoadingImages = false);
    }
  }

  // Select multiple images from the gallery
  Future<void> _pickImages() async {
    int currentTotal = _existingUrls.length + _selectedImages.length;
    if (currentTotal >= _maxImages) return;

    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      imageQuality: 70,
    );

    if (pickedFiles.isNotEmpty) {
      setState(() => _isLoadingImages = true);
      for (var xFile in pickedFiles) {
        if ((_existingUrls.length + _selectedImages.length) < _maxImages) {
          _selectedImages.add(File(xFile.path));
        }
      }
      setState(() => _isLoadingImages = false);
    }
  }

  // Handles the post submission (Cloud Upload + Local Cache + Database)
  Future<void> _handlePostSubmit() async {
    final String content = _contentController.text.trim();
    if (content.isEmpty || _isSubmitting) return;

    // Check for changes in edit mode to avoid unnecessary uploads
    if (isEditMode) {
      bool isChanged =
          content != widget.post!.content ||
          (_privacyStatus == "Private") != widget.post!.isPrivate ||
          _selectedImages.isNotEmpty ||
          _existingUrls.length != widget.post!.fullImageUrls.length;
      if (!isChanged) {
        Navigator.pop(context);
        return;
      }
    }

    // Admin cannot have anonymous post
    if (_isAdmin && _isAnonymous) {
      _isAnonymous = false;
    }

    setState(() => _isSubmitting = true);

    try {
      final String activeUserId = await _service.getCurrentUserId();
      List<String> finalImageNames = [];

      for (String url in _existingUrls) {
        finalImageNames.add(url.split('/').last.split('?').first);
      }

      for (int i = 0; i < _selectedImages.length; i++) {
        File imageFile = _selectedImages[i];

        String timestamp = DateTime.now().microsecondsSinceEpoch.toString();
        String customPrefix = 'Post_${activeUserId}_$timestamp';

        // Upload to Supabase Storage
        String? uploadedUrl = await SupabaseFileService.uploadImage(
          imageFile: imageFile,
          bucketName: 'documents',
          folderPath: 'post_images',
          fileNamePrefix: customPrefix,
        );

        if (uploadedUrl != null) {
          // Extract pure filename
          String fileName = uploadedUrl.split('/').last.split('?').first;
          finalImageNames.add(fileName);

          // Store image locally using the exact filename as the key
          await LocalFileService.storeImageLocally(
            activeUserId,
            XFile(imageFile.path),
            fileName,
            'post_images',
          );
        }
      }

      // Convert list to comma-separated string for database
      String? imgUrlResult = finalImageNames.isEmpty
          ? null
          : finalImageNames.join(',');

      if (isEditMode) {
        await _service.updatePost(
          postId: widget.post!.postId,
          content: content,
          isPrivate: _privacyStatus == "Private",
          imgUrl: imgUrlResult,
        );
      } else {
        await _service.createPost(
          content: content,
          isPrivate: _privacyStatus == "Private",
          isAnonymous: _isAnonymous,
          imgUrl: imgUrlResult,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Post Submit Error: $e");
      if (mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openImageDialog(int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) {
        PageController pageController = PageController(
          initialPage: initialIndex,
        );
        int currentIndex = initialIndex;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            int total = _existingUrls.length + _selectedImages.length;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: pageController,
                    itemCount: total,
                    onPageChanged: (index) =>
                        setDialogState(() => currentIndex = index),
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        child: Center(
                          child: index < _existingUrls.length
                              ? Image.network(
                                  _existingUrls[index],
                                  fit: BoxFit.contain,
                                )
                              : Image.file(
                                  _selectedImages[index - _existingUrls.length],
                                  fit: BoxFit.contain,
                                ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 40,
                    left: 20,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  if (total > 1)
                    Positioned(
                      top: 45,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          "${currentIndex + 1} / $total",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    top: 40,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 30,
                      ),
                      onPressed: () {
                        setState(() {
                          if (currentIndex < _existingUrls.length) {
                            _existingUrls.removeAt(currentIndex);
                          } else {
                            _selectedImages.removeAt(
                              currentIndex - _existingUrls.length,
                            );
                          }
                        });
                        if (_existingUrls.isEmpty && _selectedImages.isEmpty) {
                          Navigator.pop(context);
                        } else {
                          setDialogState(() {
                            if (currentIndex >=
                                (_existingUrls.length +
                                    _selectedImages.length)) {
                              currentIndex =
                                  (_existingUrls.length +
                                      _selectedImages.length) -
                                  1;
                            }
                          });
                        }
                      },
                    ),
                  ),
                  if (total > 1)
                    Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          total,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: currentIndex == index ? 8.0 : 6.0,
                            height: currentIndex == index ? 8.0 : 6.0,
                            decoration: BoxDecoration(
                              color: currentIndex == index
                                  ? Colors.white
                                  : Colors.white..withValues(alpha:0.4),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int total = _existingUrls.length + _selectedImages.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          isEditMode ? "Edit Post" : "Create Post",
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [_buildActionButton()],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUserHeader(),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _contentController,
                    maxLines: 8,
                    autofocus: !isEditMode,
                    decoration: const InputDecoration(
                      hintText: "What's on your mind?",
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingImages)
                    const Center(child: CircularProgressIndicator())
                  else
                    _buildImagePreviewSection(total),
                ],
              ),
            ),
          ),
          if (_isSubmitting) _buildGlobalLoading(),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar Section
        FutureBuilder<File?>(
          future: LocalFileService.loadSavedImage('user_avatar_key'),
          builder: (context, snapshot) {
            bool hasValidNetworkAvatar =
                _userAvatar != null && _userAvatar!.startsWith('http');
            File? localFile = snapshot.data;

            return CircleAvatar(
              radius: 24,
              backgroundColor: _isAnonymous
                  ? Colors.grey.shade200
                  : AppColors.primaryLight,
              backgroundImage: _isAnonymous
                  ? null
                  : (hasValidNetworkAvatar
                        ? NetworkImage(_userAvatar!)
                        : (localFile != null ? FileImage(localFile) : null)
                              as ImageProvider?),
              child:
                  (_isAnonymous ||
                      (!hasValidNetworkAvatar && localFile == null))
                  ? Icon(
                      _isAnonymous
                          ? Icons.person_outline_rounded
                          : Icons.person_rounded,
                      color: _isAnonymous ? Colors.grey : AppColors.primary,
                      size: 28,
                    )
                  : null,
            );
          },
        ),
        const SizedBox(width: 12),

        // Identity and Privacy Section
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isAnonymous ? "Anonymous Account" : _userName,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: _isAnonymous
                      ? Colors.grey.shade700
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              _buildPrivacyBadge(),
            ],
          ),
        ),

        // Only visible to Non-Admins in Create Mode
        if (!isEditMode && !_isAdmin)
          Column(
            children: [
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _isAnonymous,
                  activeColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha:0.3),
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade200,
                  onChanged: (val) {
                    setState(() {
                      _isAnonymous = val;
                    });
                  },
                ),
              ),
              Text(
                "Anonymous",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _isAnonymous ? AppColors.primary : Colors.grey,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildImagePreviewSection(int total) {
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._existingUrls.asMap().entries.map(
                (e) => _buildImageTile(
                  e.key,
                  true,
                  Image.network(e.value, fit: BoxFit.cover),
                ),
              ),
              ..._selectedImages.asMap().entries.map(
                (e) => _buildImageTile(
                  e.key,
                  false,
                  Image.file(e.value, fit: BoxFit.cover),
                ),
              ),

              if (total < 3)
                GestureDetector(
                  onTap: _showImageSourceActionSheet,
                  child: Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (total >= 3 && total < _maxImages)
              TextButton.icon(
                onPressed: _showImageSourceActionSheet,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text("Add more"),
              ),
            const Spacer(),
            if (total > 0)
              TextButton.icon(
                onPressed: () => setState(() {
                  _existingUrls.clear();
                  _selectedImages.clear();
                }),
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                label: const Text(
                  "Clear all",
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // Builds an individual image preview tile with a delete button
  Widget _buildImageTile(int index, bool isNet, Widget content) {
    return GestureDetector(
      onTap: () =>
          _openImageDialog(isNet ? index : index + _existingUrls.length),
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            margin: const EdgeInsets.only(right: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: content,
            ),
          ),
          Positioned(
            right: 16,
            top: 4,
            child: GestureDetector(
              onTap: () => setState(
                () => isNet
                    ? _existingUrls.removeAt(index)
                    : _selectedImages.removeAt(index),
              ),
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Center(
        child: ElevatedButton(
          onPressed: (_hasContent && !_isSubmitting && !_isLoadingImages)
              ? _handlePostSubmit
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _hasContent
                ? AppColors.textPrimary
                : AppColors.border,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(isEditMode ? "Update" : "Post"),
        ),
      ),
    );
  }

  void _showPrivacyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPrivacyOption(
              "Public",
              "Anyone can see this post",
              Icons.public_rounded,
            ),
            _buildPrivacyOption(
              "Private",
              "Only you can see this post",
              Icons.lock_outline_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyBadge() {
    return GestureDetector(
      onTap: _showPrivacyPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _privacyStatus == "Public" ? Icons.public : Icons.lock_outline,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: 5),
            Text(
              _privacyStatus,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyOption(String t, String s, IconData i) {
    bool sel = _privacyStatus == t;
    return ListTile(
      leading: Icon(i, color: sel ? AppColors.primary : Colors.grey),
      title: Text(
        t,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: sel ? AppColors.primary : Colors.black,
        ),
      ),
      subtitle: Text(s),
      onTap: () {
        setState(() => _privacyStatus = t);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildGlobalLoading() {
    return Container(
      color: Colors.white54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 15),
              Text(
                isEditMode ? "Updating..." : "Posting...",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
