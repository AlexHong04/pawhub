import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/current_user_store.dart';
import '../model/post_model.dart';
import '../../../core/utils/generatorId.dart';

class PostService {
  final _supabase = Supabase.instance.client;
  static final ValueNotifier<int> refreshTrigger = ValueNotifier(0);

  Future<String> getCurrentUserId() async {
    final userModel = await CurrentUserStore.read();
    if (userModel != null) {
      return userModel.id;
    }
    return "GUEST";
  }

  Future<String> getCurrentUserName() async {
    final userModel = await CurrentUserStore.read();
    if (userModel != null) {
      return userModel.name;
    }
    return "User";
  }

  String _getTimestamp() => DateTime.now().toString().split('.')[0];

  Future<List<CommunityPostModel>> fetchPosts() async {
    try {
      final String userId = await getCurrentUserId();
      final response = await _supabase
          .from('CommunityPost')
          .select('*, User!user_id(*), PostInteractions(*, User!user_id(name))')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List;

      return data
          .map((json) => CommunityPostModel.fromJson(json, userId))
          .toList();
    } catch (e) {
      debugPrint("Fetch Error: $e");
      return [];
    }
  }

  Future<bool> toggleLike(String postId) async {
    try {
      final String userId = await getCurrentUserId();
      final List<dynamic> existing = await _supabase
          .from('PostInteractions')
          .select()
          .eq('post_id', postId)
          .eq('user_id', userId)
          .filter('comment_text', 'is', null);

      if (existing.isEmpty) {
        final String newId = await GeneratorId.generateId(
          tableName: 'PostInteractions',
          idColumnName: 'interaction_id',
          prefix: 'PI',
          numberLength: 4,
        );
        await _supabase.from('PostInteractions').insert({
          'interaction_id': newId,
          'post_id': postId,
          'user_id': userId,
          'like': true,
          'comment_text': null,
          'created_at': _getTimestamp(),
        });
      } else {
        final String interactionId = existing[0]['interaction_id'];
        final bool currentLike = existing[0]['like'] ?? false;
        await _supabase
            .from('PostInteractions')
            .update({'like': !currentLike})
            .eq('interaction_id', interactionId);
      }
      refreshTrigger.value++;
      return true;
    } catch (e) {
      debugPrint("Toggle like error: $e");
      return false;
    }
  }

  Future<void> addComment(String postId, String text) async {
    final String userId = await getCurrentUserId();
    final String newId = await GeneratorId.generateId(
      tableName: 'PostInteractions',
      idColumnName: 'interaction_id',
      prefix: 'PI',
      numberLength: 4,
    );
    await _supabase.from('PostInteractions').insert({
      'interaction_id': newId,
      'post_id': postId,
      'user_id': userId,
      'comment_text': text,
      'like': false,
      'created_at': _getTimestamp(),
    });
  }

  Future<List<dynamic>> fetchComments(String postId) async {
    return await _supabase
        .from('PostInteractions')
        .select(
          'interaction_id, user_id, comment_text, created_at, User!user_id(name, avatar_url)',
        )
        .eq('post_id', postId)
        .filter('comment_text', 'not.is', null)
        .or('is_delete.eq.false,is_delete.is.null')
        .order('created_at', ascending: true);
  }

  Future<bool> deleteComment(String interactionId) async {
    try {
      await _supabase
          .from('PostInteractions')
          .update({'is_delete': true})
          .eq('interaction_id', interactionId);
      return true;
    } catch (e) {
      debugPrint("Delete comment error: $e");
      return false;
    }
  }

