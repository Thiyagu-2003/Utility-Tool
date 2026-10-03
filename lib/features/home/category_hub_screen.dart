import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/registry/tool_registry.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/toolbox_pro_logo.dart';
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

  // The 12 official sections
  static const List<ToolCategory> _mainSections = [
    ToolCategory.calculate,
    ToolCategory.convert,
    ToolCategory.dateTime,
    ToolCategory.finance,
    ToolCategory.health,
    ToolCategory.education,
    ToolCategory.homeTravel,
    ToolCategory.filesText,
    ToolCategory.developer,
    ToolCategory.security,
    ToolCategory.kitchen,
    ToolCategory.moreTools,
  ];

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
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header + Search
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Logo
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: ToolBoxProLogo(iconSize: 36),
                    ),
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search tools (GST, BMI, PDF, GPA...)',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pinned Favorites (only when not searching)
            if (!isSearching) ...[
              AnimatedBuilder(
                animation: prefs,
                builder: (context, _) {
                  final favTools = prefs.favoriteToolIds
                      .map((id) => ToolRegistry.findById(id))
                      .whereType<ToolItem>()
                      .toList();

                  if (favTools.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 16, color: AppColors.primaryOrange),
                              const SizedBox(width: 6),
                              Text(
                                'FAVORITES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: favTools.map((tool) {
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
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],

            // Section header
            if (!isSearching)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CATEGORIES',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${ToolRegistry.allTools.length} tools',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryOrange.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Content: Search Results or 12 Section Grid
            if (isSearching) ...[
              if (searchResults.isEmpty)
                SliverFillRemaining(
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
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final tool = searchResults[index];
                        return _buildSearchResultTile(context, tool, isDark);
                      },
                      childCount: searchResults.length,
                    ),
                  ),
                ),
            ] else ...[
              // 12 Category Cards — 2 columns, vertical scroll
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final category = _mainSections[index];
                      return _buildSectionCard(context, category, isDark);
                    },
                    childCount: _mainSections.length,
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, ToolCategory category, bool isDark) {
    final tools = ToolRegistry.getByCategory(category);
    final count = tools.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openSection(context, category),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: category.color.withOpacity(isDark ? 0.06 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top: Icon + Count
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          category.color.withOpacity(0.2),
                          category.color.withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(category.icon, color: category.color, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: category.color,
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom: Title + Subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultTile(BuildContext context, ToolItem tool, bool isDark) {
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
        onTap: () => _openTool(context, tool),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: tool.color.withOpacity(0.12),
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
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tool.category.color.withOpacity(0.12),
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
