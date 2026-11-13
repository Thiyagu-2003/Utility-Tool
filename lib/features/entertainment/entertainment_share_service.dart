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
