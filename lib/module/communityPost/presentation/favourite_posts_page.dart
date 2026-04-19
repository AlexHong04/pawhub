import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/qr_service.dart'; // Ensure QRDialog is imported
import '../model/post_model.dart';
import '../service/post_service.dart';
import 'post_details_page.dart';

//displays a list of posts the user has liked
class FavouritePostsPage extends StatefulWidget {
  final String userId;

  const FavouritePostsPage({super.key, required this.userId});

  @override
  State<FavouritePostsPage> createState() => _FavouritePostsPageState();
}

class _FavouritePostsPageState extends State<FavouritePostsPage> {
  final PostService _postService = PostService();

  // List to store the fetched favourite posts
  List<CommunityPostModel> _favouritePosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavourites();
  }

  Future<void> _loadFavourites() async {
    setState(() => _isLoading = true);

    try {
      final posts = await _postService.fetchLikedPostsByUser(widget.userId);

      if (mounted) {
        setState(() {
          _favouritePosts = posts.where((post) {
            bool canSee = !post.isPrivate || (post.userId == widget.userId);
            return canSee;
          }).toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading favourites: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Favourites",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
        onRefresh: _loadFavourites, // Allow users to pull-to-refresh
        color: AppColors.primary,
        child: _favouritePosts.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: _favouritePosts.length,
          itemBuilder: (context, index) {
            final post = _favouritePosts[index];
            return _buildEnhancedPostCard(post, index);
          },
        ),
      ),
    );
  }

  Widget _buildEnhancedPostCard(CommunityPostModel post, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PostDetailsPage(post: post)),
          ).then((_) => _loadFavourites()),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey.shade100,
                      backgroundImage: (post.userAvatar != null && post.userAvatar!.startsWith('http'))
                          ? NetworkImage(post.userAvatar!)
                          : null,
                      child: post.userAvatar == null ? const Icon(Icons.person, color: Colors.grey) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.userName,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          Text(
                            "${post.likesCount} likes",
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    // "Unlike" button inside the card header
                    IconButton(
                      onPressed: () => _handleUnlike(post, index),
                      style: IconButton.styleFrom(backgroundColor: Colors.red.shade50),
                      icon: const Icon(Icons.favorite, color: Colors.redAccent, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Content: Post Text
                Text(
                  post.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                ),

                // Media: Display thumbnail if image exists
                if (post.fullImageUrls.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        post.fullImageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade50,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],

                // Footer: Interaction info & Share Button
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.grey.shade400),
                        const SizedBox(width: 6),
                        Text(
                          "${post.commentsCount} comments",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => QRDialog(
                            title: "Share Post",
                            data: "pawhub://post/${post.postId}",
                            showSaveButton: true,
                            shareText: "🐾 Check out this favourite post on PawHub!\n\n"
                                "👤 Posted by: ${post.userName}\n\n"
                                "✨ Read the full story here:\n"
                                "https://pawhub.hongjin.site/post/${post.postId}",
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.share_outlined, size: 18, color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Removes the post from favourites with an optimistic UI update.
  void _handleUnlike(CommunityPostModel post, int index) async {
    setState(() {
      _favouritePosts.removeAt(index);
    });

    try {
      await _postService.toggleLike(post.postId);
      PostService.refreshTrigger.value++;
    } catch (e) {
      debugPrint("Unlike failed: $e");
      _loadFavourites();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Action failed. Reverting changes.")),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.favorite_outline_rounded, size: 60, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          const Text(
            "No favourites yet",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          const Text(
            "Posts you like will appear here.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}