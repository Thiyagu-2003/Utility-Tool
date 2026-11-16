import 'package:flutter/material.dart';
import '../../models/smart_measure_capability.dart';

class ConfidencePill extends StatelessWidget {
  final TrackingConfidence confidence;
  final String? errorMargin;
  final VoidCallback? onTap;

  const ConfidencePill({
    super.key,
    required this.confidence,
    this.errorMargin,
    this.onTap,
  });

  Color get _badgeColor {
    switch (confidence) {
      case TrackingConfidence.high:
        return const Color(0xFF10B981);
      case TrackingConfidence.medium:
        return const Color(0xFFF59E0B);
      case TrackingConfidence.low:
        return const Color(0xFFF97316);
      case TrackingConfidence.unavailable:
        return const Color(0xFFEF4444);
    }
  }

  IconData get _badgeIcon {
    switch (confidence) {
      case TrackingConfidence.high:
        return Icons.verified_rounded;
      case TrackingConfidence.medium:
        return Icons.speed_rounded;
      case TrackingConfidence.low:
        return Icons.warning_amber_rounded;
      case TrackingConfidence.unavailable:
        return Icons.signal_cellular_connected_no_internet_0_bar_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _badgeColor.withOpacity(0.8), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: _badgeColor.withOpacity(0.2),
              blurRadius: 6,
              spreadRadius: 1,
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_badgeIcon, size: 14, color: _badgeColor),
            const SizedBox(width: 6),
            Text(
              confidence.label,
              style: TextStyle(
                color: _badgeColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (errorMargin != null) ...[
              const SizedBox(width: 6),
              Container(
                width: 3,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                errorMargin!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
