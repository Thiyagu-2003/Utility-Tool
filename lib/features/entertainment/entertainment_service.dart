import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'entertainment_models.dart';

class EntertainmentStats {
  final int totalTitles;
  final int watchingCount;
  final int completedCount;
  final int planToWatchCount;
  final int onHoldCount;
  final int droppedCount;
  final int totalEpisodesWatched;
  final int totalNotes;

  const EntertainmentStats({
    this.totalTitles = 0,
    this.watchingCount = 0,
    this.completedCount = 0,
    this.planToWatchCount = 0,
    this.onHoldCount = 0,
    this.droppedCount = 0,
    this.totalEpisodesWatched = 0,
    this.totalNotes = 0,
  });
}

/// Offline-first service for managing entertainment watchlist and notes
class EntertainmentService extends ChangeNotifier {
  static final EntertainmentService _instance = EntertainmentService._internal();
  factory EntertainmentService() => _instance;
  EntertainmentService._internal();

  static const String _storageKey = 'entertainment_tracker_items_v1';

  final List<EntertainmentItem> _items = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;
  List<EntertainmentItem> get items => List.unmodifiable(_items);

  @visibleForTesting
  void clearForTesting() {
    _items.clear();
    _initialized = false;
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _items.clear();
          for (final item in decoded) {
            try {
              if (item is Map<String, dynamic>) {
                _items.add(EntertainmentItem.fromJson(item));
              } else if (item is Map) {
                _items.add(EntertainmentItem.fromJson(Map<String, dynamic>.from(item)));
              }
            } catch (e) {
              debugPrint('Error deserializing EntertainmentItem: $e');
            }
          }
        }
      } else {
        // Seed initial friendly sample if completely empty
        _seedInitialSamples();
      }
    } catch (e) {
      debugPrint('EntertainmentService init error: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  void _seedInitialSamples() {
    _items.addAll([
      EntertainmentItem(
        id: 'seed_anime_1',
        title: 'Frieren: Beyond Journey\'s End',
        category: EntertainmentCategory.anime,
        description: 'An elf mage and her companions journey across the continent to find heaven.',
        releaseYear: 2023,
        genres: ['Fantasy', 'Adventure', 'Drama'],
        personalRating: 9.5,
        isFavorite: true,
        status: WatchingStatus.watching,
        totalSeasons: 1,
        totalEpisodes: 28,
        currentSeason: 1,
        currentEpisode: 18,
        notes: [
          EntertainmentNote(
            id: 'seed_n1',
            title: 'Himmel\'s Philosophy',
            content: 'The journey itself was the treasure, not just defeating the Demon King.',
            type: NoteType.quote,
          ),
          EntertainmentNote(
            id: 'seed_n2',
            title: 'Frieren',
            content: 'Stolid exterior but deeply sentimental and cherishes memories.',
            type: NoteType.character,
          ),
        ],
      ),
      EntertainmentItem(
        id: 'seed_movie_1',
        title: 'Interstellar',
        category: EntertainmentCategory.movies,
        description: 'A team of explorers travel through a wormhole in space in an attempt to ensure humanity\'s survival.',
        releaseYear: 2014,
        genres: ['Sci-Fi', 'Drama', 'Adventure'],
        personalRating: 10.0,
        isFavorite: true,
        status: WatchingStatus.completed,
        totalSeasons: 1,
        totalEpisodes: 1,
        currentSeason: 1,
        currentEpisode: 1,
        notes: [
          EntertainmentNote(
            id: 'seed_n3',
            title: 'Docking Scene',
            content: 'Hans Zimmer No Time for Caution crescendo during the manual docking sequence.',
            type: NoteType.scene,
          ),
        ],
      ),
      EntertainmentItem(
        id: 'seed_tv_1',
        title: 'Severance',
        category: EntertainmentCategory.tvSeries,
        description: 'Mark leads a team of office workers whose memories have been surgically divided between their work and personal lives.',
        releaseYear: 2022,
        genres: ['Thriller', 'Sci-Fi', 'Mystery'],
        personalRating: 9.0,
        status: WatchingStatus.planToWatch,
        totalSeasons: 2,
        totalEpisodes: 19,
        currentSeason: 1,
        currentEpisode: 0,
      ),
      EntertainmentItem(
        id: 'seed_drama_1',
        title: 'Crash Landing on You',
        category: EntertainmentCategory.drama,
        description: 'A paragliding mishap drops a South Korean heiress into North Korea - and into the life of an army officer.',
        releaseYear: 2019,
        genres: ['Romance', 'Comedy', 'Drama'],
        personalRating: 9.2,
        isFavorite: true,
        status: WatchingStatus.completed,
        totalSeasons: 1,
        totalEpisodes: 16,
        currentSeason: 1,
        currentEpisode: 16,
      ),
    ]);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _items.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('EntertainmentService persist error: $e');
    }
  }

  // --- CRUD Actions ---

  Future<void> addItem(EntertainmentItem item) async {
    _items.insert(0, item);
    await _persist();
    notifyListeners();
  }

  Future<void> updateItem(EntertainmentItem item) async {
    final idx = _items.indexWhere((e) => e.id == item.id);
    if (idx != -1) {
      _items[idx] = item.copyWith(updatedAt: DateTime.now());
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteItem(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final item = _items[idx];
      _items[idx] = item.copyWith(isFavorite: !item.isFavorite, updatedAt: DateTime.now());
      await _persist();
      notifyListeners();
    }
  }

  Future<void> updateStatus(String id, WatchingStatus status) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final item = _items[idx];
      int ep = item.currentEpisode;
      if (status == WatchingStatus.completed && item.totalEpisodes > 0) {
        ep = item.totalEpisodes;
      }
      _items[idx] = item.copyWith(status: status, currentEpisode: ep, updatedAt: DateTime.now());
      await _persist();
      notifyListeners();
    }
  }

  Future<void> incrementEpisode(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final item = _items[idx];
      final nextEp = item.currentEpisode + 1;
      WatchingStatus nextStatus = item.status;
      if (item.status == WatchingStatus.planToWatch) {
        nextStatus = WatchingStatus.watching;
      }
      if (item.totalEpisodes > 0 && nextEp >= item.totalEpisodes) {
        nextStatus = WatchingStatus.completed;
      }
      _items[idx] = item.copyWith(
        currentEpisode: item.totalEpisodes > 0 ? nextEp.clamp(0, item.totalEpisodes) : nextEp,
        status: nextStatus,
        updatedAt: DateTime.now(),
      );
      await _persist();
      notifyListeners();
    }
  }

  Future<void> decrementEpisode(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final item = _items[idx];
      if (item.currentEpisode > 0) {
        final nextEp = item.currentEpisode - 1;
        WatchingStatus nextStatus = item.status;
        if (nextStatus == WatchingStatus.completed && nextEp < item.totalEpisodes) {
          nextStatus = WatchingStatus.watching;
        }
        _items[idx] = item.copyWith(
          currentEpisode: nextEp,
          status: nextStatus,
          updatedAt: DateTime.now(),
        );
        await _persist();
        notifyListeners();
      }
    }
  }

  // --- Notes within Entry ---

  Future<void> addNoteToItem(String itemId, EntertainmentNote note) async {
    final idx = _items.indexWhere((e) => e.id == itemId);
    if (idx != -1) {
      final item = _items[idx];
      final newNotes = List<EntertainmentNote>.from(item.notes)..insert(0, note);
      _items[idx] = item.copyWith(notes: newNotes, updatedAt: DateTime.now());
      await _persist();
      notifyListeners();
    }
  }

  Future<void> updateNoteInItem(String itemId, EntertainmentNote updatedNote) async {
    final idx = _items.indexWhere((e) => e.id == itemId);
    if (idx != -1) {
      final item = _items[idx];
      final nIdx = item.notes.indexWhere((n) => n.id == updatedNote.id);
      if (nIdx != -1) {
        final newNotes = List<EntertainmentNote>.from(item.notes);
        newNotes[nIdx] = updatedNote.copyWith(updatedAt: DateTime.now());
        _items[idx] = item.copyWith(notes: newNotes, updatedAt: DateTime.now());
        await _persist();
        notifyListeners();
      }
    }
  }

  Future<void> deleteNoteFromItem(String itemId, String noteId) async {
    final idx = _items.indexWhere((e) => e.id == itemId);
    if (idx != -1) {
      final item = _items[idx];
      final newNotes = item.notes.where((n) => n.id != noteId).toList();
      _items[idx] = item.copyWith(notes: newNotes, updatedAt: DateTime.now());
      await _persist();
      notifyListeners();
    }
  }

  // --- Queries & Statistics ---

  List<EntertainmentItem> filterItems({
    EntertainmentCategory? category,
    WatchingStatus? status,
    bool? favoritesOnly,
    String? searchQuery,
    String sortBy = 'updated', // 'updated', 'title', 'rating', 'release'
    bool ascending = false,
  }) {
    var result = List<EntertainmentItem>.from(_items);

    if (category != null) {
      result = result.where((e) => e.category == category).toList();
    }
    if (status != null) {
      result = result.where((e) => e.status == status).toList();
    }
    if (favoritesOnly == true) {
      result = result.where((e) => e.isFavorite).toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      result = result.where((e) {
        final titleMatch = e.title.toLowerCase().contains(q);
        final descMatch = e.description.toLowerCase().contains(q);
        final genreMatch = e.genres.any((g) => g.toLowerCase().contains(q));
        final notesMatch = e.notes.any((n) =>
            n.title.toLowerCase().contains(q) || n.content.toLowerCase().contains(q));
        return titleMatch || descMatch || genreMatch || notesMatch;
      }).toList();
    }

    result.sort((a, b) {
      int cmp = 0;
      switch (sortBy) {
        case 'title':
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'rating':
          cmp = a.personalRating.compareTo(b.personalRating);
          break;
        case 'release':
          cmp = (a.releaseYear ?? 0).compareTo(b.releaseYear ?? 0);
          break;
        case 'updated':
        default:
          cmp = a.updatedAt.compareTo(b.updatedAt);
          break;
      }
      return ascending ? cmp : -cmp;
    });

    return result;
  }

  EntertainmentStats getStats() {
    int watching = 0;
    int completed = 0;
    int plan = 0;
    int onHold = 0;
    int dropped = 0;
    int totalEp = 0;
    int totalNotes = 0;

    for (final item in _items) {
      switch (item.status) {
        case WatchingStatus.watching:
          watching++;
          break;
        case WatchingStatus.completed:
          completed++;
          break;
        case WatchingStatus.planToWatch:
          plan++;
          break;
        case WatchingStatus.onHold:
          onHold++;
          break;
        case WatchingStatus.dropped:
          dropped++;
          break;
      }
      totalEp += item.currentEpisode;
      totalNotes += item.notes.length;
    }

    return EntertainmentStats(
      totalTitles: _items.length,
      watchingCount: watching,
      completedCount: completed,
      planToWatchCount: plan,
      onHoldCount: onHold,
      droppedCount: dropped,
      totalEpisodesWatched: totalEp,
      totalNotes: totalNotes,
    );
  }

  List<EntertainmentItem> getCurrentlyWatching() {
    return _items.where((e) => e.status == WatchingStatus.watching).toList();
  }

  List<EntertainmentItem> getRecentlyUpdated({int limit = 5}) {
    final sorted = List<EntertainmentItem>.from(_items)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(limit).toList();
  }
}
