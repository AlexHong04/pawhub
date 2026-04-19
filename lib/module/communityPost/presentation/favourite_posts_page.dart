import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
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

      // Ensure the widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _favouritePosts = posts;
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
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text("Favourites", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      // Display a loading spinner, an empty state, or the list of posts based on the current state
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _favouritePosts.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _favouritePosts.length,
        itemBuilder: (context, index) {
          final post = _favouritePosts[index];
          return _buildPostCard(post, index);
        },
      ),
    );
  }

  Widget _buildPostCard(CommunityPostModel post, int index) {
    return GestureDetector(
      onTap: () => Navigator.push(context,MaterialPageRoute(builder: (context) => PostDetailsPage(post: post)),
      ).then((_) => _loadFavourites()),

      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: (post.userAvatar != null && post.userAvatar!.startsWith('http'))
                    ? NetworkImage(post.userAvatar!)
                    : null,
                child: post.userAvatar == null ? const Icon(Icons.person) : null,
              ),
              title: Text(post.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                "${post.likesCount} likes",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.favorite, color: Colors.redAccent),
                onPressed: () => _handleUnlike(post, index),
              ),
            ),

            Text(
              post.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),

            if (post.fullImageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    post.fullImageUrls.first, // Display only the first image as a thumbnail
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleUnlike(CommunityPostModel post, int index) async {
    setState(() {
      _favouritePosts.removeAt(index);
    });

    try {
      // Send the unlike request to the backend
      await _postService.toggleLike(post.postId);

      // trigger post's like status changed
      PostService.refreshTrigger.value++;

    } catch (e) {
      debugPrint("Unlike failed: $e");
      _loadFavourites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Action failed. Please try again.")),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.favorite_border, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text("No favourite posts yet.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}