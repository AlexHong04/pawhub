import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityPostModel {
  final String postId;
  final String userId;
  final String content;
  final String? imgUrl;
  final bool isPrivate;
  final bool isAnonymous;
  final bool isActive;
  final DateTime createdAt;
  final String userName;
  final String userRole;
  final String? userAvatar;
  final bool isVolunteer;
  int likesCount;
  int commentsCount;
  bool isLiked;
  List<dynamic> previewComments;

  CommunityPostModel({
    required this.postId,
    required this.userId,
    required this.content,
    this.imgUrl,
    required this.isPrivate,
    required this.isAnonymous,
    required this.isActive,
    required this.createdAt,
    required this.userName,
    required this.userRole,
    this.userAvatar,
    required this.isVolunteer,
    required this.likesCount,
    required this.commentsCount,
    required this.isLiked,
    required this.previewComments,
  });

  List<String> get fullImageUrls {
    if (imgUrl == null || imgUrl!.isEmpty) return [];
    return imgUrl!
        .split(',')
        .map(
          (fileName) => Supabase.instance.client.storage
              .from('documents')
              .getPublicUrl('post_images/${fileName.trim()}'),
        )
        .toList();
  }

  factory CommunityPostModel.fromJson(
    Map<String, dynamic> data,
    String currentUser,
  ) {
    final userData = data['User'] ?? {};
    final interactions = data['PostInteractions'] as List<dynamic>? ?? [];

    final bool anonymous = data['is_anonymous'] ?? false;

    final String finalUserName = anonymous
        ? "Anonymous Account"
        : (userData['name'] ?? "Unknown");
    final String? finalAvatar = anonymous ? null : userData['avatar_url'];

    final likesList = interactions
        .where(
          (i) =>
              i['like'] == true &&
              (i['comment_text'] == null ||
                  i['comment_text'].toString().isEmpty),
        )
        .toList();
    final commentsList = interactions
        .where(
          (i) =>
              i['is_delete'] != true &&
              i['comment_text'] != null &&
              i['comment_text'].toString().isNotEmpty,
        )
        .toList();
    final likedByMe = interactions.any(
      (i) =>
          i['user_id'] == currentUser &&
          i['like'] == true &&
          i['comment_text'] == null,
    );

    final previewComments = commentsList.map((c) {
      final interactionUser = c['User'] ?? {};
      return {
        'name': interactionUser['name'] ?? c['user_id'] ?? "User",
        'comment_text': c['comment_text'] ?? "",
      };
    }).toList();

    return CommunityPostModel(
      postId: data["post_id"].toString(),
      userId: data["user_id"].toString(),
      content: data["content"] ?? "",
      imgUrl: data["img_url"],
      isPrivate: data["is_private"] ?? false,
      isAnonymous: anonymous,
      isActive: data["is_active"] ?? true,
      createdAt: data['created_at'] is String
          ? DateTime.parse(data['created_at'])
          : DateTime.now(),
      userName: finalUserName,
      userRole: userData['role'] ?? "User",
      isVolunteer: userData['is_volunteer'] ?? false,
      userAvatar: finalAvatar,
      likesCount: likesList.length,
      commentsCount: commentsList.length,
      isLiked: likedByMe,
      previewComments: previewComments,
    );
  }
}
