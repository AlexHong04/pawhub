import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/local_file_service.dart';
import '../model/post_model.dart';
import '../service/post_service.dart';
import 'manage_post.dart';
import 'post_details_page.dart';

class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({super.key});

  @override
  State<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<CommunityFeedPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final PostService _postService = PostService();

  String _currentUserId = 'GUEST';
  String _currentUserName = "User";

  List<CommunityPostModel> _posts = [];
  bool _isLoading = true;

  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    _currentUserId = await _postService.getCurrentUserId();
    _currentUserName = await _postService.getCurrentUserName();
    await _loadPosts();
  }

  // If silent == true, it refreshes data WITHOUT showing the loading spinner.
  Future<void> _loadPosts({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    try {
      final data = await _postService.fetchPosts();
      if (mounted) {
        setState(() {
          _posts = data.where((post) {
            if (!post.isPrivate) return true;
            return post.userId == _currentUserId;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("User Fetch Posts Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inHours >= 24) {
      return time.toString().split('.')[0].substring(0, 16);
    }
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
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

    final filteredPosts = _posts.where((post) {
      final query = _searchQuery.toLowerCase();
      return post.content.toLowerCase().contains(query) ||
          post.userName.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F6F9),
        elevation: 0,
        centerTitle: true,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search posts...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              )
            : const Text(
                "Community",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  fontSize: 22,
                ),
              ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchQuery = "";
                  }
                });
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue.shade600,
                child: Icon(
                  _isSearching ? Icons.close : Icons.search,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: () => _loadPosts(silent: false),
              child: filteredPosts.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.25,
                        ),
                        const Icon(
                          Icons.search_off_rounded,
                          size: 80,
                          color: Colors.black26,
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            "No related posts found",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            "Try searching with different keywords.",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black38,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredPosts.length,
                      itemBuilder: (context, index) {
                        final post = filteredPosts[index];
                        final bool isMyPost = post.userId == _currentUserId;

                        Color badgeBgColor = Colors.grey.shade100;
                        Color badgeTextColor = Colors.grey;
                        String roleText = post.userRole.toUpperCase();

                        bool showBadge = false;

                        if (post.userRole.toLowerCase() == 'admin') {
                          showBadge = true;
                          badgeBgColor = Colors.blue.shade50;
                          badgeTextColor = Colors.blue.shade700;
                          roleText = "ADMIN";
                        } else if (post.isVolunteer) {
                          showBadge = true;
                          badgeBgColor = const Color(0xFFE8F5E9);
                          badgeTextColor = const Color(0xFF2E7D32);
                          roleText = "VOLUNTEER";
                        }

                        ImageProvider? avatarImage;
                        if (post.userAvatar != null &&
                            post.userAvatar!.isNotEmpty &&
                            post.userAvatar!.startsWith('http')) {
                          avatarImage = NetworkImage(post.userAvatar!);
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey.withValues(
                                          alpha: 0.1,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: const Color(0xFFF5F7FA),
                                      backgroundImage: avatarImage,
                                      child: avatarImage == null
                                          ? const Icon(
                                              Icons.person,
                                              color: Colors.grey,
                                              size: 24,
                                            )
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                post.userName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),

                                            if (showBadge) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: badgeBgColor,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  roleText,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    color: badgeTextColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (post.isPrivate) ...[
                                              const SizedBox(width: 6),
                                              Icon(
                                                Icons.lock_outline_rounded,
                                                size: 16,
                                                color: Colors.grey.shade500,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatTimeAgo(post.createdAt),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isMyPost)
                                    IconButton(
                                      icon: Icon(
                                        Icons.more_horiz,
                                        color: Colors.grey.shade400,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        showModalBottomSheet(
                                          context: context,
                                          backgroundColor: Colors.transparent,
                                          builder: (BuildContext context) {
                                            return Container(
                                              padding: const EdgeInsets.only(
                                                top: 12,
                                                bottom: 30,
                                              ),
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                      top: Radius.circular(24),
                                                    ),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 40,
                                                    height: 5,
                                                    margin:
                                                        const EdgeInsets.only(
                                                          bottom: 24,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade300,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                  ),
                                                  ListTile(
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 24,
                                                        ),
                                                    leading: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.blue.shade50,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        Icons.edit_rounded,
                                                        color: Colors
                                                            .blue
                                                            .shade600,
                                                        size: 22,
                                                      ),
                                                    ),
                                                    title: const Text(
                                                      'Edit Post',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    onTap: () async {
                                                      Navigator.pop(context);
                                                      final res =
                                                          await Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) =>
                                                                  ManagePostPage(
                                                                    post: post,
                                                                  ),
                                                            ),
                                                          );
                                                      if (res == true) {
                                                        _loadPosts(
                                                          silent: true,
                                                        );
                                                      }
                                                    },
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ListTile(
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 24,
                                                        ),
                                                    leading: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.red.shade50,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        color: Colors.redAccent,
                                                        size: 22,
                                                      ),
                                                    ),
                                                    title: const Text(
                                                      'Delete Post',
                                                      style: TextStyle(
                                                        color: Colors.redAccent,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      _confirmDelete(post);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                post.content,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.4,
                                  color: Colors.black87,
                                ),
                              ),
                              if (post.fullImageUrls.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: SizedBox(
                                    height: 180,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: post.fullImageUrls.length,
                                      itemBuilder: (context, i) => GestureDetector(
                                        onTap: () => _openFullScreenImage(
                                          post.fullImageUrls,
                                          i,
                                        ),
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Builder(
                                              builder: (context) {
                                                final String url =
                                                    post.fullImageUrls[i];
                                                final String fileName = url.split('/').last.split('?').first;
                                                return Image.network(
                                                  url,
                                                  width:
                                                      post.fullImageUrls.length == 1 ? 300 : 180,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return FutureBuilder<File?>(
                                                      future:
                                                          LocalFileService.loadSavedImage(
                                                            fileName,
                                                          ),
                                                      builder: (context, snapshot) {
                                                        if (snapshot.hasData &&
                                                            snapshot.data !=
                                                                null) {
                                                          return Image.file(
                                                            snapshot.data!,
                                                            width:
                                                              post.fullImageUrls.length == 1 ? 300 : 180,
                                                            fit: BoxFit.cover,
                                                          );
                                                        }
                                                        return Container(
                                                          width:
                                                            post.fullImageUrls.length == 1 ? 300 : 180,
                                                          color: Colors
                                                              .grey
                                                              .shade100,
                                                          child: const Center(
                                                            child: Icon(
                                                              Icons
                                                                  .broken_image,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
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
                                          post.isLiked
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          size: 20,
                                          color: post.isLiked
                                              ? Colors.redAccent
                                              : Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "${post.likesCount}",
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  GestureDetector(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              PostDetailsPage(post: post),
                                        ),
                                      );
                                      _loadPosts(silent: true);
                                    },
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline,
                                          size: 20,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "${post.commentsCount}",
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  GestureDetector(
                                    child: Icon(
                                      Icons.share_outlined,
                                      size: 20,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ManagePostPage()),
          );
          if (res == true) _loadPosts(silent: true);
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  void _confirmDelete(CommunityPostModel post) {
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
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Delete post?",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "You can restore this post for the next 7 days from your Archive settings. After that, it will be permanently deleted.",
                textAlign: TextAlign.center,
                style: TextStyle(
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
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _postService.deletePost(post.postId);
                        setState(() {
                          _posts.removeWhere((p) => p.postId == post.postId);
                        });
                      },
                      child: const Text(
                        "Delete",
                        style: TextStyle(
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
}
