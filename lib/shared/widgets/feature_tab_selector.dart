import 'package:flutter/material.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';

class FeatureTabItem<T> {
  final T value;
  final String label;
  final IconData? icon;

  const FeatureTabItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

class FeatureTabSelector<T> extends StatefulWidget {
  final List<FeatureTabItem<T>> tabs;
  final T activeTab;
  final ValueChanged<T> onTabSelected;
  final Color accentColor;
  final String? title;

  const FeatureTabSelector({
    super.key,
    required this.tabs,
    required this.activeTab,
    required this.onTabSelected,
    required this.accentColor,
    this.title,
  });

  @override
  State<FeatureTabSelector<T>> createState() => _FeatureTabSelectorState<T>();
}

class _FeatureTabSelectorState<T> extends State<FeatureTabSelector<T>> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _chipKeys = [];

  @override
  void initState() {
    super.initState();
    _chipKeys.addAll(List.generate(widget.tabs.length, (_) => GlobalKey()));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActiveTab(animated: false));
  }

  @override
  void didUpdateWidget(covariant FeatureTabSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabs.length != oldWidget.tabs.length) {
      _chipKeys.clear();
      _chipKeys.addAll(List.generate(widget.tabs.length, (_) => GlobalKey()));
    }
    if (widget.activeTab != oldWidget.activeTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActiveTab(animated: true));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveTab({bool animated = true}) {
    final activeIndex = widget.tabs.indexWhere((t) => t.value == widget.activeTab);
    if (activeIndex == -1 || activeIndex >= _chipKeys.length) return;

    final targetContext = _chipKeys[activeIndex].currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.5,
        duration: animated ? const Duration(milliseconds: 300) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _scrollBy(double offset) {
    if (!_scrollController.hasClients) return;
    PreferencesService().triggerHaptic();
    final target = (_scrollController.offset + offset).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _showAllTabsSheet(BuildContext context) {
    PreferencesService().triggerHaptic();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.grid_view_rounded, size: 20, color: widget.accentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title ?? 'All Available Features',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Select any of the ${widget.tabs.length} options to switch directly',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Grid of all features
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 420;
                      final crossAxisCount = isWide ? 3 : 2;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: isWide ? 2.1 : 1.9,
                        ),
                        itemCount: widget.tabs.length,
                        itemBuilder: (context, idx) {
                          final tab = widget.tabs[idx];
                          final isSelected = tab.value == widget.activeTab;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                PreferencesService().triggerHaptic();
                                Navigator.of(ctx).pop();
                                widget.onTabSelected(tab.value);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? widget.accentColor.withValues(alpha: 0.12)
                                      : (isDark ? AppColors.darkSurface : AppColors.lightCardHover),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? widget.accentColor
                                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                    width: isSelected ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (tab.icon != null) ...[
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? widget.accentColor
                                              : (isDark ? AppColors.darkCard : Colors.white),
                                          shape: BoxShape.circle,
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: widget.accentColor.withValues(alpha: 0.35),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Icon(
                                          tab.icon,
                                          size: 18,
                                          color: isSelected
                                              ? Colors.white
                                              : (isDark
                                                  ? AppColors.darkTextSecondary
                                                  : AppColors.lightTextSecondary),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Text(
                                        tab.label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          color: isSelected
                                              ? widget.accentColor
                                              : (isDark
                                                  ? AppColors.darkTextPrimary
                                                  : AppColors.lightTextPrimary),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                        color: widget.accentColor,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeIndex = widget.tabs.indexWhere((t) => t.value == widget.activeTab);
    final activeTabItem = activeIndex != -1 ? widget.tabs[activeIndex] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header summary row with "View All" button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Active tool preview indicator
            Expanded(
              child: GestureDetector(
                onTap: () => _showAllTabsSheet(context),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    if (activeTabItem?.icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          activeTabItem!.icon,
                          size: 16,
                          color: widget.accentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeTabItem?.label ?? 'Select Option',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            activeIndex != -1
                                ? 'Option ${activeIndex + 1} of ${widget.tabs.length}'
                                : '${widget.tabs.length} options',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Right: "View All (X)" prominent button
            InkWell(
              onTap: () => _showAllTabsSheet(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grid_view_rounded, size: 14, color: widget.accentColor),
                    const SizedBox(width: 5),
                    Text(
                      'All (${widget.tabs.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Horizontal Chip row with Left & Right scroll assistance buttons
        Row(
          children: [
            // Left Chevron Scroll Button
            _buildScrollArrow(
              icon: Icons.chevron_left_rounded,
              onTap: () => _scrollBy(-180),
              isDark: isDark,
            ),
            const SizedBox(width: 4),

            // Scrollable chips
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: List.generate(widget.tabs.length, (idx) {
                    final tab = widget.tabs[idx];
                    final isSelected = tab.value == widget.activeTab;

                    return Padding(
                      key: _chipKeys[idx],
                      padding: EdgeInsets.only(
                        right: idx == widget.tabs.length - 1 ? 0 : 8.0,
                      ),
                      child: FilterChip(
                        showCheckmark: false,
                        avatar: tab.icon != null
                            ? Icon(
                                tab.icon,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              )
                            : null,
                        label: Text(tab.label),
                        selected: isSelected,
                        selectedColor: widget.accentColor,
                        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightCardHover,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? widget.accentColor
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                        onSelected: (val) {
                          if (val) {
                            PreferencesService().triggerHaptic();
                            widget.onTabSelected(tab.value);
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
            ),

            const SizedBox(width: 4),
            // Right Chevron Scroll Button
            _buildScrollArrow(
              icon: Icons.chevron_right_rounded,
              onTap: () => _scrollBy(180),
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScrollArrow({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 28,
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightCardHover,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }
}
