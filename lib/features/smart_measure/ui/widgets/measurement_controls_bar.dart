import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MeasurementControlsBar extends StatelessWidget {
  final VoidCallback onAddPoint;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onClear;
  final VoidCallback? onSave;
  final bool canUndo;
  final bool canRedo;
  final bool canSave;
  final int pointsCount;
  final String primaryActionLabel;

  const MeasurementControlsBar({
    super.key,
    required this.onAddPoint,
    this.onUndo,
    this.onRedo,
    this.onClear,
    this.onSave,
    this.canUndo = false,
    this.canRedo = false,
    this.canSave = false,
    this.pointsCount = 0,
    this.primaryActionLabel = 'Add Point',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.12), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Clear / Reset
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              color: pointsCount > 0 ? Colors.white70 : Colors.white24,
              tooltip: 'Clear',
              onPressed: pointsCount > 0
                  ? () {
                      HapticFeedback.lightImpact();
                      onClear?.call();
                    }
                  : null,
            ),

            // Undo
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              color: canUndo ? Colors.white : Colors.white24,
              tooltip: 'Undo',
              onPressed: canUndo
                  ? () {
                      HapticFeedback.lightImpact();
                      onUndo?.call();
                    }
                  : null,
            ),

            // Primary Add Point button
            GestureDetector(
              onTap: () {
                HapticFeedback.heavyImpact();
                onAddPoint();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      primaryActionLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Redo
            IconButton(
              icon: const Icon(Icons.redo_rounded),
              color: canRedo ? Colors.white : Colors.white24,
              tooltip: 'Redo',
              onPressed: canRedo
                  ? () {
                      HapticFeedback.lightImpact();
                      onRedo?.call();
                    }
                  : null,
            ),

            // Save Measurement
            IconButton(
              icon: const Icon(Icons.check_circle_rounded),
              color: canSave ? const Color(0xFF10B981) : Colors.white24,
              tooltip: 'Save Result',
              onPressed: canSave
                  ? () {
                      HapticFeedback.mediumImpact();
                      onSave?.call();
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
