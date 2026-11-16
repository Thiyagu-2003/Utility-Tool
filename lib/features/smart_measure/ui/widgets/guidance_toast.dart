import 'package:flutter/material.dart';

class GuidanceToast extends StatelessWidget {
  final String message;
  final IconData icon;
  final bool isWarning;

  const GuidanceToast({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isWarning
        ? const Color(0xFFEF4444).withOpacity(0.85)
        : Colors.black.withOpacity(0.7);

    final borderColor = isWarning
        ? const Color(0xFFFCA5A5)
        : Colors.white24;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
