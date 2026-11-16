import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Interactive high-tech reticle that pulses and displays real-time depth targeting.
class ARReticle extends StatefulWidget {
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
  State<ARReticle> createState() => _ARReticleState();
}

class _ARReticleState extends State<ARReticle> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColor = widget.isLockedOnSurface
        ? const Color(0xFF10B981) // Emerald green when locked
        : Colors.white;

    return Center(
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final pulse = widget.isLockedOnSurface ? (1.0 + _animController.value * 0.08) : 1.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 68 * pulse,
                height: 68 * pulse,
                child: CustomPaint(
                  painter: _ReticlePainter(
                    color: ringColor,
                    isLocked: widget.isLockedOnSurface,
                    animVal: _animController.value,
                  ),
                ),
              ),
              if (widget.distanceDisplay != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.isLockedOnSurface ? const Color(0xFF10B981) : Colors.white24,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                      )
                    ],
                  ),
                  child: Text(
                    widget.distanceDisplay!,
                    style: TextStyle(
                      color: widget.isLockedOnSurface ? const Color(0xFF10B981) : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final Color color;
  final bool isLocked;
  final double animVal;

  _ReticlePainter({
    required this.color,
    required this.isLocked,
    required this.animVal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Center precision dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, isLocked ? 4.0 : 3.0, dotPaint);

    // Inner glow when locked
    if (isLocked) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius * 0.6, glowPaint);
    }

    // Outer segmented circular ring
    final ringPaint = Paint()
      ..color = color.withOpacity(isLocked ? 0.9 : 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isLocked ? 2.2 : 1.6;

    // 4 arc segments
    const sweep = (math.pi / 2) - 0.35;
    for (int i = 0; i < 4; i++) {
      final startAngle = (i * math.pi / 2) + 0.175;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        ringPaint,
      );
    }

    // Alignment crosshair tick marks
    final tickPaint = Paint()
      ..color = color.withOpacity(isLocked ? 1.0 : 0.7)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final tickLen = isLocked ? 7.0 : 5.0;

    // Top tick
    canvas.drawLine(Offset(center.dx, center.dy - radius - 2), Offset(center.dx, center.dy - radius - 2 - tickLen), tickPaint);
    // Bottom tick
    canvas.drawLine(Offset(center.dx, center.dy + radius + 2), Offset(center.dx, center.dy + radius + 2 + tickLen), tickPaint);
    // Left tick
    canvas.drawLine(Offset(center.dx - radius - 2, center.dy), Offset(center.dx - radius - 2 - tickLen, center.dy), tickPaint);
    // Right tick
    canvas.drawLine(Offset(center.dx + radius + 2, center.dy), Offset(center.dx + radius + 2 + tickLen, center.dy), tickPaint);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isLocked != isLocked ||
        oldDelegate.animVal != animVal;
  }
}
