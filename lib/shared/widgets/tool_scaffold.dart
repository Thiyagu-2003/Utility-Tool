import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';

class ToolScaffold extends StatelessWidget {
  final String title;
  final ToolCategory category;
  final String toolId;
  final Widget body;
  final VoidCallback? onReset;
  final List<Widget>? actions;
  final bool isScrollable;
  final EdgeInsetsGeometry? padding;

  const ToolScaffold({
    super.key,
    required this.title,
    required this.category,
    required this.toolId,
    required this.body,
    this.onReset,
    this.actions,
    this.isScrollable = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefs = PreferencesService();

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCardHover,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            ),
            onPressed: () {
              prefs.triggerHaptic();
              Navigator.of(context).pop();
            },
          ),
        ),
        title: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                category.label.toUpperCase(),
                style: TextStyle(
                  color: category.color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: prefs,
            builder: (context, _) {
              final isFav = prefs.isFavorite(toolId);
              return IconButton(
                tooltip: isFav ? 'Remove from Favorites' : 'Add to Favorites',
                icon: Icon(
                  isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFav ? AppColors.primaryOrange : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  size: 24,
                ),
                onPressed: () => prefs.toggleFavorite(toolId),
              );
            },
          ),
          if (onReset != null)
            IconButton(
              tooltip: 'Reset Fields',
              icon: Icon(
                Icons.refresh_rounded,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              onPressed: () {
                prefs.triggerHaptic();
                onReset!();
              },
            ),
          if (actions != null) ...actions!,
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        left: true,
        right: true,
        bottom: true,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: isScrollable
                  ? SingleChildScrollView(
                      padding: padding ?? const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      physics: const BouncingScrollPhysics(),
                      child: body,
                    )
                  : Padding(
                      padding: padding ?? const EdgeInsets.only(bottom: 8),
                      child: body,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
