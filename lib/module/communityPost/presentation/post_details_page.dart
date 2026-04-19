import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/constants/colors.dart';
import '../../../core/utils/local_file_service.dart';
import '../model/post_model.dart';
import '../service/post_service.dart';
import '../../../core/utils/qr_service.dart';
import 'manage_post.dart';

class PostDetailsPage extends StatefulWidget {
  final CommunityPostModel post;
  final bool isAdmin;

  const PostDetailsPage({super.key, required this.post, this.isAdmin = false});

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  final PostService _service = PostService();
  final TextEditingController _commentController = TextEditingController();
  List<dynamic> _allComments = [];
  bool _isLoading = true;

  String _currentUserId = 'GUEST';
  String _currentUserName = "Me";
  String? _currentUserAvatar;

  // Speech Recognition States
  late stt.SpeechToText _speechToText;
  bool _isListening = false;

  String _currentLocaleId = 'en_US';
  String _textBeforeListening = "";

  final Map<String, String> _supportedLocales = {
    'en_US': 'EN',
    'zh_CN': '华',
    'ms_MY': 'BM',
  };

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _initializeData();
  }

  Future<void> _initializeData() async {
    _currentUserId = await _service.getCurrentUserId();
    _currentUserName = await _service.getCurrentUserName();

    bool isOwner = widget.post.userId == _currentUserId;
    bool canView = true;

    if (widget.post.isPrivate && !isOwner && !widget.isAdmin) {
      canView = false;
    }

    if (!canView) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You do not have permission to view this post."),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }
    await Future.wait([_loadComments(), _loadCurrentUserAvatar()]);
  }

  Future<void> _loadCurrentUserAvatar() async {
    try {
      final supabase = Supabase.instance.client;
      final userData = await supabase
          .from('User')
          .select('avatar_url')
          .eq('user_id', _currentUserId)
          .maybeSingle();

      if (userData != null && mounted) {
        setState(() {
          _currentUserAvatar = userData['avatar_url'];
        });
      }
    } catch (e) {
      debugPrint("Load current user avatar error: $e");
    }
  }

  Future<void> _loadComments() async {
    final data = await _service.fetchComments(widget.post.postId);
    if (mounted) {
      setState(() {
        _allComments = List.from(data);
        _isLoading = false;
      });
    }
  }

  String _formatDetailsTime(dynamic timestamp) {
    if (timestamp == null) return "Just now";
    DateTime time = timestamp is DateTime
        ? timestamp
        : DateTime.parse(timestamp.toString());

    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inHours >= 24) {
      return time.toString().split('.')[0].substring(0, 16);
    }

    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';

    return 'Just now';
  }

  void _openImageFullscreen(int initialIndex, List<String> urls) {
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
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: pageController,
                    itemCount: urls.length,
                    onPageChanged: (index) =>
                        setDialogState(() => currentIndex = index),
                    itemBuilder: (context, index) {
                      final String url = urls[index];
                      final String fileName = url.split('/').last.split('?').first;

                      return InteractiveViewer(
                        child: Center(
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return FutureBuilder<File?>(
                                future: LocalFileService.loadSavedImage(fileName),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data != null) {
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
                  if (urls.length > 1)
                    Positioned(
                      top: 45,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          "${currentIndex + 1} / ${urls.length}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
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
                            width: currentIndex == index ? 8.0 : 6.0,
                            height: currentIndex == index ? 8.0 : 6.0,
                            decoration: BoxDecoration(
                              color: currentIndex == index
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

  void _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    if (_isListening) {
      _speechToText.stop();
      setState(() => _isListening = false);
    }

    _commentController.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _allComments.add({
        'user_id': _currentUserId,
        'comment_text': text,
        'created_at': DateTime.now().toIso8601String(),
        'User': {'name': _currentUserName, 'avatar_url': _currentUserAvatar},
      });
      //update for comment count
      widget.post.commentsCount++;
    });

    await _service.addComment(widget.post.postId, text);
    _loadComments();
  }

  void _confirmDeleteComment(int index, dynamic comment) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
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
              Text(
                widget.isAdmin ? "Delete Comment?" : "Delete Comment?",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "This action cannot be undone. Are you sure you want to remove this comment?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
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
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteComment(index, comment);
                      },
                      child: const Text(
                        "Delete",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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

  Future<void> _deleteComment(int index, dynamic comment) async {
    final interactionId = comment['interaction_id'];
    setState(() {
      _allComments.removeAt(index);
      // update for comment count
      if (widget.post.commentsCount > 0) {
        widget.post.commentsCount--;
      }
    });

    if (interactionId != null) {
      final success = await _service.deleteComment(interactionId.toString());
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to delete comment from server."),
            backgroundColor: Colors.redAccent,
          ),
        );
        _loadComments();
      }
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speechToText.initialize(
        onStatus: (val) => debugPrint('onStatus: $val'),
        onError: (val) => debugPrint('onError: $val'),
      );

      if (available) {
        setState(() {
          _isListening = true;
          _textBeforeListening = _commentController.text;
        });

        _speechToText.listen(
          onResult: (val) => setState(() {
            String combinedText = _textBeforeListening;

            if (combinedText.isNotEmpty && !combinedText.endsWith(' ')) {
              combinedText += ' ';
            }

            combinedText += val.recognizedWords;

            _commentController.text = combinedText;

            _commentController.selection = TextSelection.fromPosition(
              TextPosition(offset: _commentController.text.length),
            );
          }),
          localeId: _currentLocaleId,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Microphone permission denied.")),
          );
        }
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Comments",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (widget.post.userId == _currentUserId)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManagePostPage(post: widget.post),
                  ),
                );

                if (result == true && mounted) {
                  setState(() {
                  });
                }
              },
            ),

          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black87),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => QRDialog(
                  title: "Share Post",
                  data: "pawhub://post/${widget.post.postId}",
                  showSaveButton: true,
                  shareText: "🐾 Look at this adorable post on PawHub!\n\n"
                      "👤 Posted by: ${widget.post.userName}\n\n"
                      "✨ Click the link to view the full story:\n"
                      "https://pawhub.hongjin.site/post/${widget.post.postId}\n\n"
                      "❤️ Join our pet-loving community today!",
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
                : ListView(
              children: [
                _buildOriginalPost(),
                Container(height: 8, color: Colors.grey.shade100),
                _buildCommentList(),
              ],
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildOriginalPost() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Builder(
                builder: (context) {
                  bool hasValidAvatar = widget.post.userAvatar != null &&
                      widget.post.userAvatar!.trim().isNotEmpty &&
                      widget.post.userAvatar!.startsWith('http');
                  return CircleAvatar(
                    backgroundImage: hasValidAvatar
                        ? NetworkImage(widget.post.userAvatar!)
                        : null,
                    child: !hasValidAvatar ? const Icon(Icons.person) : null,
                  );
                },
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.post.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatDetailsTime(widget.post.createdAt),
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.post.content,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 12),
          _buildPostImages(),

          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (widget.post.isLiked) {
                      widget.post.likesCount--;
                      widget.post.isLiked = false;
                    } else {
                      widget.post.likesCount++;
                      widget.post.isLiked = true;
                    }
                  });
                  _service.toggleLike(widget.post.postId);
                },
                child: Row(
                  children: [
                    Icon(
                      widget.post.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: widget.post.isLiked ? Colors.redAccent : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${widget.post.likesCount}",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    "${widget.post.commentsCount}",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostImages() {
    final urls = widget.post.fullImageUrls;
    if (urls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _openImageFullscreen(i, urls),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Builder(
                builder: (context) {
                  final String url = urls[i];
                  final String fileName = url.split('/').last.split('?').first;
                  return Image.network(
                    url,
                    width: 280,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return FutureBuilder<File?>(
                        future: LocalFileService.loadSavedImage(fileName),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return Image.file(
                              snapshot.data!,
                              width: 280,
                              fit: BoxFit.cover,
                            );
                          }
                          return Container(
                            width: 280,
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
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentList() {
    if (_allComments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text(
            "No comments yet. Be the first to comment!",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _allComments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final c = _allComments[index];

        final userData = c['User'] ?? {};
        final String displayName =
            userData['name'] ?? c['name'] ?? c['user_id'] ?? "User";
        final String? avatarUrl = userData['avatar_url'];

        bool hasValidAvatar = avatarUrl != null &&
            avatarUrl.trim().isNotEmpty &&
            avatarUrl.startsWith('http');

        final bool canDelete = widget.isAdmin || c['user_id'] == _currentUserId;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: hasValidAvatar ? NetworkImage(avatarUrl) : null,
              child: !hasValidAvatar
                  ? Text(
                displayName.isNotEmpty
                    ? displayName[0].toUpperCase()
                    : 'U',
              )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _formatDetailsTime(c['created_at']),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                            if (canDelete) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _confirmDeleteComment(index, c),
                                child: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c['comment_text'] ?? "",
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 12,
        left: 16,
        right: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: _isListening ? "Listening..." : "Add a comment...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                      color: _isListening ? Colors.redAccent : Colors.grey),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          Container(
            height: 48,
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                PopupMenuButton<String>(
                  initialValue: _currentLocaleId,
                  tooltip: 'Change Language',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _supportedLocales[_currentLocaleId]!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  onSelected: (String locale) {
                    setState(() {
                      _currentLocaleId = locale;
                    });
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      const PopupMenuItem(
                          value: 'en_US', child: Text('English (EN)')),
                      const PopupMenuItem(
                          value: 'zh_CN', child: Text('华语 (Chinese)')),
                      const PopupMenuItem(
                          value: 'ms_MY', child: Text('Bahasa Melayu (BM)')),
                    ];
                  },
                ),
                IconButton(
                  onPressed: _listen,
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.redAccent : Colors.grey.shade600,
                    size: 24,
                  ),
                ),
                IconButton(
                  onPressed: _submitComment,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}