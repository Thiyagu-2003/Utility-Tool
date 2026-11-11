import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utility_tool/core/models/tool_model.dart';
import 'package:utility_tool/core/registry/tool_registry.dart';
import 'package:utility_tool/features/entertainment/entertainment_models.dart';
import 'package:utility_tool/features/entertainment/entertainment_service.dart';
import 'package:utility_tool/features/entertainment/entertainment_tracker_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EntertainmentService().clearForTesting();
  });

  group('Entertainment Models & Logic Tests', () {
    test('EntertainmentCategory extensions and parsing', () {
      expect(EntertainmentCategory.anime.label, 'Anime');
      expect(EntertainmentCategory.drama.label, 'Drama');
      expect(EntertainmentCategory.movies.label, 'Movies');
      expect(EntertainmentCategory.tvSeries.label, 'TV Series');

      expect(EntertainmentCategoryExtension.fromString('anime'), EntertainmentCategory.anime);
      expect(EntertainmentCategoryExtension.fromString('drama'), EntertainmentCategory.drama);
      expect(EntertainmentCategoryExtension.fromString('movies'), EntertainmentCategory.movies);
      expect(EntertainmentCategoryExtension.fromString('movie'), EntertainmentCategory.movies);
      expect(EntertainmentCategoryExtension.fromString('tv_series'), EntertainmentCategory.tvSeries);
    });

    test('WatchingStatus extensions and parsing', () {
      expect(WatchingStatus.planToWatch.label, 'Plan to Watch');
      expect(WatchingStatus.watching.label, 'Currently Watching');
      expect(WatchingStatus.completed.label, 'Completed');

      expect(WatchingStatusExtension.fromString('watching'), WatchingStatus.watching);
      expect(WatchingStatusExtension.fromString('completed'), WatchingStatus.completed);
      expect(WatchingStatusExtension.fromString('plan_to_watch'), WatchingStatus.planToWatch);
    });

    test('NoteType extensions and parsing', () {
      expect(NoteType.character.label, 'Favourite Character');
      expect(NoteType.scene.label, 'Memorable Scene');
      expect(NoteType.quote.label, 'Quote');
      expect(NoteType.review.label, 'Personal Review');
      expect(NoteType.general.label, 'Note');
    });

    test('EntertainmentItem serialization and episode progress calculation', () {
      final item = EntertainmentItem(
        id: 'test_1',
        title: 'Attack on Titan',
        category: EntertainmentCategory.anime,
        description: 'Humanity fighting Titans',
        releaseYear: 2013,
        genres: ['Action', 'Mystery'],
        personalRating: 9.8,
        isFavorite: true,
        status: WatchingStatus.watching,
        totalSeasons: 4,
        totalEpisodes: 87,
        currentSeason: 2,
        currentEpisode: 37,
      );

      final json = item.toJson();
      expect(json['id'], 'test_1');
      expect(json['title'], 'Attack on Titan');
      expect(json['category'], 'anime');
      expect(json['status'], 'watching');

      final deserialized = EntertainmentItem.fromJson(json);
      expect(deserialized.id, item.id);
      expect(deserialized.title, item.title);
      expect(deserialized.genres, ['Action', 'Mystery']);
      expect(deserialized.personalRating, 9.8);
      expect(deserialized.isFavorite, true);

      // Episode progress
      expect(deserialized.progressPercentage, closeTo(37 / 87, 0.001));
      expect(deserialized.progressText, contains('Ep 37 / 87'));
    });

    test('EntertainmentItem movie progress behavior', () {
      final movie = EntertainmentItem(
        id: 'm1',
        title: 'Spirited Away',
        category: EntertainmentCategory.movies,
        status: WatchingStatus.planToWatch,
      );

      expect(movie.isMovie, true);
      expect(movie.progressPercentage, 0.0);
      expect(movie.progressText, 'Plan to Watch');

      final completedMovie = movie.copyWith(status: WatchingStatus.completed);
      expect(completedMovie.progressPercentage, 1.0);
      expect(completedMovie.progressText, 'Watched');
    });

    test('EntertainmentNote serialization and copyWith', () {
      final note = EntertainmentNote(
        id: 'n1',
        title: 'Levi Ackerman',
        content: 'Humanity strongest soldier',
        type: NoteType.character,
      );

      final json = note.toJson();
      expect(json['type'], 'character');

      final deserialized = EntertainmentNote.fromJson(json);
      expect(deserialized.id, 'n1');
      expect(deserialized.title, 'Levi Ackerman');
      expect(deserialized.type, NoteType.character);

      final updated = deserialized.copyWith(title: 'Captain Levi');
      expect(updated.title, 'Captain Levi');
      expect(updated.content, 'Humanity strongest soldier');
    });
  });

  group('EntertainmentService Integration & Storage Tests', () {
    test('Initialization with seeds when empty', () async {
      final service = EntertainmentService();
      await service.init();
      expect(service.isInitialized, true);
      expect(service.items.isNotEmpty, true);
      expect(service.items.any((e) => e.title.contains('Frieren')), true);
    });

    test('CRUD operations on EntertainmentItem', () async {
      final service = EntertainmentService();
      await service.init();

      final newItem = EntertainmentItem(
        id: 'custom_drama_1',
        title: 'Vincenzo',
        category: EntertainmentCategory.drama,
        status: WatchingStatus.planToWatch,
        totalEpisodes: 20,
      );

      await service.addItem(newItem);
      expect(service.items.any((e) => e.id == 'custom_drama_1'), true);

      // Update
      await service.updateItem(newItem.copyWith(status: WatchingStatus.watching, currentEpisode: 5));
      final updated = service.items.firstWhere((e) => e.id == 'custom_drama_1');
      expect(updated.status, WatchingStatus.watching);
      expect(updated.currentEpisode, 5);

      // Toggle favorite
      await service.toggleFavorite('custom_drama_1');
      expect(service.items.firstWhere((e) => e.id == 'custom_drama_1').isFavorite, true);

      // Episode increment and decrement
      await service.incrementEpisode('custom_drama_1');
      expect(service.items.firstWhere((e) => e.id == 'custom_drama_1').currentEpisode, 6);

      await service.decrementEpisode('custom_drama_1');
      expect(service.items.firstWhere((e) => e.id == 'custom_drama_1').currentEpisode, 5);

      // Delete
      await service.deleteItem('custom_drama_1');
      expect(service.items.any((e) => e.id == 'custom_drama_1'), false);
    });

    test('Notes management within an item', () async {
      final service = EntertainmentService();
      await service.init();

      final firstItem = service.items.first;
      final note = EntertainmentNote(
        id: 'review_note_1',
        title: 'Masterpiece',
        content: 'Flawless pacing and animation.',
        type: NoteType.review,
      );

      await service.addNoteToItem(firstItem.id, note);
      var item = service.items.firstWhere((e) => e.id == firstItem.id);
      expect(item.notes.any((n) => n.id == 'review_note_1'), true);

      // Edit Note
      await service.updateNoteInItem(
        firstItem.id,
        note.copyWith(content: 'Flawless pacing, brilliant OST and animation.'),
      );
      item = service.items.firstWhere((e) => e.id == firstItem.id);
      final found = item.notes.firstWhere((n) => n.id == 'review_note_1');
      expect(found.content, contains('OST'));

      // Delete Note
      await service.deleteNoteFromItem(firstItem.id, 'review_note_1');
      item = service.items.firstWhere((e) => e.id == firstItem.id);
      expect(item.notes.any((n) => n.id == 'review_note_1'), false);
    });

    test('Filtering, Sorting, and Statistics calculation', () async {
      final service = EntertainmentService();
      await service.init();

      final animeOnly = service.filterItems(category: EntertainmentCategory.anime);
      expect(animeOnly.every((e) => e.category == EntertainmentCategory.anime), true);

      final watchingOnly = service.filterItems(status: WatchingStatus.watching);
      expect(watchingOnly.every((e) => e.status == WatchingStatus.watching), true);

      final searchResult = service.filterItems(searchQuery: 'Frieren');
      expect(searchResult.isNotEmpty, true);
      expect(searchResult.first.title, contains('Frieren'));

      final stats = service.getStats();
      expect(stats.totalTitles, service.items.length);
      expect(stats.watchingCount, greaterThanOrEqualTo(1));
    });
  });

  group('ToolRegistry Verification', () {
    test('Entertainment Tracker is registered in ToolRegistry', () {
      final tool = ToolRegistry.findById('entertainment_tracker');
      expect(tool, isNotNull);
      expect(tool!.title, 'Entertainment Notes & Tracker');
      expect(tool.category, ToolCategory.everyday);
      expect(tool.keywords, contains('anime'));
      expect(tool.keywords, contains('drama'));
      expect(tool.keywords, contains('movies'));
      expect(tool.keywords, contains('tv series'));
    });
  });

  group('EntertainmentTrackerScreen UI Widget Tests', () {
    testWidgets('Screen renders dashboard and category tabs', (tester) async {
      tester.view.physicalSize = const Size(800 * 2.0, 1200 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: EntertainmentTrackerScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Entertainment Notes & Tracker'), findsOneWidget);
      expect(find.text('Watching Statistics'), findsOneWidget);
      expect(find.text('Currently Watching'), findsAtLeastNWidgets(1));

      // Scroll down the dashboard ListView to find 'Explore By Category'
      final dashboardFinder = find.byType(ListView).first;
      await tester.scrollUntilVisible(
        find.text('Explore By Category'),
        200,
        scrollable: find.descendant(of: dashboardFinder, matching: find.byType(Scrollable)).first,
      );
      expect(find.text('Explore By Category'), findsOneWidget);

      // Switch to Anime tab
      await tester.tap(find.text('Anime').first);
      await tester.pumpAndSettle();

      // Check search bar and filter chips
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Favourites'), findsOneWidget);
    });
  });
}
