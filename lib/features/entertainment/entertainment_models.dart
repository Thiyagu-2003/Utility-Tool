/// Supported Entertainment Categories
enum EntertainmentCategory {
  anime,
  drama,
  movies,
  tvSeries,
}

extension EntertainmentCategoryExtension on EntertainmentCategory {
  String get label {
    switch (this) {
      case EntertainmentCategory.anime:
        return 'Anime';
      case EntertainmentCategory.drama:
        return 'Drama';
      case EntertainmentCategory.movies:
        return 'Movies';
      case EntertainmentCategory.tvSeries:
        return 'TV Series';
    }
  }

  String get id {
    switch (this) {
      case EntertainmentCategory.anime:
        return 'anime';
      case EntertainmentCategory.drama:
        return 'drama';
      case EntertainmentCategory.movies:
        return 'movies';
      case EntertainmentCategory.tvSeries:
        return 'tv_series';
    }
  }

  static EntertainmentCategory fromString(String? val) {
    switch (val) {
      case 'anime':
        return EntertainmentCategory.anime;
      case 'drama':
        return EntertainmentCategory.drama;
      case 'movies':
      case 'movie':
        return EntertainmentCategory.movies;
      case 'tv_series':
      case 'tvSeries':
      case 'tv':
        return EntertainmentCategory.tvSeries;
      default:
        return EntertainmentCategory.anime;
    }
  }
}

/// Watching Status for entries
enum WatchingStatus {
  planToWatch,
  watching,
  completed,
  onHold,
  dropped,
}

extension WatchingStatusExtension on WatchingStatus {
  String get label {
    switch (this) {
      case WatchingStatus.planToWatch:
        return 'Plan to Watch';
      case WatchingStatus.watching:
        return 'Currently Watching';
      case WatchingStatus.completed:
        return 'Completed';
      case WatchingStatus.onHold:
        return 'On Hold';
      case WatchingStatus.dropped:
        return 'Dropped';
    }
  }

  String get id {
    switch (this) {
      case WatchingStatus.planToWatch:
        return 'plan_to_watch';
      case WatchingStatus.watching:
        return 'watching';
      case WatchingStatus.completed:
        return 'completed';
      case WatchingStatus.onHold:
        return 'on_hold';
      case WatchingStatus.dropped:
        return 'dropped';
    }
  }

  static WatchingStatus fromString(String? val) {
    switch (val) {
      case 'watching':
        return WatchingStatus.watching;
      case 'completed':
        return WatchingStatus.completed;
      case 'on_hold':
      case 'onHold':
        return WatchingStatus.onHold;
      case 'dropped':
        return WatchingStatus.dropped;
      case 'plan_to_watch':
      case 'planToWatch':
      default:
        return WatchingStatus.planToWatch;
    }
  }
}

/// Note Type for structured personal notes
enum NoteType {
  general,
  character,
  scene,
  quote,
  review,
}

extension NoteTypeExtension on NoteType {
  String get label {
    switch (this) {
      case NoteType.general:
        return 'Note';
      case NoteType.character:
        return 'Favourite Character';
      case NoteType.scene:
        return 'Memorable Scene';
      case NoteType.quote:
        return 'Quote';
      case NoteType.review:
        return 'Personal Review';
    }
  }

  static NoteType fromString(String? val) {
    switch (val) {
      case 'character':
        return NoteType.character;
      case 'scene':
        return NoteType.scene;
      case 'quote':
        return NoteType.quote;
      case 'review':
        return NoteType.review;
      case 'general':
      default:
        return NoteType.general;
    }
  }
}

/// Individual personal note or highlight for an entertainment title
class EntertainmentNote {
  final String id;
  final String title;
  final String content;
  final NoteType type;
  final DateTime createdAt;
  final DateTime updatedAt;

