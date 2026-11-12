import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/tool_scaffold.dart';
import 'entertainment_models.dart';
import 'entertainment_service.dart';

enum EntertainmentViewTab {
  dashboard('Dashboard', Icons.dashboard_rounded),
  all('All Titles', Icons.movie_filter_rounded),
  anime('Anime', Icons.animation_rounded),
  drama('Drama', Icons.theater_comedy_rounded),
  movies('Movies', Icons.movie_creation_rounded),
  tvSeries('TV Series', Icons.tv_rounded);

  final String label;
  final IconData icon;
  const EntertainmentViewTab(this.label, this.icon);

  EntertainmentCategory? get category {
    switch (this) {
      case EntertainmentViewTab.anime:
        return EntertainmentCategory.anime;
      case EntertainmentViewTab.drama:
        return EntertainmentCategory.drama;
      case EntertainmentViewTab.movies:
        return EntertainmentCategory.movies;
      case EntertainmentViewTab.tvSeries:
        return EntertainmentCategory.tvSeries;
      default:
        return null;
    }
  }
}

class EntertainmentTrackerScreen extends StatefulWidget {
  final EntertainmentCategory? initialCategory;

  const EntertainmentTrackerScreen({
    super.key,
    this.initialCategory,
  });

  @override
  State<EntertainmentTrackerScreen> createState() => _EntertainmentTrackerScreenState();
}

class _EntertainmentTrackerScreenState extends State<EntertainmentTrackerScreen> {
  final EntertainmentService _service = EntertainmentService();
  late EntertainmentViewTab _currentTab;

