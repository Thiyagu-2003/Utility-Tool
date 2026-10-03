import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ToolBoxProIcon extends StatelessWidget {
  final double size;
  final bool showHandle;

  const ToolBoxProIcon({
    super.key,
    this.size = 56,
    this.showHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final double tileSize = (size * 0.34);
    final double tileRadius = size * 0.09;
    final double iconSize = size * 0.20;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Briefcase Handle Arch
          if (showHandle)
            Positioned(
              top: size * 0.04,
              child: Container(
                width: size * 0.42,
                height: size * 0.22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(size * 0.12)),
                  border: Border.all(
                    color: const Color(0xFF2A3042),
                    width: size * 0.06,
                  ),
                ),
              ),
            ),

          // Main Toolbox Body Squircle
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: size * 0.90,
              height: size * 0.90,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E2230),
                    Color(0xFF0F121C),
                  ],
                ),
                borderRadius: BorderRadius.circular(size * 0.24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: size * 0.18,
                    offset: Offset(0, size * 0.08),
                  ),
                ],
              ),
              padding: EdgeInsets.all(size * 0.11),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Tile 1: Blue Calculator
                      _buildTile(
                        size: tileSize,
                        radius: tileRadius,
                        color: const Color(0xFF0284C7),
                        icon: Icons.calculate_rounded,
                        iconSize: iconSize,
                      ),
                      SizedBox(width: size * 0.04),
                      // Tile 2: Green Image/Gallery
                      _buildTile(
                        size: tileSize,
                        radius: tileRadius,
                        color: const Color(0xFF10B981),
                        icon: Icons.photo_library_rounded,
                        iconSize: iconSize,
                      ),
                    ],
                  ),
                  SizedBox(height: size * 0.04),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Tile 3: Orange Document
                      _buildTile(
                        size: tileSize,
                        radius: tileRadius,
                        color: const Color(0xFFF59E0B),
                        icon: Icons.description_rounded,
                        iconSize: iconSize,
                      ),
                      SizedBox(width: size * 0.04),
                      // Tile 4: Purple Gear / Settings
                      _buildTile(
                        size: tileSize,
                        radius: tileRadius,
                        color: const Color(0xFF8B5CF6),
                        icon: Icons.settings_rounded,
                        iconSize: iconSize,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required double size,
    required double radius,
    required Color color,
    required IconData icon,
    required double iconSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: iconSize,
      ),
    );
  }
}

class ToolBoxProLogo extends StatelessWidget {
  final double iconSize;
  final bool showTagline;

  const ToolBoxProLogo({
    super.key,
    this.iconSize = 44,
    this.showTagline = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ToolBoxProIcon(size: iconSize),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ToolBox',
                  style: TextStyle(
                    fontSize: iconSize * 0.44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                ShaderMask(
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                    ).createShader(bounds);
                  },
                  child: Text(
                    'Pro',
                    style: TextStyle(
                      fontSize: iconSize * 0.44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            if (showTagline) ...[
              const SizedBox(height: 2),
              Text(
                'All Your Tools. One App.',
                style: TextStyle(
                  fontSize: iconSize * 0.22,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
