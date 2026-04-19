import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pawhub/core/constants/colors.dart';
import 'package:pawhub/core/utils/local_file_service.dart';
import 'dart:async';

const String kProfileAvatarStorageKeyPrefix = 'profile_edit_avatar_path';

String profileAvatarStorageKey(
  String userId, {
  String prefix = kProfileAvatarStorageKeyPrefix,
}) {
  if (userId.trim().isEmpty) return '';
  return '${prefix}_${userId.trim()}';
}

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.previewFile,
    this.radius = 28,
    this.backgroundColor = AppColors.background,
    this.storageKeyPrefix = kProfileAvatarStorageKeyPrefix,
    this.fallbackTextStyle,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final File? previewFile;
  final double radius;
  final Color backgroundColor;
  final String storageKeyPrefix;
  final TextStyle? fallbackTextStyle;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  Future<File?>? _localAvatarFuture;

  @override
  void initState() {
    super.initState();
    _loadLocalAvatar();
  }

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.storageKeyPrefix != widget.storageKeyPrefix) {
      _loadLocalAvatar();
    }
  }

  void _loadLocalAvatar() {
    final storageKey = profileAvatarStorageKey(
      widget.userId,
      prefix: widget.storageKeyPrefix,
    );

    _localAvatarFuture = storageKey.isEmpty
        ? Future<File?>.value(null)
        : LocalFileService.loadSavedImage(storageKey);
  }

  Widget _buildFallbackInitials() {
    final name = widget.name.trim();
    final initials = name.isEmpty
        ? '?'
        : name
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part[0])
            .join()
            .toUpperCase();

    return Center(
      child: Text(
        initials,
        style: widget.fallbackTextStyle ?? const TextStyle(
          color: AppColors.errorRed,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewFile = widget.previewFile;
    final avatarUrl = widget.avatarUrl?.trim() ?? '';
    final hasNetworkAvatar = avatarUrl.isNotEmpty && avatarUrl.startsWith('http');
    final diameter = widget.radius * 2;

    if (previewFile != null) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.backgroundColor,
        child: ClipOval(
          child: Image.file(
            previewFile,
            width: diameter,
            height: diameter,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return FutureBuilder<File?>(
      future: _localAvatarFuture,
      builder: (context, snapshot) {
        final localAvatar = snapshot.data;

        Widget avatarChild;
        final hasLocalAvatar = localAvatar != null;
        if (hasNetworkAvatar) {
          avatarChild = _buildNetworkImageWithFallback(
            avatarUrl,
            diameter,
            hasLocalAvatar ? localAvatar : null,
          );
        } else if (hasLocalAvatar) {
          debugPrint('📱 Showing cached local avatar for user: ${widget.userId}');
          avatarChild = Image.file(
            localAvatar,
            width: diameter,
            height: diameter,
            fit: BoxFit.cover,
          );
        } else {
          avatarChild = _buildFallbackInitials();
        }

        return CircleAvatar(
          radius: widget.radius,
          backgroundColor: widget.backgroundColor,
          child: ClipOval(child: avatarChild),
        );
      },
    );
  }

  Widget _buildNetworkImageWithFallback(
    String avatarUrl,
    double diameter,
    File? localAvatar,
  ) {
    return Image.network(
      avatarUrl,
      width: diameter,
      height: diameter,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        if (localAvatar != null) {
          return Image.file(
            localAvatar,
            width: diameter,
            height: diameter,
            fit: BoxFit.cover,
          );
        }
        return _buildFallbackInitials();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        if (localAvatar != null) {
          return Image.file(
            localAvatar,
            width: diameter,
            height: diameter,
            fit: BoxFit.cover,
          );
        }
        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}