  // Search & Filters
  final TextEditingController _searchCtrl = TextEditingController();
  WatchingStatus? _selectedStatusFilter;
  bool _favoritesOnly = false;
  String _sortBy = 'updated'; // 'updated', 'title', 'rating', 'release'

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      switch (widget.initialCategory!) {
        case EntertainmentCategory.anime:
          _currentTab = EntertainmentViewTab.anime;
          break;
        case EntertainmentCategory.drama:
          _currentTab = EntertainmentViewTab.drama;
          break;
        case EntertainmentCategory.movies:
          _currentTab = EntertainmentViewTab.movies;
          break;
        case EntertainmentCategory.tvSeries:
          _currentTab = EntertainmentViewTab.tvSeries;
          break;
      }
    } else {
      _currentTab = EntertainmentViewTab.dashboard;
    }
    _service.init();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tabs = EntertainmentViewTab.values.map((tab) {
      return FeatureTabItem<EntertainmentViewTab>(
        value: tab,
        label: tab.label,
        icon: tab.icon,
      );
    }).toList();

    return ToolScaffold(
      title: 'Entertainment Notes & Tracker',
      subtitle: 'Anime, Drama, Movies & TV Series',
      category: ToolCategory.entertainment,
      toolId: 'entertainment_tracker',
      isScrollable: false,
      actions: [
        IconButton(
          tooltip: 'Add Title',
          icon: const Icon(Icons.add_rounded),
          onPressed: () => _openAddEditItemDialog(),
        ),
      ],
      body: AnimatedBuilder(
        animation: _service,
        builder: (context, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: FeatureTabSelector<EntertainmentViewTab>(
                  tabs: tabs,
                  activeTab: _currentTab,
                  accentColor: AppColors.catEveryday,
                  onTabSelected: (tab) {
                    PreferencesService().triggerHaptic();
                    setState(() {
                      _currentTab = tab;
                    });
                  },
                ),
              ),
              Expanded(
                child: _currentTab == EntertainmentViewTab.dashboard
                    ? _buildDashboardView(isDark)
                    : _buildLibraryView(isDark),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // DASHBOARD VIEW
  // ==========================================

  Widget _buildDashboardView(bool isDark) {
    final stats = _service.getStats();
    final watchingItems = _service.getCurrentlyWatching();
    final recentlyUpdated = _service.getRecentlyUpdated(limit: 6);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: [
        // Top stats container
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Watching Statistics',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile('Total Titles', '${stats.totalTitles}', Icons.video_library_rounded, Colors.indigo),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatTile('Watching', '${stats.watchingCount}', Icons.play_circle_fill_rounded, Colors.teal),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile('Completed', '${stats.completedCount}', Icons.check_circle_rounded, Colors.green),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatTile('Planned', '${stats.planToWatchCount}', Icons.bookmark_add_rounded, Colors.amber),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile('Episodes Watched', '${stats.totalEpisodesWatched}', Icons.playlist_add_check_rounded, Colors.deepPurple),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatTile('Notes & Highlights', '${stats.totalNotes}', Icons.edit_note_rounded, Colors.orange),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Currently Watching Section
        _buildSectionHeader(
          title: 'Currently Watching',
          count: watchingItems.length,
          icon: Icons.play_arrow_rounded,
          onViewAll: () {
            setState(() {
              _currentTab = EntertainmentViewTab.all;
              _selectedStatusFilter = WatchingStatus.watching;
            });
          },
        ),
        const SizedBox(height: 8),
        if (watchingItems.isEmpty)
          _buildEmptyCard('No titles currently in progress. Add or update status to start tracking!')
        else
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: watchingItems.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = watchingItems[index];
                return SizedBox(
                  width: 160,
                  child: _buildPosterCard(item, isDark, compact: true),
                );
              },
            ),
          ),

        const SizedBox(height: 20),

        // Recently Updated Section
        _buildSectionHeader(
          title: 'Recently Updated',
          count: recentlyUpdated.length,
          icon: Icons.history_rounded,
        ),
        const SizedBox(height: 8),
        if (recentlyUpdated.isEmpty)
          _buildEmptyCard('No titles added yet.')
        else
          ...recentlyUpdated.map((item) => _buildListItemCard(item, isDark)),

        const SizedBox(height: 20),

        // Quick Category Breakdown
        _buildSectionHeader(
          title: 'Explore By Category',
          icon: Icons.category_rounded,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildCategoryActionCard(
                'Anime',
                Icons.animation_rounded,
                _service.filterItems(category: EntertainmentCategory.anime).length,
                Colors.pink,
                () => setState(() => _currentTab = EntertainmentViewTab.anime),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCategoryActionCard(
                'Drama',
                Icons.theater_comedy_rounded,
                _service.filterItems(category: EntertainmentCategory.drama).length,
                Colors.purple,
                () => setState(() => _currentTab = EntertainmentViewTab.drama),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildCategoryActionCard(
                'Movies',
                Icons.movie_creation_rounded,
                _service.filterItems(category: EntertainmentCategory.movies).length,
                Colors.blue,
                () => setState(() => _currentTab = EntertainmentViewTab.movies),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCategoryActionCard(
                'TV Series',
                Icons.tv_rounded,
                _service.filterItems(category: EntertainmentCategory.tvSeries).length,
                Colors.teal,
                () => setState(() => _currentTab = EntertainmentViewTab.tvSeries),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryActionCard(
    String title,
    IconData icon,
    int count,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '$count titles',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // LIBRARY VIEW (CATEGORY & ALL)
  // ==========================================

  Widget _buildLibraryView(bool isDark) {
    final cat = _currentTab.category;
    final filtered = _service.filterItems(
      category: cat,
      status: _selectedStatusFilter,
      favoritesOnly: _favoritesOnly,
      searchQuery: _searchCtrl.text,
      sortBy: _sortBy,
    );

    return Column(
      children: [
        // Search & Filter controls
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search title, genre, notes...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      selected: _favoritesOnly,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _favoritesOnly ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 16,
                            color: _favoritesOnly ? Colors.red : null,
                          ),
                          const SizedBox(width: 4),
                          const Text('Favourites'),
                        ],
                      ),
                      onSelected: (val) => setState(() => _favoritesOnly = val),
                    ),
                    const SizedBox(width: 6),
                    ...WatchingStatus.values.map((status) {
                      final isSelected = _selectedStatusFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(status.label),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              _selectedStatusFilter = val ? status : null;
                            });
                          },
                        ),
                      );
                    }),
                    IconButton(
                      icon: const Icon(Icons.sort_rounded, size: 20),
                      tooltip: 'Sort by',
                      onPressed: _showSortBottomSheet,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Library Items List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.video_library_outlined, size: 48, color: Theme.of(context).hintColor),
                        const SizedBox(height: 12),
                        Text(
                          'No entertainment entries found',
                          style: TextStyle(fontSize: 16, color: Theme.of(context).hintColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your favourite Anime, Drama, Movies, or TV Series to get started!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildListItemCard(item, isDark);
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // CARDS & UI COMPONENTS
  // ==========================================

  Widget _buildPosterCard(EntertainmentItem item, bool isDark, {bool compact = false}) {
    final catColor = _categoryColor(item.category);

    return InkWell(
      onTap: () => _openItemDetailScreen(item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.isFavorite ? Colors.amber.withValues(alpha: 0.5) : Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster / Placeholder image
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPosterImage(item.posterPath, item.category),
                  // Category badge
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.category.label,
                        style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Rating badge
                  if (item.personalRating > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              item.personalRating.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Progress indicator overlay at bottom of poster
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      value: item.progressPercentage,
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                      valueColor: AlwaysStoppedAnimation<Color>(catColor),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            // Info content
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.progressText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                        ),
                      ),
                      if (!item.isMovie)
                        InkWell(
                          onTap: () => _service.incrementEpisode(item.id),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded, size: 12, color: catColor),
                                Text(
                                  '1 Ep',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: catColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItemCard(EntertainmentItem item, bool isDark) {
    final catColor = _categoryColor(item.category);
    final statusColor = _statusColor(item.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.isFavorite ? Colors.amber.withValues(alpha: 0.4) : Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: () => _openItemDetailScreen(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 70,
                  height: 95,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildPosterImage(item.posterPath, item.category),
                      if (item.isFavorite)
                        const Positioned(
                          top: 4,
                          left: 4,
                          child: Icon(Icons.favorite_rounded, size: 14, color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and category badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.category.label,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: catColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Metadata row: Year, Rating, Status
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (item.releaseYear != null)
                          Text(
                            '${item.releaseYear}',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                          ),
                        if (item.personalRating > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                item.personalRating.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.status.label,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: statusColor),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Episode Progress bar (if not movie)
                    if (!item.isMovie) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: item.progressPercentage,
                                backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(catColor),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.progressText,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).hintColor),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Watched +1 episode',
                            onPressed: () => _service.incrementEpisode(item.id),
                          ),
                        ],
                      ),
                    ],

                    // Genres & Notes count
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.genres.isNotEmpty)
                          Expanded(
                            child: Text(
                              item.genres.join(', '),
                              style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (item.notes.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.speaker_notes_outlined, size: 13, color: Theme.of(context).hintColor),
                              const SizedBox(width: 3),
                              Text(
                                '${item.notes.length}',
                                style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPosterImage(String? path, EntertainmentCategory category) {
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholderPoster(category),
        );
      }
    }
    return _buildPlaceholderPoster(category);
  }

  Widget _buildPlaceholderPoster(EntertainmentCategory category) {
    final catColor = _categoryColor(category);
    IconData icon;
    switch (category) {
      case EntertainmentCategory.anime:
        icon = Icons.animation_rounded;
        break;
      case EntertainmentCategory.drama:
        icon = Icons.theater_comedy_rounded;
        break;
      case EntertainmentCategory.movies:
        icon = Icons.movie_creation_rounded;
        break;
      case EntertainmentCategory.tvSeries:
        icon = Icons.tv_rounded;
        break;
    }

    return Container(
      color: catColor.withValues(alpha: 0.15),
      child: Center(
        child: Icon(icon, size: 36, color: catColor.withValues(alpha: 0.6)),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    int? count,
    required IconData icon,
    VoidCallback? onViewAll,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            child: const Text('View All', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
        ),
      ),
    );
  }

  Color _categoryColor(EntertainmentCategory category) {
    switch (category) {
      case EntertainmentCategory.anime:
        return Colors.pink;
      case EntertainmentCategory.drama:
        return Colors.purple;
      case EntertainmentCategory.movies:
        return Colors.blue;
      case EntertainmentCategory.tvSeries:
        return Colors.teal;
    }
  }

  Color _statusColor(WatchingStatus status) {
    switch (status) {
      case WatchingStatus.watching:
        return Colors.teal;
      case WatchingStatus.completed:
        return Colors.green;
      case WatchingStatus.planToWatch:
        return Colors.amber.shade700;
      case WatchingStatus.onHold:
        return Colors.orange;
      case WatchingStatus.dropped:
        return Colors.red;
    }
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sort Titles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: const Text('Recently Updated'),
                trailing: _sortBy == 'updated' ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  setState(() => _sortBy = 'updated');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha_rounded),
                title: const Text('Title (A-Z)'),
                trailing: _sortBy == 'title' ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  setState(() => _sortBy = 'title');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_rounded),
                title: const Text('Personal Rating (Highest First)'),
                trailing: _sortBy == 'rating' ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  setState(() => _sortBy = 'rating');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_rounded),
                title: const Text('Release Year'),
                trailing: _sortBy == 'release' ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  setState(() => _sortBy = 'release');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // ENTRY DETAIL & NOTES SCREEN
  // ==========================================

  void _openItemDetailScreen(EntertainmentItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _EntertainmentDetailScreen(
          itemId: item.id,
          service: _service,
          onEdit: (entry) => _openAddEditItemDialog(existingItem: entry),
        ),
      ),
    );
  }

  // ==========================================
  // ADD / EDIT TITLE DIALOG
  // ==========================================

  void _openAddEditItemDialog({
    EntertainmentItem? existingItem,
    EntertainmentCategory? preselectedCategory,
  }) {
    final titleCtrl = TextEditingController(text: existingItem?.title ?? '');
    final descCtrl = TextEditingController(text: existingItem?.description ?? '');
    final yearCtrl = TextEditingController(
        text: existingItem?.releaseYear != null ? '${existingItem!.releaseYear}' : '');
    final genresCtrl = TextEditingController(text: existingItem?.genres.join(', ') ?? '');
    final seasonsCtrl = TextEditingController(text: '${existingItem?.totalSeasons ?? 1}');
    final episodesCtrl = TextEditingController(text: '${existingItem?.totalEpisodes ?? 0}');
    final curEpisodeCtrl = TextEditingController(text: '${existingItem?.currentEpisode ?? 0}');

    EntertainmentCategory category =
        existingItem?.category ?? preselectedCategory ?? EntertainmentCategory.anime;
    WatchingStatus status = existingItem?.status ?? WatchingStatus.planToWatch;
    double rating = existingItem?.personalRating ?? 0.0;
    bool isFavorite = existingItem?.isFavorite ?? false;
    String? posterPath = existingItem?.posterPath;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isMovie = category == EntertainmentCategory.movies;

            return AlertDialog(
              title: Text(existingItem == null ? 'Add Title' : 'Edit Title'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster selection row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 60,
                              height: 80,
                              child: _buildPosterImage(posterPath, category),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    try {
                                      final picked = await FilePicker.pickFile(type: FileType.image);
                                      if (picked != null && picked.path != null) {
                                        setDialogState(() {
                                          posterPath = picked.path;
                                        });
                                      }
                                    } catch (e) {
                                      debugPrint('Image pick error: $e');
                                    }
                                  },
                                  icon: const Icon(Icons.image_rounded, size: 16),
                                  label: Text(posterPath == null ? 'Select Poster' : 'Change Poster'),
                                ),
                                if (posterPath != null)
                                  TextButton(
                                    onPressed: () => setDialogState(() => posterPath = null),
                                    child: const Text('Remove Poster', style: TextStyle(fontSize: 11, color: Colors.red)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Category Dropdown
                      DropdownButtonFormField<EntertainmentCategory>(
                        initialValue: category,
                        decoration: const InputDecoration(labelText: 'Category', isDense: true),
                        items: EntertainmentCategory.values.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Text(cat.label),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => category = val);
                        },
                      ),
                      const SizedBox(height: 10),

                      // Title field
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Title *',
                          hintText: 'e.g. Frieren, Interstellar...',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Status Dropdown
                      DropdownButtonFormField<WatchingStatus>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Watching Status', isDense: true),
                        items: WatchingStatus.values.map((st) {
                          return DropdownMenuItem(
                            value: st,
                            child: Text(st.label),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => status = val);
                        },
                      ),
                      const SizedBox(height: 10),

                      // Episode and Season Tracking (if not movie)
                      if (!isMovie) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: episodesCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Total Episodes',
                                  hintText: 'e.g. 12, 24',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: curEpisodeCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Current Ep',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: seasonsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Total Seasons',
                            hintText: 'e.g. 1',
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Rating slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Personal Rating:', style: TextStyle(fontSize: 13)),
                          Text(
                            rating > 0 ? '${rating.toStringAsFixed(1)} / 10' : 'Unrated',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      Slider(
                        value: rating,
                        min: 0,
                        max: 10,
                        divisions: 20,
                        label: rating.toStringAsFixed(1),
                        onChanged: (val) => setDialogState(() => rating = val),
                      ),

                      // Year & Genres
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: yearCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Release Year',
                                hintText: '2024',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: genresCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Genres (comma-separated)',
                                hintText: 'Action, Sci-Fi',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Description
                      TextField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description / Synopsis',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Favorite toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mark as Favourite', style: TextStyle(fontSize: 13)),
                        secondary: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFavorite ? Colors.red : null,
                        ),
                        value: isFavorite,
                        onChanged: (val) => setDialogState(() => isFavorite = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;

                    final genres = genresCtrl.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();

                    final totalEp = int.tryParse(episodesCtrl.text.trim()) ?? 0;
                    final curEp = int.tryParse(curEpisodeCtrl.text.trim()) ?? 0;
                    final totalSeas = int.tryParse(seasonsCtrl.text.trim()) ?? 1;
                    final relYear = int.tryParse(yearCtrl.text.trim());

                    if (existingItem != null) {
                      _service.updateItem(
                        existingItem.copyWith(
                          title: title,
                          category: category,
                          description: descCtrl.text.trim(),
                          releaseYear: relYear,
                          posterPath: posterPath,
                          genres: genres,
                          personalRating: rating,
                          isFavorite: isFavorite,
                          status: status,
                          totalSeasons: totalSeas,
                          totalEpisodes: isMovie ? 1 : totalEp,
                          currentEpisode: isMovie ? (status == WatchingStatus.completed ? 1 : 0) : curEp,
                        ),
                      );
                    } else {
                      _service.addItem(
                        EntertainmentItem(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          title: title,
                          category: category,
                          description: descCtrl.text.trim(),
                          releaseYear: relYear,
                          posterPath: posterPath,
                          genres: genres,
                          personalRating: rating,
                          isFavorite: isFavorite,
                          status: status,
                          totalSeasons: totalSeas,
                          totalEpisodes: isMovie ? 1 : totalEp,
                          currentEpisode: isMovie ? (status == WatchingStatus.completed ? 1 : 0) : curEp,
                        ),
                      );
                    }
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ==========================================
// DETAILS & PERSONAL NOTES SCREEN
// ==========================================

class _EntertainmentDetailScreen extends StatefulWidget {
  final String itemId;
  final EntertainmentService service;
  final Function(EntertainmentItem) onEdit;

  const _EntertainmentDetailScreen({
    required this.itemId,
    required this.service,
    required this.onEdit,
  });

  @override
  State<_EntertainmentDetailScreen> createState() => _EntertainmentDetailScreenState();
}

class _EntertainmentDetailScreenState extends State<_EntertainmentDetailScreen> {
  NoteType? _filterNoteType;

  EntertainmentItem? get _item {
    try {
      return widget.service.items.firstWhere((e) => e.id == widget.itemId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final item = _item;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Entry Not Found')),
            body: const Center(child: Text('This entry no longer exists.')),
          );
        }

        final theme = Theme.of(context);
        final notes = _filterNoteType == null
            ? item.notes
            : item.notes.where((n) => n.type == _filterNoteType).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                icon: Icon(
                  item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: item.isFavorite ? Colors.red : null,
                ),
                tooltip: 'Toggle Favourite',
                onPressed: () => widget.service.toggleFavorite(item.id),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'Edit Title Details',
                onPressed: () => widget.onEdit(item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Delete Title',
                onPressed: () => _confirmDeleteItem(context, item),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            children: [
              // Header Card with Poster & Metadata
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 80,
                          height: 110,
                          child: _buildDetailPoster(item.posterPath, item.category),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Information
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.category.label} • ${item.releaseYear ?? "N/A"}',
                              style: TextStyle(color: theme.hintColor, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            // Rating and Status
                            Row(
                              children: [
                                if (item.personalRating > 0) ...[
                                  const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${item.personalRating.toStringAsFixed(1)} / 10',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    item.status.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (item.genres.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                item.genres.join(', '),
                                style: TextStyle(fontSize: 12, color: theme.hintColor),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Watching Status & Episode Counter Card
              if (!item.isMovie)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Episode Tracking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.progressText,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: item.progressPercentage,
                                      minHeight: 8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Quick buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline_rounded),
                                  onPressed: item.currentEpisode > 0
                                      ? () => widget.service.decrementEpisode(item.id)
                                      : null,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_rounded, color: Colors.blue, size: 28),
                                  onPressed: () => widget.service.incrementEpisode(item.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Description Card
              if (item.description.isNotEmpty) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Synopsis / Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 6),
                        Text(item.description, style: const TextStyle(fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ==========================================
              // PERSONAL NOTES & HIGHLIGHTS SECTION
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Personal Notes & Highlights (${item.notes.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _openAddEditNoteDialog(context, item.id),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Note'),
                  ),
                ],
              ),

              // Note Type filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _filterNoteType == null,
                      onSelected: (_) => setState(() => _filterNoteType = null),
                    ),
                    const SizedBox(width: 6),
                    ...NoteType.values.map((nt) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(nt.label),
                          selected: _filterNoteType == nt,
                          onSelected: (val) {
                            setState(() {
                              _filterNoteType = val ? nt : null;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              if (notes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.notes_rounded, size: 36, color: theme.hintColor),
                        const SizedBox(height: 8),
                        Text(
                          'No notes recorded yet',
                          style: TextStyle(color: theme.hintColor, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Save favourite characters, memorable scenes, memorable quotes, or your personal review!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.hintColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...notes.map((note) => _buildNoteCard(context, item.id, note)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openAddEditNoteDialog(context, item.id),
            icon: const Icon(Icons.add_comment_rounded),
            label: const Text('Add Note'),
          ),
        );
      },
    );
  }

  Widget _buildNoteCard(BuildContext context, String itemId, EntertainmentNote note) {
    final theme = Theme.of(context);
    final typeColor = _noteTypeColor(note.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    note.type.label,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _openAddEditNoteDialog(context, itemId, existingNote: note),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => widget.service.deleteNoteFromItem(itemId, note.id),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              note.content,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 6),
            Text(
              'Updated: ${DateFormat.yMMMd().add_jm().format(note.updatedAt)}',
              style: TextStyle(fontSize: 10, color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }

  Color _noteTypeColor(NoteType type) {
    switch (type) {
      case NoteType.character:
        return Colors.purple;
      case NoteType.scene:
        return Colors.orange;
      case NoteType.quote:
        return Colors.blue;
      case NoteType.review:
        return Colors.teal;
      case NoteType.general:
        return Colors.grey.shade700;
    }
  }

  Widget _buildDetailPoster(String? path, EntertainmentCategory category) {
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return Container(
      color: Colors.grey.shade200,
      child: const Center(child: Icon(Icons.movie_creation_rounded, size: 36, color: Colors.grey)),
    );
  }

  void _confirmDeleteItem(BuildContext context, EntertainmentItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Title'),
        content: Text('Are you sure you want to delete "${item.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              widget.service.deleteItem(item.id);
              Navigator.pop(ctx); // Dialog
              Navigator.pop(context); // Screen
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openAddEditNoteDialog(BuildContext context, String itemId, {EntertainmentNote? existingNote}) {
    final titleCtrl = TextEditingController(text: existingNote?.title ?? '');
    final contentCtrl = TextEditingController(text: existingNote?.content ?? '');
    NoteType type = existingNote?.type ?? NoteType.general;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingNote == null ? 'Add Personal Note' : 'Edit Note'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<NoteType>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Note Type', isDense: true),
                      items: NoteType.values.map((nt) {
                        return DropdownMenuItem(value: nt, child: Text(nt.label));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => type = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title / Subject *',
                        hintText: 'e.g. Character name, Scene title...',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Details / Content *',
                        hintText: 'Write your thoughts, memorable quote or review...',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    final content = contentCtrl.text.trim();
                    if (title.isEmpty || content.isEmpty) return;

                    if (existingNote != null) {
                      widget.service.updateNoteInItem(
                        itemId,
                        existingNote.copyWith(title: title, content: content, type: type),
                      );
                    } else {
                      widget.service.addNoteToItem(
                        itemId,
                        EntertainmentNote(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          title: title,
                          content: content,
                          type: type,
                        ),
                      );
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save Note'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
