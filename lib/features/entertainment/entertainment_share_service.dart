import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/share_utils.dart';
import 'entertainment_models.dart';

/// Helper service to generate shareable summaries, CSVs, JSON exports, and trigger sharing sheets
class EntertainmentShareService {
  /// Generate a human-readable text summary of entertainment items suitable for
  /// instant messaging (WhatsApp, Telegram, Discord, Email, SMS).
  static String generateTextSummary({
    required List<EntertainmentItem> items,
    EntertainmentCategory? category,
    WatchingStatus? status,
    bool favoritesOnly = false,
    bool includeNotes = true,
    String sortBy = 'rating', // 'rating', 'title', 'release', 'updated'
  }) {
    var filtered = List<EntertainmentItem>.from(items);

    if (category != null) {
      filtered = filtered.where((item) => item.category == category).toList();
    }
    if (status != null) {
      filtered = filtered.where((item) => item.status == status).toList();
    }
    if (favoritesOnly) {
      filtered = filtered.where((item) => item.isFavorite).toList();
    }

    filtered.sort((a, b) {
      switch (sortBy) {
        case 'title':
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case 'release':
          return (b.releaseYear ?? 0).compareTo(a.releaseYear ?? 0);
        case 'updated':
          return b.updatedAt.compareTo(a.updatedAt);
        case 'rating':
        default:
          final rCmp = b.personalRating.compareTo(a.personalRating);
          if (rCmp != 0) return rCmp;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });

    final buffer = StringBuffer();

    // Header
    final catLabel = category?.label ?? 'Entertainment';
    final statusLabel = status != null ? status.label : 'Watchlist';
    final favSuffix = favoritesOnly ? ' (Favorites)' : '';
    buffer.writeln('🍿 My $catLabel $statusLabel$favSuffix (${filtered.length} ${filtered.length == 1 ? "title" : "titles"})');
    buffer.writeln('Shared from Utility Tool\n');

    if (filtered.isEmpty) {
      buffer.writeln('No titles found for this filter.');
      return buffer.toString();
    }

    int totalEpisodesWatched = 0;
    double totalRatingSum = 0;
    int ratedCount = 0;

    for (var i = 0; i < filtered.length; i++) {
      final item = filtered[i];
      totalEpisodesWatched += item.currentEpisode;
      if (item.personalRating > 0) {
        totalRatingSum += item.personalRating;
        ratedCount++;
      }

      final yearStr = item.releaseYear != null ? ' (${item.releaseYear})' : '';
      final favStar = item.isFavorite ? ' ❤️' : '';
      buffer.writeln('${i + 1}. ${item.title}$yearStr$favStar');

      // Rating & Progress
      final ratingStr = item.personalRating > 0
          ? '⭐ ${item.personalRating.toStringAsFixed(1)}/10'
          : '⭐ Unrated';
      buffer.writeln('   $ratingStr • ${item.progressText}');

      // Genres
      if (item.genres.isNotEmpty) {
        buffer.writeln('   🏷️ ${item.genres.join(", ")}');
      }

      // Notes (if requested)
      if (includeNotes && item.notes.isNotEmpty) {
        final highlight = item.notes.first;
        final cleanContent = highlight.content.replaceAll('\n', ' ').trim();
        buffer.writeln('   💭 "${highlight.title.isNotEmpty ? "${highlight.title}: " : ""}$cleanContent"');
      }

      buffer.writeln();
    }

    // Summary Footer
    buffer.writeln('────────────────────');
    final avgRating = ratedCount > 0 ? (totalRatingSum / ratedCount).toStringAsFixed(1) : 'N/A';
    buffer.writeln('📊 Summary: ${filtered.length} titles • $totalEpisodesWatched eps watched • Avg rating: $avgRating/10');

    return buffer.toString().trim();
  }

  /// Generate a detailed text summary for sharing a single title recommendation
  static String generateSingleItemText(EntertainmentItem item) {
    final buffer = StringBuffer();
    final yearStr = item.releaseYear != null ? ' (${item.releaseYear})' : '';
    buffer.writeln('🍿 Recommendation: ${item.title}$yearStr');
    buffer.writeln('Category: ${item.category.label} • Status: ${item.status.label}');
    if (item.personalRating > 0) {
      buffer.writeln('⭐ Personal Rating: ${item.personalRating.toStringAsFixed(1)}/10');
    }
    buffer.writeln('📺 Progress: ${item.progressText}');
    if (item.genres.isNotEmpty) {
      buffer.writeln('🏷️ Genres: ${item.genres.join(", ")}');
    }

    if (item.description.trim().isNotEmpty) {
      buffer.writeln('\n📝 Synopsis:');
      buffer.writeln(item.description.trim());
    }

    if (item.notes.isNotEmpty) {
      buffer.writeln('\n💭 Notes & Highlights:');
      for (final note in item.notes) {
        final prefix = note.title.isNotEmpty ? '• ${note.title}: ' : '• ';
        buffer.writeln('$prefix${note.content.trim()}');
      }
    }

    buffer.writeln('\nShared from Utility Tool');
    return buffer.toString().trim();
  }

  /// Generate JSON string representation of titles
  static String generateJsonExport(List<EntertainmentItem> items) {
    final list = items.map((e) => e.toJson()).toList();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'exportType': 'entertainment_watchlist',
      'exportedAt': DateTime.now().toIso8601String(),
      'itemCount': items.length,
      'items': list,
    });
  }

  /// Generate CSV string representation of titles
  static String generateCsvExport(List<EntertainmentItem> items) {
    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('"Title","Category","Status","Rating","Year","CurrentEpisode","TotalEpisodes","Genres","Favorite","Notes"');

    for (final item in items) {
      final safeTitle = _escapeCsv(item.title);
      final cat = _escapeCsv(item.category.label);
      final status = _escapeCsv(item.status.label);
      final rating = item.personalRating.toStringAsFixed(1);
      final year = item.releaseYear?.toString() ?? '';
      final curEp = item.currentEpisode.toString();
      final totEp = item.totalEpisodes.toString();
      final genres = _escapeCsv(item.genres.join('; '));
      final fav = item.isFavorite ? 'Yes' : 'No';
      final notesText = _escapeCsv(item.notes.map((n) => '${n.title}: ${n.content}').join(' | '));

      buffer.writeln('"$safeTitle","$cat","$status","$rating","$year","$curEp","$totEp","$genres","$fav","$notesText"');
    }

    return buffer.toString();
  }

  static String _escapeCsv(String val) => val.replaceAll('"', '""').replaceAll('\n', ' ');

  /// Parses raw content (JSON string, CSV string, or lines of text) into a list of EntertainmentItems.
  static List<EntertainmentItem> parseImportData(String rawContent) {
    final trimmed = rawContent.trim();
    if (trimmed.isEmpty) return const [];

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return _parseJson(trimmed);
    }
    return _parseCsvOrLines(trimmed);
  }

  static List<EntertainmentItem> _parseJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      List<dynamic> itemsList;
      if (decoded is Map && decoded['items'] is List) {
        itemsList = decoded['items'];
      } else if (decoded is List) {
        itemsList = decoded;
      } else {
        return const [];
      }

      final results = <EntertainmentItem>[];
      for (final raw in itemsList) {
        if (raw is Map) {
          try {
            results.add(EntertainmentItem.fromJson(Map<String, dynamic>.from(raw)));
          } catch (_) {}
        }
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  static List<EntertainmentItem> _parseCsvOrLines(String csvStr) {
    final lines = const LineSplitter().convert(csvStr).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return const [];

    final results = <EntertainmentItem>[];
    final header = lines.first.toLowerCase();

    // 1. MyAnimeList export CSV
    if (header.contains('series_title') || header.contains('series_episodes')) {
      final cols = _splitCsvLine(lines.first);
      final titleIdx = cols.indexWhere((c) => c.toLowerCase() == 'series_title');
      final typeIdx = cols.indexWhere((c) => c.toLowerCase() == 'series_type');
      final watchedIdx = cols.indexWhere((c) => c.toLowerCase() == 'my_watched_episodes');
      final totalEpIdx = cols.indexWhere((c) => c.toLowerCase() == 'series_episodes');
      final scoreIdx = cols.indexWhere((c) => c.toLowerCase() == 'my_score');
      final statusIdx = cols.indexWhere((c) => c.toLowerCase() == 'my_status');

      for (var i = 1; i < lines.length; i++) {
        final row = _splitCsvLine(lines[i]);
        if (titleIdx >= 0 && titleIdx < row.length) {
          final title = row[titleIdx].trim();
          if (title.isEmpty) continue;

          final type = typeIdx >= 0 && typeIdx < row.length ? row[typeIdx].toLowerCase() : '';
          final category = type.contains('movie') ? EntertainmentCategory.movies : EntertainmentCategory.anime;

          final watched = watchedIdx >= 0 && watchedIdx < row.length ? int.tryParse(row[watchedIdx]) ?? 0 : 0;
          final total = totalEpIdx >= 0 && totalEpIdx < row.length ? int.tryParse(row[totalEpIdx]) ?? 0 : 0;
          final score = scoreIdx >= 0 && scoreIdx < row.length ? double.tryParse(row[scoreIdx]) ?? 0.0 : 0.0;

          WatchingStatus st = WatchingStatus.completed;
          if (statusIdx >= 0 && statusIdx < row.length) {
            final rawSt = row[statusIdx].toLowerCase();
            if (rawSt == '1' || rawSt.contains('watch')) {
              st = WatchingStatus.watching;
            } else if (rawSt == '2' || rawSt.contains('complete')) {
              st = WatchingStatus.completed;
            } else if (rawSt == '3' || rawSt.contains('hold')) {
              st = WatchingStatus.onHold;
            } else if (rawSt == '4' || rawSt.contains('drop')) {
              st = WatchingStatus.dropped;
            } else if (rawSt == '6' || rawSt.contains('plan')) {
              st = WatchingStatus.planToWatch;
            }
          }

          results.add(
            EntertainmentItem(
              id: 'mal_${DateTime.now().microsecondsSinceEpoch}_$i',
              title: title,
              category: category,
              status: st,
              currentEpisode: watched,
              totalEpisodes: total,
              personalRating: score,
            ),
          );
        }
      }
      return results;
    }

    // 2. Standard App CSV Format
    if (header.contains('title') && header.contains('category')) {
      final cols = _splitCsvLine(lines.first).map((c) => c.toLowerCase()).toList();
      final titleIdx = cols.indexOf('title');
      final catIdx = cols.indexOf('category');
      final statusIdx = cols.indexOf('status');
      final ratingIdx = cols.indexOf('rating');
      final yearIdx = cols.indexOf('year');
      final curEpIdx = cols.indexOf('currentepisode');
      final totEpIdx = cols.indexOf('totalepisodes');
      final genresIdx = cols.indexOf('genres');
      final favIdx = cols.indexOf('favorite');
      final notesIdx = cols.indexOf('notes');

      for (var i = 1; i < lines.length; i++) {
        final row = _splitCsvLine(lines[i]);
        if (titleIdx >= 0 && titleIdx < row.length) {
          final title = row[titleIdx].trim();
          if (title.isEmpty) continue;

          final catStr = catIdx >= 0 && catIdx < row.length ? row[catIdx] : 'anime';
          final stStr = statusIdx >= 0 && statusIdx < row.length ? row[statusIdx] : 'completed';
          final rating = ratingIdx >= 0 && ratingIdx < row.length ? double.tryParse(row[ratingIdx]) ?? 0.0 : 0.0;
          final year = yearIdx >= 0 && yearIdx < row.length ? int.tryParse(row[yearIdx]) : null;
          final curEp = curEpIdx >= 0 && curEpIdx < row.length ? int.tryParse(row[curEpIdx]) ?? 0 : 0;
          final totEp = totEpIdx >= 0 && totEpIdx < row.length ? int.tryParse(row[totEpIdx]) ?? 0 : 0;
          final genres = genresIdx >= 0 && genresIdx < row.length
              ? row[genresIdx].split(';').map((g) => g.trim()).where((g) => g.isNotEmpty).toList()
              : <String>[];
          final isFav = favIdx >= 0 && favIdx < row.length
              ? (row[favIdx].toLowerCase() == 'yes' || row[favIdx].toLowerCase() == 'true')
              : false;

          final notes = <EntertainmentNote>[];
          if (notesIdx >= 0 && notesIdx < row.length && row[notesIdx].trim().isNotEmpty) {
            final rawNotes = row[notesIdx].split('|');
            for (var n = 0; n < rawNotes.length; n++) {
              final noteStr = rawNotes[n].trim();
              if (noteStr.isNotEmpty) {
                final parts = noteStr.split(':');
                final nTitle = parts.length > 1 ? parts[0].trim() : 'Note';
                final nContent = parts.length > 1 ? parts.sublist(1).join(':').trim() : noteStr;
                notes.add(EntertainmentNote(
                  id: 'note_${DateTime.now().microsecondsSinceEpoch}_$n',
                  title: nTitle,
                  content: nContent,
                ));
              }
            }
          }

          results.add(
            EntertainmentItem(
              id: 'imp_${DateTime.now().microsecondsSinceEpoch}_$i',
              title: title,
              category: EntertainmentCategoryExtension.fromString(catStr),
              status: WatchingStatusExtension.fromString(stStr),
              personalRating: rating,
              releaseYear: year,
              currentEpisode: curEp,
              totalEpisodes: totEp,
              genres: genres,
              isFavorite: isFav,
              notes: notes,
            ),
          );
        }
      }
      return results;
    }

    // 3. Fallback: line-by-line simple text import (e.g. numbered list: "1. Attack on Titan")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      // Strip leading numbering e.g. "1. ", "1) ", "- "
      line = line.replaceFirst(RegExp(r'^\s*(\d+[\.\)]|\-|\*)\s*'), '').trim();
      if (line.isEmpty) continue;

      results.add(
        EntertainmentItem(
          id: 'line_${DateTime.now().microsecondsSinceEpoch}_$i',
          title: line,
          category: EntertainmentCategory.anime,
          status: WatchingStatus.completed,
        ),
      );
    }
    return results;
  }

  static List<String> _splitCsvLine(String line) {
    final values = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++; // skip escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        values.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(char);
      }
    }
    values.add(sb.toString().trim());
    return values;
  }

  /// Share text via the native system share sheet (WhatsApp, Telegram, Gmail, etc.)
  static Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
  }

  /// Share file bytes (for CSV or JSON exports)
  static Future<void> shareExportFile({
    required String content,
    required String filename,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    await shareFileBytes(bytes, filename);
  }

  /// Quick copy to clipboard with feedback snackbar
  static Future<void> copyToClipboard(
    BuildContext context,
    String text, {
    String successMessage = 'Watchlist copied to clipboard!',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(successMessage)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
