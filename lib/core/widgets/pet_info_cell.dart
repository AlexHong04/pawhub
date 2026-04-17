import 'package:flutter/material.dart';

class InfoCell extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? textColor;

  const InfoCell({
    super.key,
    required this.icon,
    required this.text,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: textColor ?? Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}