  Future<void> createPost({
    required String content,
    required bool isPrivate,
    required bool isAnonymous,
    String? imgUrl,
  }) async {
    final String userId = await getCurrentUserId();
    final String newPostId = await GeneratorId.generateId(
      tableName: 'CommunityPost',
      idColumnName: 'post_id',
      prefix: 'CP',
      numberLength: 4,
    );
    await _supabase.from('CommunityPost').insert({
      'post_id': newPostId,
      'user_id': userId,
      'content': content,
      'img_url': imgUrl,
      'is_private': isPrivate,
      'is_anonymous': isAnonymous,
      'is_active': true,
      'created_at': _getTimestamp(),
    });
  }

  Future<void> updatePost({
    required String postId,
    required String content,
    required bool isPrivate,
    String? imgUrl,
  }) async {
    await _supabase
        .from('CommunityPost')
        .update({
          'content': content,
          'img_url': imgUrl,
          'is_private': isPrivate,
          'updated_at': _getTimestamp(),
        })
        .eq('post_id', postId);
  }

  Future<void> deletePost(String postId) async {
    await _supabase
        .from('CommunityPost')
        .update({'is_active': false, 'updated_at': _getTimestamp()})
        .eq('post_id', postId);
  }

  Future<List<CommunityPostModel>> fetchRecentlyDeletedPosts() async {
    final String userId = await getCurrentUserId();
    final threshold = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

    final response = await _supabase
        .from('CommunityPost')
        .select('*, User!user_id(*)')
        .eq('user_id', userId)
        .eq('is_active', false)
        .gte('updated_at', threshold)
        .order('updated_at', ascending: false);

    final List<dynamic> data = response as List;
    return data.map((json) => CommunityPostModel.fromJson(json, userId)).toList();
  }

  Future<void> reactivePost(String postId) async {
    await _supabase
        .from('CommunityPost')
        .update({
      'is_active': true,
      'updated_at': _getTimestamp(),
    })
        .eq('post_id', postId);
  }

  Future<CommunityPostModel?> fetchPostById(String postId) async {
    try {
      final String userId = await getCurrentUserId();

      final response = await _supabase
          .from('CommunityPost')
          .select('*, User!user_id(*), PostInteractions(*, User!user_id(name))')
          .eq('post_id', postId)
          .eq('is_active', true)
          .single();

      return CommunityPostModel.fromJson(response, userId);
    } catch (e) {
      debugPrint("Fetch Post By ID Error: $e");
      return null;
    }
  }
  Future<int> fetchLikedPostsCountByUser(String userId) async {
    if (userId.trim().isEmpty) return 0;

    try {
      final response = await _supabase
          .from('PostInteractions')
          .select('post_id')
          .eq('user_id', userId)
          .eq('like', true)
          .filter('comment_text', 'is', null);

      final uniquePostIds = (response as List)
          .map((row) => (row['post_id'] ?? '').toString())
          .where((postId) => postId.trim().isNotEmpty)
          .toSet();

      return uniquePostIds.length;
    } catch (e) {
      debugPrint('Fetch liked posts count error: $e');
      return 0;
    }
  }

Future<List<CommunityPostModel>> fetchLikedPostsByUser(String userId) async {
  try {
    final String currentId = await getCurrentUserId();

    final interactionResponse = await _supabase
        .from('PostInteractions')
        .select('post_id')
        .eq('user_id', userId)
        .eq('like', true)
        .filter('comment_text', 'is', null);

    final List<dynamic> interactions = interactionResponse as List;
    if (interactions.isEmpty) return [];

    final List<String> likedPostIds = interactions
        .map((item) => item['post_id'].toString())
        .toList();

    final postsResponse = await _supabase
        .from('CommunityPost')
        .select('*, User!user_id(*), PostInteractions(*, User!user_id(name))')
        .filter('post_id', 'in', '(${likedPostIds.join(',')})')
        .eq('is_active', true)
        .order('created_at', ascending: false);

    final List<dynamic> postsData = postsResponse as List;

    return postsData
        .map((json) => CommunityPostModel.fromJson(json, currentId))
        .toList();
  } catch (e) {
    debugPrint("Fetch Liked Posts Error: $e");
    return [];
  }
}}
