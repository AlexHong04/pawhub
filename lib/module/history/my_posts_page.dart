import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../core/utils/local_file_service.dart';
import '../Profile/model/user_model.dart';
import '../Profile/service/profile_service.dart';
import '../communityPost/model/post_model.dart';
import '../communityPost/service/post_service.dart';
import '../communityPost/presentation/manage_post.dart';
import '../communityPost/presentation/post_details_page.dart';
import '../../../core/utils/current_user_store.dart';

class MyPostsPage extends StatefulWidget {
  const MyPostsPage({super.key});

  @override
  State<MyPostsPage> createState() => _MyPostsPageState();
}

class _MyPostsPageState extends State<MyPostsPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final PostService _postService = PostService();
  UserModel? _userProfile;
  String _currentUserId = 'GUEST';
  String _currentUserName = "Jackie Chan";
  String? _currentUserAvatar;

  List<CommunityPostModel> _myPosts = [];
  List<CommunityPostModel> _deletedPosts = [];
  bool _isLoading = true;
  bool _isShowingDeleted = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    final cachedAuth = await CurrentUserStore.read();
    if (cachedAuth != null) {
      setState(() {
        _currentUserId = cachedAuth.id;
        _currentUserName = cachedAuth.name ?? "Jackie Chan";
      });
    }
    try {
      final freshProfile = await ProfileService.getCurrentUserProfile();
      if (freshProfile != null) {
        setState(() {
          _userProfile = freshProfile;
          _currentUserName = freshProfile.name;
        });
      }
    } catch (e) {
      debugPrint('Profile sync failed: $e');
    }
    await _loadMyPosts();
  }

  Future<void> _loadMyPosts({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final data = await _postService.fetchPosts();
      if (mounted) {
        setState(() {
          _myPosts = data
              .where((post) => post.userId == _currentUserId)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleRecycleBin() async {
    if (!_isShowingDeleted) {
      setState(() => _isLoading = true);
      final data = await _postService.fetchRecentlyDeletedPosts();

      // remove data over 7 days
      final now = DateTime.now();
      final filteredData = data.where((post) {
        if (post.updatedAt == null) return false;
        return post.updatedAt!.add(const Duration(days: 7)).isAfter(now);
      }).toList();

      setState(() {
        _deletedPosts = filteredData;
        _isShowingDeleted = true;
        _isLoading = false;
      });
    } else {
      setState(() => _isShowingDeleted = false);
      _loadMyPosts(silent: true);
    }
  }

  String _getExpiryInfo(DateTime? updatedAt) {
    if (updatedAt == null) return "No date available";
    final expiryDate = updatedAt.add(const Duration(days: 7));
    final remaining = expiryDate.difference(DateTime.now());

    if (remaining.inDays > 0) return "${remaining.inDays} days left";
    if (remaining.inHours > 0) return "${remaining.inHours} hours left";
    if (remaining.inMinutes > 0) return "${remaining.inMinutes} mins left";
    return "Expired";
  }

  void _openFullScreenImage(List<String> urls, int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (context) {
        PageController pageController = PageController(
          initialPage: initialIndex,
        );
        int current = initialIndex;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  "${current + 1} / ${urls.length}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
              ),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: pageController,
                    itemCount: urls.length,
                    onPageChanged: (index) =>
                        setDialogState(() => current = index),
                    itemBuilder: (context, index) {
                      final String url = urls[index];
                      final String fileName = url.split('/').last.split('?').first;

                      return InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return FutureBuilder<File?>(
                                future: LocalFileService.loadSavedImage(
                                  fileName,
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData &&
                                      snapshot.data != null) {
                                    return Image.file(
                                      snapshot.data!,
                                      fit: BoxFit.contain,
                                    );
                                  }
                                  return const Icon(
                                    Icons.broken_image,
                                    color: Colors.white54,
                                    size: 50,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  if (urls.length > 1)
                    Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          urls.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: current == index ? 8.0 : 6.0,
                            height: current == index ? 8.0 : 6.0,
                            decoration: BoxDecoration(
                              color: current == index
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.4),
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
    super.build(context);
    final currentList = _isShowingDeleted ? _deletedPosts : _myPosts;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F6F9),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isShowingDeleted ? "Archive" : "My Posts",
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black87,
            fontSize: 20,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: () => _isShowingDeleted
                  ? _toggleRecycleBin()
                  : _loadMyPosts(silent: false),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 80),
                children: [
                  _buildProfileHeader(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Divider(color: Color(0xFFE0E0E0), height: 1),
                  ),
                  const SizedBox(height: 12),
                  if (currentList.isEmpty)
                    _buildEmptyState()
                  else
                    ...currentList.map((post) => _buildPostCard(post)),
                ],
              ),
            ),
      floatingActionButton: _isShowingDeleted
          ? null
          : FloatingActionButton(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              onPressed: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManagePostPage(),
                  ),
                );
                if (res == true) _loadMyPosts(silent: true);
              },
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
    );
  }

  Widget _buildProfileHeader() {
    final avatarUrl = _userProfile?.avatarUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: const Color(0xFFE0E0E0),
            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? NetworkImage(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? const Icon(Icons.person, size: 35, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUserName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_myPosts.length} Posts published",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _toggleRecycleBin,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isShowingDeleted
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isShowingDeleted ? Colors.blue : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Icon(
                _isShowingDeleted
                    ? Icons.history_rounded
                    : Icons.archive_outlined,
                color: _isShowingDeleted ? Colors.blue : Colors.black87,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(CommunityPostModel post) {
    final bool isExpired =
        post.updatedAt != null &&
        post.updatedAt!.add(const Duration(days: 7)).isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Published At",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      Text(
                        post.createdAt.toString().substring(0, 16),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (post.isPrivate) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              _isShowingDeleted
                  ? IconButton(
                      icon: Icon(
                        Icons.unarchive_rounded,
                        color: isExpired ? Colors.grey.shade400 : Colors.blue,
                      ),
                      onPressed: isExpired ? null : () => _confirmRestore(post),
                    )
                  : IconButton(
                      icon: const Icon(Icons.more_horiz, color: Colors.grey),
                      onPressed: () => _showPostOptions(post),
                    ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            post.content,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              height: 1.4,
            ),
          ),

          if (post.fullImageUrls.isNotEmpty) _buildImageGrid(post),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (post.isLiked) {
                          post.likesCount--;
                          post.isLiked = false;
                        } else {
                          post.likesCount++;
                          post.isLiked = true;
                        }
                      });
                      _postService.toggleLike(post.postId);
                    },
                    child: Row(
                      children: [
                        Icon(
                          post.isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: post.isLiked
                              ? Colors.redAccent
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "${post.likesCount}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 20),

                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostDetailsPage(post: post),
                        ),
                      );
                      _loadMyPosts(silent: true);
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 18,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "${post.commentsCount}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (_isShowingDeleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isExpired
                        ? Colors.red.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isExpired ? "Expired" : _getExpiryInfo(post.updatedAt),
                    style: TextStyle(
                      color: isExpired ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(CommunityPostModel post) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        height: 160,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: post.fullImageUrls.length,
          itemBuilder: (context, i) {
            final String url = post.fullImageUrls[i];
            final String fileName = url.split('/').last.split('?').first;

            return GestureDetector(
              onTap: () => _openFullScreenImage(post.fullImageUrls, i),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    url,
                    width: post.fullImageUrls.length == 1 ? 280 : 160,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return FutureBuilder<File?>(
                        future: LocalFileService.loadSavedImage(fileName),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return Image.file(
                              snapshot.data!,
                              width: post.fullImageUrls.length == 1 ? 280 : 160,
                              fit: BoxFit.cover,
                            );
                          }
                          return Container(
                            width: post.fullImageUrls.length == 1 ? 280 : 160,
                            color: Colors.grey.shade100,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmDelete(CommunityPostModel post) {
    _showConsistentDialog(
      title: "Delete post?",
      content:
          "You can restore this post for the next 7 days from your Archive. After that, it will be permanently deleted.",
      confirmText: "Delete",
      isDelete: true,
      onConfirm: () async {
        await _postService.deletePost(post.postId);
        _loadMyPosts(silent: true);
      },
    );
  }

  void _confirmRestore(CommunityPostModel post) {
    _showConsistentDialog(
      title: "Restore post?",
      content:
          "Once restored, this post will be visible to everyone in the community feed again.",
      confirmText: "Restore",
      isDelete: false,
      onConfirm: () async {
        await _postService.reactivePost(post.postId);
        _toggleRecycleBin();
      },
    );
  }

  void _showConsistentDialog({
    required String title,
    required String content,
    required String confirmText,
    required bool isDelete,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: isDelete ? Colors.red.shade50 : Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isDelete
                        ? Icons.delete_outline_rounded
                        : Icons.settings_backup_restore_rounded,
                    color: isDelete ? Colors.redAccent : Colors.blue,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                content,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDelete
                            ? Colors.redAccent
                            : Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
                      child: Text(
                        confirmText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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

  void _showPostOptions(CommunityPostModel post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.only(top: 12, bottom: 30),
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
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.blue),
              title: const Text(
                'Edit Post',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                Navigator.pop(context);
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManagePostPage(post: post),
                  ),
                );
                if (res == true) _loadMyPosts(silent: true);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Delete Post',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(post);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 100),
          Icon(
            _isShowingDeleted ? Icons.archive_outlined : Icons.post_add_rounded,
            size: 80,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 16),
          Text(
            _isShowingDeleted ? "No archived posts" : "No active posts",
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}