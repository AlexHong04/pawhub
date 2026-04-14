import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    try {
      final profileData = await ProfileService.getCurrentUserProfile();
      if (profileData != null) {
        _userProfile = profileData;
        _currentUserId = profileData.id;
      }
    } catch (e) {
      debugPrint('Supabase sync error in MyPostsPage: $e');

      final cachedAuth = await CurrentUserStore.read();
      if (cachedAuth != null) {
        _currentUserId = cachedAuth.id;
        _userProfile = UserModel(
          id: cachedAuth.id,
          name: cachedAuth.name ?? "User",
          email: cachedAuth.email ?? "",
          gender: '', contact: '', address: '',
          role: cachedAuth.role ?? 'User',
          onlineStatus: 'Online',
          isVolunteer: false,
          updatedAt: DateTime.now(),
          avatarUrl: '',
        );
      }
    }
    await _loadMyPosts();
  }

  Future<void> _loadMyPosts({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final data = await _postService.fetchPosts();
      if (mounted) {
        setState(() {
          _myPosts = data.where((post) => post.userId == _currentUserId).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch My Posts Error: $e");
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
      barrierColor: Colors.black..withValues(alpha:0.95),
      builder: (context) {
        PageController pageController = PageController(initialPage: initialIndex);
        int current = initialIndex;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: () => Navigator.pop(context)),
              ),
              body: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: pageController,
                    itemCount: urls.length,
                    onPageChanged: (index) => setDialogState(() => current = index),
                    itemBuilder: (context, index) => InteractiveViewer(
                      panEnabled: true, minScale: 0.5, maxScale: 4.0,
                      child: Center(child: Image.network(urls[index], fit: BoxFit.contain)),
                    ),
                  ),
                  if (urls.length > 1)
                    Positioned(
                      top: 45, left: 0, right: 0,
                      child: Center(child: Text("${current + 1} / ${urls.length}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
                    ),
                  if (urls.length > 1)
                    Positioned(
                      bottom: 40, left: 0, right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(urls.length, (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: current == index ? 8.0 : 6.0, height: current == index ? 8.0 : 6.0,
                          decoration: BoxDecoration(color: current == index ? Colors.white : Colors.white..withValues(alpha:0.4), shape: BoxShape.circle),
                        )),
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

  void _confirmDelete(CommunityPostModel post) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent, elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black..withValues(alpha:0.1), blurRadius: 20, offset: const Offset(0, 10))]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 64, width: 64, decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle), child: const Center(child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 32))),
              const SizedBox(height: 20),
              const Text("Delete Post?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              const SizedBox(height: 8),
              const Text("This action cannot be undone. Are you sure you want to permanently delete this post?", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: AppColors.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 15)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _postService.deletePost(post.postId);
                      setState(() => _myPosts.removeWhere((p) => p.postId == post.postId));
                    },
                    child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final name = _userProfile?.name ?? "My Profile";
    final avatarUrl = _userProfile?.avatarUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Posts",
          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 20),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _loadMyPosts(silent: false),
        child: ListView(
          padding: const EdgeInsets.only(top: 0, bottom: 80),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.border,
                    backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: _currentUserAvatar == null ? const Icon(Icons.person, color: AppColors.textPlaceholder, size: 30) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUserName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${_myPosts.length} Posts published",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: AppColors.border, height: 1),
            ),

            const SizedBox(height: 12),

            if (_myPosts.isEmpty)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.post_add_rounded, size: 80, color: AppColors.border),
                  const SizedBox(height: 16),
                  const Text("No posts yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Text("Share your first moment!", style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ],
              )
            else
              ..._myPosts.map((post) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha:0.03), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                _formatTimeAgo(post.createdAt),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary),
                              ),
                              if (post.isPrivate) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.lock_rounded, size: 14, color: AppColors.textPlaceholder),
                              ],
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.more_horiz, color: AppColors.textPlaceholder),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder: (BuildContext context) {
                                  return Container(
                                    padding: const EdgeInsets.only(top: 12, bottom: 30),
                                    decoration: const BoxDecoration(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10))),
                                        ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                                          leading: Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle), child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 22)),
                                          title: const Text('Edit Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                                          onTap: () async {
                                            Navigator.pop(context);
                                            final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => ManagePostPage(post: post)));
                                            if (res == true) _loadMyPosts(silent: true);
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                                          leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle), child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22)),
                                          title: const Text('Delete Post', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
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
                      const SizedBox(height: 8),
                      Text(post.content, style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.textBody)),
                      if (post.fullImageUrls.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: SizedBox(
                            height: 180,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: post.fullImageUrls.length,
                              itemBuilder: (context, i) => GestureDetector(
                                onTap: () => _openFullScreenImage(post.fullImageUrls, i),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      children: [
                                        Image.network(post.fullImageUrls[i], width: post.fullImageUrls.length == 1 ? 300 : 180, height: 180, fit: BoxFit.cover),
                                        if (post.fullImageUrls.length > 1)
                                          Positioned(
                                            top: 8, right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: Colors.black.withValues(alpha:0.6), borderRadius: BorderRadius.circular(12)),
                                              child: Text("${i + 1}/${post.fullImageUrls.length}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                            ),
                                          ),
                                      ],
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
                                if (post.isLiked) { post.likesCount--; post.isLiked = false; }
                                else { post.likesCount++; post.isLiked = true; }
                              });
                              _postService.toggleLike(post.postId);
                            },
                            child: Row(
                              children: [
                                Icon(post.isLiked ? Icons.favorite : Icons.favorite_border, size: 20, color: post.isLiked ? Colors.redAccent : AppColors.iconColor),
                                const SizedBox(width: 6),
                                Text("${post.likesCount}", style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailsPage(post: post)));
                              _loadMyPosts(silent: true);
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: AppColors.iconColor),
                                const SizedBox(width: 6),
                                Text("${post.commentsCount}", style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.textDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        onPressed: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagePostPage()));
          if (res == true) _loadMyPosts(silent: true);
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}