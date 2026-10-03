import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/registry/tool_registry.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/toolbox_pro_logo.dart';

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
  late ToolCategory _selectedCategory;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.isFinanceFocused
        ? ToolCategory.finance
        : (widget.initialCategory ?? ToolCategory.all);
  }

  void _openTool(BuildContext context, ToolItem tool) {
    PreferencesService().triggerHaptic();
    PreferencesService().addRecent(tool.id);
    Navigator.of(context).push(
      MaterialPageRoute(builder: tool.builder),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final prefs = PreferencesService();

    // Filter tools based on category and search query
    List<ToolItem> displayedTools = _searchQuery.isNotEmpty
        ? ToolRegistry.searchTools(_searchQuery)
        : ToolRegistry.getByCategory(_selectedCategory);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Search Bar & Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.isFinanceFocused) ...[
                      const Padding(
                        padding: EdgeInsets.only(bottom: 14.0, top: 4.0),
                        child: ToolBoxProLogo(iconSize: 40),
                      ),
                    ],
                    // Search bar
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.lightCardHover,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search tools (e.g. GST, Age, Unit, JSON)...',
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),

                    if (!widget.isFinanceFocused && _searchQuery.isEmpty) ...[
                      const SizedBox(height: 14),
                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: ToolCategory.values.map((cat) {
                            final isSelected = cat == _selectedCategory;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                showCheckmark: false,
                                avatar: Icon(
                                  cat.icon,
                                  size: 16,
                                  color: isSelected ? Colors.white : cat.color,
                                ),
                                label: Text(cat.label),
                                selected: isSelected,
                                selectedColor: cat.color,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 13,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    PreferencesService().triggerSelectionHaptic();
                                    setState(() => _selectedCategory = cat);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Favorites Row (If on "All" and favorites exist and not searching)
            if (_searchQuery.isEmpty && _selectedCategory == ToolCategory.all) ...[
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
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 18, color: AppColors.primaryOrange),
                              const SizedBox(width: 6),
                              Text(
                                'FAVORITES & PINNED',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: favTools.map((tool) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 10.0),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _openTool(context, tool),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: tool.color.withOpacity(0.35),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: tool.color.withOpacity(0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(tool.icon, size: 18, color: tool.color),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            tool.title,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],

            // Main Tools Grid
            if (displayedTools.isEmpty)
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tool = displayedTools[index];
                      return _buildToolCard(context, tool, isDark);
                    },
                    childCount: displayedTools.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, ToolItem tool, bool isDark) {
    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openTool(context, tool),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tool.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(tool.icon, color: tool.color, size: 24),
                  ),
                  AnimatedBuilder(
                    animation: PreferencesService(),
                    builder: (context, _) {
                      final isFav = PreferencesService().isFavorite(tool.id);
                      return IconButton(
                        icon: Icon(
                          isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 20,
                          color: isFav
                              ? AppColors.primaryOrange
                              : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ),
                        onPressed: () => PreferencesService().toggleFavorite(tool.id),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      );
                    },
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tool.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tool.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      height: 1.25,
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
}
