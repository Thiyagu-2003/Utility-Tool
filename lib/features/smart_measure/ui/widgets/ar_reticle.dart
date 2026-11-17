import 'package:flutter/material.dart';

/// Minimal iPhone-Measure-style aiming reticle: a small ring with a centre dot.
/// (Replaces the old pulsing ring with arc segments, tick marks and glow.)
class ARReticle extends StatelessWidget {
  final bool isLockedOnSurface;
  final double? liveDistanceMeters;
  final String? distanceDisplay;

  const ARReticle({
    super.key,
    required this.isLockedOnSurface,
    this.liveDistanceMeters,
    this.distanceDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final color = isLockedOnSurface ? Colors.white : Colors.white.withValues(alpha: 0.6);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 3)],
            ),
            child: Center(
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ),
          ),
          if (distanceDisplay != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
              ),
              child: Text(
                distanceDisplay!,
                style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