  EntertainmentNote({
    required this.id,
    required this.title,
    required this.content,
    this.type = NoteType.general,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory EntertainmentNote.fromJson(Map<String, dynamic> json) =>
      EntertainmentNote(
        id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        type: NoteTypeExtension.fromString(json['type'] as String?),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  EntertainmentNote copyWith({
    String? title,
    String? content,
    NoteType? type,
    DateTime? updatedAt,
  }) =>
      EntertainmentNote(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        type: type ?? this.type,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );
}

/// Main entertainment title entity
class EntertainmentItem {
  final String id;
  final String title;
  final EntertainmentCategory category;
  final String description;
  final int? releaseYear;
  final String? posterPath;
  final List<String> genres;
  final double personalRating; // 0.0 to 10.0 or 0 to 5
  final bool isFavorite;
  final WatchingStatus status;

  // Episode & Season tracking
  final int totalSeasons;
  final int totalEpisodes;
  final int currentSeason;
  final int currentEpisode;

  // Notes
  final List<EntertainmentNote> notes;

  final DateTime createdAt;
  final DateTime updatedAt;

  EntertainmentItem({
    required this.id,
    required this.title,
    required this.category,
    this.description = '',
    this.releaseYear,
    this.posterPath,
    List<String>? genres,
    this.personalRating = 0.0,
    this.isFavorite = false,
    this.status = WatchingStatus.planToWatch,
    this.totalSeasons = 1,
    this.totalEpisodes = 0,
    this.currentSeason = 1,
    this.currentEpisode = 0,
    List<EntertainmentNote>? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : genres = genres ?? const [],
        notes = notes ?? const [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isMovie => category == EntertainmentCategory.movies;

  double get progressPercentage {
    if (isMovie) {
      return status == WatchingStatus.completed ? 1.0 : 0.0;
    }
    if (totalEpisodes <= 0) {
      return status == WatchingStatus.completed ? 1.0 : 0.0;
    }
    final ratio = currentEpisode / totalEpisodes;
    return ratio.clamp(0.0, 1.0);
  }

  String get progressText {
    if (isMovie) {
      return status == WatchingStatus.completed ? 'Watched' : status.label;
    }
    if (totalEpisodes > 0) {
      if (totalSeasons > 1) {
        return 'S$currentSeason: Ep $currentEpisode / $totalEpisodes';
      }
      return 'Ep $currentEpisode / $totalEpisodes';
    }
    if (currentEpisode > 0) {
      return 'Ep $currentEpisode watched';
    }
    return status.label;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.id,
        'description': description,
        'releaseYear': releaseYear,
        'posterPath': posterPath,
        'genres': genres,
        'personalRating': personalRating,
        'isFavorite': isFavorite,
        'status': status.id,
        'totalSeasons': totalSeasons,
        'totalEpisodes': totalEpisodes,
        'currentSeason': currentSeason,
        'currentEpisode': currentEpisode,
        'notes': notes.map((n) => n.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory EntertainmentItem.fromJson(Map<String, dynamic> json) =>
      EntertainmentItem(
        id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title'] as String? ?? 'Untitled',
        category: EntertainmentCategoryExtension.fromString(json['category'] as String?),
        description: json['description'] as String? ?? '',
        releaseYear: json['releaseYear'] as int?,
        posterPath: json['posterPath'] as String?,
        genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        personalRating: (json['personalRating'] as num?)?.toDouble() ?? 0.0,
        isFavorite: json['isFavorite'] as bool? ?? false,
        status: WatchingStatusExtension.fromString(json['status'] as String?),
        totalSeasons: json['totalSeasons'] as int? ?? 1,
        totalEpisodes: json['totalEpisodes'] as int? ?? 0,
        currentSeason: json['currentSeason'] as int? ?? 1,
        currentEpisode: json['currentEpisode'] as int? ?? 0,
        notes: (json['notes'] as List<dynamic>?)
                ?.map((e) => EntertainmentNote.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  EntertainmentItem copyWith({
    String? title,
    EntertainmentCategory? category,
    String? description,
    int? releaseYear,
    String? posterPath,
    List<String>? genres,
    double? personalRating,
    bool? isFavorite,
    WatchingStatus? status,
    int? totalSeasons,
    int? totalEpisodes,
    int? currentSeason,
    int? currentEpisode,
    List<EntertainmentNote>? notes,
    DateTime? updatedAt,
  }) =>
      EntertainmentItem(
        id: id,
        title: title ?? this.title,
        category: category ?? this.category,
        description: description ?? this.description,
        releaseYear: releaseYear ?? this.releaseYear,
        posterPath: posterPath ?? this.posterPath,
        genres: genres ?? this.genres,
        personalRating: personalRating ?? this.personalRating,
        isFavorite: isFavorite ?? this.isFavorite,
        status: status ?? this.status,
        totalSeasons: totalSeasons ?? this.totalSeasons,
        totalEpisodes: totalEpisodes ?? this.totalEpisodes,
        currentSeason: currentSeason ?? this.currentSeason,
        currentEpisode: currentEpisode ?? this.currentEpisode,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );
}
