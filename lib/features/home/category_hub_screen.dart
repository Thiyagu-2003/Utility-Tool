import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/tool_model.dart';
import '../../core/registry/tool_registry.dart';
import '../../core/services/preferences_service.dart';
import '../../core/services/search_calculator_service.dart';
import '../../core/theme/app_colors.dart';
import '../history/calculation_history_screen.dart';
import '../slate/slate_screen.dart';
import 'section_detail_screen.dart';

class CategoryHubScreen extends StatefulWidget {
  final ToolCategory? initialCategory;
  final bool isFinanceFocused;

  const CategoryHubScreen({
    super.key,
    this.initialCategory,
    this.isFinanceFocused = false,
  });

  @override
  State<CategoryHubScreen> createState() => _CategoryHubScreenState();
}

class _CategoryHubScreenState extends State<CategoryHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isEditMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openTool(BuildContext context, ToolItem tool) {
    PreferencesService().triggerHaptic();
    PreferencesService().addRecent(tool.id);
    Navigator.of(context).push(
      MaterialPageRoute(builder: tool.builder),
    );
  }

  void _openSection(BuildContext context, ToolCategory category) {
    PreferencesService().triggerHaptic();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SectionDetailScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefs = PreferencesService();

    if (widget.isFinanceFocused) {
      return _buildFinanceDedicatedView(context, isDark);
    }

    final isSearching = _searchQuery.trim().isNotEmpty;
    final searchResults = isSearching ? ToolRegistry.searchTools(_searchQuery) : <ToolItem>[];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header + Search
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Header Row: Logo + Offline Badge + History Shortcut
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // App logo tile 48x48, radius 14, with ToolBox Pro icon
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.35 : 0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF0F172A),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.construction_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Title "ToolBox" in #0F172A + "Pro" in #0369A1, 21sp bold; tagline 13sp #475569
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'ToolBox',
                                    style: GoogleFonts.outfit(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.4,
                                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Pro',
                                    style: GoogleFonts.outfit(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.4,
                                      color: const Color(0xFF0369A1),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'All Your Tools. One App.',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        // "100% Offline" pill: bg #CCFBF1, 1.5 border #0D9488, text #115E59 bold 13sp
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF042F2E) : const Color(0xFFCCFBF1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF0D9488),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '100% Offline',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF115E59),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // History button: 44x44 circle, white, 1.5 border #CBD5E1, bold clock-history icon
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              PreferencesService().triggerHaptic();
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const CalculationHistoryScreen()),
                              );
                            },
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.history_rounded,
                                size: 24,
                                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // SEARCH BAR: Height 52, radius 16, white, 1.5 border #CBD5E1
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search tools, math (e.g. 25 * 40), or units...',
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 24,
                            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Recently Used Tools (only when not searching and enabled)
            if (!isSearching)
              AnimatedBuilder(
                animation: prefs,
                builder: (context, _) {
                  if (!prefs.showRecents) return const SliverToBoxAdapter(child: SizedBox.shrink());

                  final recentTools = prefs.recentToolIds
                      .map((id) => ToolRegistry.findById(id))
                      .whereType<ToolItem>()
                      .toList();

                  if (recentTools.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.history_rounded, size: 15, color: AppColors.primaryOrange),
                              const SizedBox(width: 6),
                              Text(
                                'RECENT TOOLS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => prefs.clearRecents(),
                                child: Text(
                                  'Clear',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: recentTools.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final tool = recentTools[i];
                                return Material(
                                  color: isDark ? AppColors.darkSurface : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => _openTool(context, tool),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: tool.color.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(tool.icon, size: 16, color: tool.color),
                                          const SizedBox(width: 6),
                                          Text(
                                            tool.title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // FAVORITES
            if (!isSearching)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 18, color: Color(0xFFEA580C)),
                          const SizedBox(width: 6),
                          Text(
                            'FAVORITES',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 14 * 0.08,
                              color: isDark ? const Color(0xFFFB923C) : const Color(0xFF9A3412),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          clipBehavior: Clip.none,
                          children: [
                            _buildFavoriteChip(
                              title: 'Slate',
                              toolId: 'slate',
                              circleColor: const Color(0xFF111827),
                              icon: Icons.edit_outlined,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFavoriteChip(
                              title: 'Age',
                              toolId: 'age_calc',
                              circleColor: const Color(0xFF7C3AED),
                              icon: Icons.cake_outlined,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFavoriteChip(
                              title: 'GST Calculator',
                              toolId: 'gst_calc',
                              circleColor: const Color(0xFF16A34A),
                              icon: Icons.receipt_long_outlined,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFavoriteChip(
                              title: 'Discount Calculator',
                              toolId: 'discount_calc',
                              circleColor: const Color(0xFFE11D48),
                              icon: Icons.local_offer_outlined,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 8),
                            _buildFavoriteChip(
                              title: 'Unit Converter',
                              toolId: 'unit_converter',
                              circleColor: const Color(0xFF0891B2),
                              icon: Icons.swap_horiz_rounded,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Section header
            if (!isSearching)
              SliverToBoxAdapter(
                child: AnimatedBuilder(
                  animation: prefs,
                  builder: (context, _) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEA580C),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isEditMode ? 'CUSTOMIZE TOOLBOX' : 'CATEGORIES',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          if (_isEditMode) ...[
                            TextButton.icon(
                              onPressed: () {
                                prefs.resetCategoryOrder();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Categories reset to default order'),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 14),
                              label: const Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 6),
                            FilledButton.icon(
                              onPressed: () {
                                PreferencesService().triggerHaptic();
                                setState(() => _isEditMode = false);
                              },
                              icon: const Icon(Icons.check_rounded, size: 14),
                              label: const Text('Done', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFEA580C),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ] else ...[
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                PreferencesService().triggerHaptic();
                                setState(() => _isEditMode = true);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.tune_rounded, size: 13, color: Color(0xFFEA580C)),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Edit',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // "49 tools" pill: bg #FFEDD5, text #9A3412
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${ToolRegistry.allTools.length} tools',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFFFEDD5) : const Color(0xFF9A3412),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Helper banner in Edit Mode
            if (_isEditMode && !isSearching)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryOrange.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.touch_app_rounded, color: AppColors.primaryOrange, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Long-press & drag to reorder categories (e.g. move Kitchen to top). Tap ⬆ to move directly to top.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Content: Search Results or 12 Section Grid / Reorderable List
            if (isSearching) ...[
              // Quick Calculation Shortcut (e.g. 15% of 250, 45 * 12, 5 km to m)
              Builder(
                builder: (context) {
                  final shortcut = SearchCalculatorService.evaluate(_searchQuery);
                  if (shortcut == null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _buildCalculationShortcutCard(context, shortcut, isDark, prefs),
                    ),
                  );
                },
              ),

              if (searchResults.isEmpty)
                Builder(
                  builder: (context) {
                    final shortcut = SearchCalculatorService.evaluate(_searchQuery);
                    if (shortcut != null) {
                      return const SliverToBoxAdapter(child: SizedBox(height: 30));
                    }
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 54, color: AppColors.darkTextMuted.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'No tools found for "$_searchQuery"',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tool = searchResults[index];
                        return _buildSearchResultTile(context, tool, isDark, prefs);
                      },
                      childCount: searchResults.length,
                    ),
                  ),
                ),
            ] else ...[
              AnimatedBuilder(
                animation: prefs,
                builder: (context, _) {
                  final categories = prefs.categoryOrder.isEmpty
                      ? PreferencesService.defaultCategories
                      : prefs.categoryOrder;

                  if (_isEditMode) {
                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverReorderableList(
                        itemCount: categories.length,
                        onReorder: (oldIndex, newIndex) {
                          prefs.reorderCategory(oldIndex, newIndex);
                        },
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            elevation: 8,
                            shadowColor: Colors.black45,
                            borderRadius: BorderRadius.circular(16),
                            child: child,
                          );
                        },
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey('reorder_cat_${category.name}'),
                            index: index,
                            child: _buildReorderableCategoryTile(
                              context,
                              category,
                              index,
                              isDark,
                              prefs,
                            ),
                          );
                        },
                      ),
                    );
                  }

                  // Normal Mode: 2 columns, customized order
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.05,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == 0) {
                            return _buildSlateCard(context, isDark);
                          }
                          final category = categories[index - 1];
                          return _buildSectionCard(context, category, isDark, prefs);
                        },
                        childCount: categories.length + 1,
                      ),
                    ),
                  );
                },
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildSlateCard(BuildContext context, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          PreferencesService().triggerHaptic();
          PreferencesService().addRecent('slate');
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SlateScreen()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: 60x60 tile on left, orange "New" badge on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF111827).withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(17),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.25),
                                Colors.white.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                        const Center(
                          child: Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Orange (#EA580C) "New" badge with white text instead of a count
                  Container(
                    constraints: const BoxConstraints(minHeight: 26, minWidth: 26),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'New',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Title "Slate" (17sp bold)
              Text(
                'Slate',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Description "Draw, write & sketch on a full-screen canvas" (13sp, #475569, up to 2 lines)
              Text(
                'Draw, write & sketch on a full-screen canvas',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteChip({
    required String title,
    required String toolId,
    required Color circleColor,
    required IconData icon,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (toolId == 'slate') {
            PreferencesService().triggerHaptic();
            PreferencesService().addRecent('slate');
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SlateScreen()),
            );
            return;
          }
          final tool = ToolRegistry.findById(toolId);
          if (tool != null) {
            _openTool(context, tool);
          }
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 44,
          padding: const EdgeInsets.only(left: 5, right: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    ToolCategory category,
    bool isDark,
    PreferencesService prefs,
  ) {
    final tools = ToolRegistry.getByCategory(category);
    final count = tools.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openSection(context, category),
        onLongPress: () {
          PreferencesService().triggerHaptic();
          setState(() => _isEditMode = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Customizing Toolbox: Drag "${category.label}" to the top or custom order'),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Move to Top',
                textColor: const Color(0xFFEA580C),
                onPressed: () {
                  prefs.moveCategoryToTop(category);
                },
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: icon tile on the left, count badge on the right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 60x60, radius 17, SOLID saturated colour with subtle top-left light-to-transparent gradient overlay (white 25% -> 0%)
                  // White icon 40dp inside 60dp tile (tight padding), stroke 2.1
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: category.color,
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: [
                        BoxShadow(
                          color: category.color.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(17),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.25),
                                Colors.white.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                        Center(
                          child: Icon(
                            category.icon,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Count badge: min 26dp tall, pill, bg #0F172A, white bold 13sp number
                  Container(
                    constraints: const BoxConstraints(minHeight: 26, minWidth: 26),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$count',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Below: title 17sp bold #0F172A
              Text(
                category.label,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Description: 13sp #475569, up to 2 lines (do NOT truncate with ellipsis on one line)
              Text(
                category.description,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReorderableCategoryTile(
    BuildContext context,
    ToolCategory category,
    int index,
    bool isDark,
    PreferencesService prefs,
  ) {
    final tools = ToolRegistry.getByCategory(category);
    final count = tools.length;

    return Container(
      key: ValueKey('reorder_tile_${category.name}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: index == 0
              ? AppColors.primaryOrange.withOpacity(0.6)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: index == 0 ? 1.5 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: category.color.withOpacity(isDark ? 0.08 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Position Index Pill
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: index == 0
                      ? AppColors.primaryOrange.withOpacity(0.18)
                      : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: index == 0 ? AppColors.primaryOrange : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Category Icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      category.color.withOpacity(0.22),
                      category.color.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.icon, color: category.color, size: 22),
              ),
              const SizedBox(width: 12),

              // Title and tool count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            category.label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        if (index == 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '#1 TOP',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count tools • ${category.description}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),

              // Quick "Move to Top" button
              if (index > 0)
                Tooltip(
                  message: 'Move ${category.label} to top',
                  child: Material(
                    color: AppColors.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => prefs.moveCategoryToTop(category),
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 18,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(width: 6),

              // Reorder Drag Handle (instant touch drag)
              ReorderableDragStartListener(
                index: index,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculationShortcutCard(
    BuildContext context,
    QuickCalcResult shortcut,
    bool isDark,
    PreferencesService prefs,
  ) {
    final isConversion = shortcut.isConversion;
    final icon = isConversion ? Icons.swap_horiz_rounded : Icons.calculate_rounded;
    final accentColor = isConversion ? AppColors.catConverter : AppColors.primaryOrange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: 8),
              Text(
                isConversion ? 'QUICK UNIT CONVERSION' : 'QUICK CALCULATION SHORTCUT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: accentColor,
                ),
              ),
              const Spacer(),
              Text(
                shortcut.expression,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortcut.result,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    if (shortcut.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        shortcut.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Copy result & save to history',
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: shortcut.result));
                  prefs.addCalculationRecord(
                    toolTitle: 'Search Calculator',
                    expression: shortcut.expression,
                    result: shortcut.result,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied "${shortcut.result}" & saved to history'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultTile(
    BuildContext context,
    ToolItem tool,
    bool isDark,
    PreferencesService prefs,
  ) {
    final isFav = prefs.isFavorite(tool.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        onTap: () => _openTool(context, tool),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tool.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(tool.icon, color: tool.color, size: 20),
        ),
        title: Text(
          tool.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          tool.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tool.category.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tool.category.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: tool.category.color,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                isFav ? Icons.star_rounded : Icons.star_border_rounded,
                color: isFav ? AppColors.warning : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                size: 20,
              ),
              tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
              onPressed: () => prefs.toggleFavorite(tool.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceDedicatedView(BuildContext context, bool isDark) {
    final financeTools = ToolRegistry.getByCategory(ToolCategory.finance);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Finance Suite Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withOpacity(0.15),
                    const Color(0xFF059669).withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Color(0xFF10B981),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Finance Suite',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'GST, Loan EMI, Discounts, Currency & more',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section label
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'ALL FINANCE TOOLS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),

            // Tool cards
            ...financeTools.map((tool) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openTool(context, tool),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: tool.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(tool.icon, color: tool.color, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tool.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tool.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
