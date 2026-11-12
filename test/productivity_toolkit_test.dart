import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utility_tool/core/models/tool_model.dart';
import 'package:utility_tool/core/registry/tool_registry.dart';
import 'package:utility_tool/features/productivity/productivity_models.dart';
import 'package:utility_tool/features/productivity/productivity_pdf.dart';
import 'package:utility_tool/features/productivity/productivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Must run first: ProductivityService is a singleton that only init()s once.
  group('ProductivityService init with corrupt storage', () {
    test('malformed JSON and bad entries are skipped instead of throwing', () async {
      SharedPreferences.setMockInitialValues({
        'prod_notes_list': '{not json',
        'prod_todos_list': '[{"id":"t_ok","title":"Keep me"}, 5, "x"]',
        'prod_subscriptions_list': '[{"id":"s","name":"N","cost":5,"alertDaysBefore":2.0,"nextRenewalDate":"2026-01-01"}]',
      });
      final service = ProductivityService();
      await service.init();
      expect(service.notes, isEmpty);
      expect(service.todos.map((t) => t.id), ['t_ok']);
      expect(service.subscriptions.single.alertDaysBefore, 2);
    });
  });

  group('Date countdown logic', () {
    test('calendarDaysBetween ignores time of day', () {
      expect(calendarDaysBetween(DateTime(2026, 3, 8, 23, 59), DateTime(2026, 3, 9, 0, 1)), 1);
      expect(calendarDaysBetween(DateTime(2026, 3, 9, 0, 1), DateTime(2026, 3, 8, 23, 59)), -1);
      expect(calendarDaysBetween(DateTime(2026, 10, 24), DateTime(2026, 11, 2)), 9);
      expect(calendarDaysBetween(DateTime(2026, 12, 31, 18), DateTime(2027, 1, 1, 6)), 1);
    });

    test('past subscription renewals roll forward by billing cycle', () {
      final monthly = SubscriptionItem(
        id: 'm',
        name: 'M',
        cost: 1,
        nextRenewalDate: DateTime(2026, 1, 31),
      );
      // Jan 31 -> Feb 28 (passed) -> Mar 31, clamped per month and never Mar 3.
      expect(monthly.nextRenewalFrom(DateTime(2026, 3, 5, 15)), DateTime(2026, 3, 31));
      expect(monthly.nextRenewalFrom(DateTime(2026, 2, 10)), DateTime(2026, 2, 28));
      // Renewal day itself is "today", not rolled.
      expect(monthly.nextRenewalFrom(DateTime(2026, 1, 31, 20)), DateTime(2026, 1, 31));

      final yearly = SubscriptionItem(
        id: 'y',
        name: 'Y',
        cost: 1,
        billingCycle: 'Yearly',
        nextRenewalDate: DateTime(2024, 2, 29),
      );
      expect(yearly.nextRenewalFrom(DateTime(2025, 3, 1)), DateTime(2026, 2, 28));

      final lapsed = SubscriptionItem(
        id: 'l',
        name: 'L',
        cost: 1,
        nextRenewalDate: DateTime.now().subtract(const Duration(days: 40)),
      );
      expect(lapsed.daysUntilRenewal, greaterThanOrEqualTo(0));
    });

    test('bill due today is not overdue, yesterday is', () {
      final now = DateTime.now();
      final dueToday = BillItem(id: 'a', title: 'A', payee: 'P', amount: 1, dueDate: DateTime(now.year, now.month, now.day));
      final dueYesterday = BillItem(id: 'b', title: 'B', payee: 'P', amount: 1, dueDate: DateTime(now.year, now.month, now.day - 1, 23, 59));
      expect(dueToday.daysUntilDue, 0);
      expect(dueToday.isOverdue, isFalse);
      expect(dueYesterday.daysUntilDue, -1);
      expect(dueYesterday.isOverdue, isTrue);
    });

    test('work session spanning midnight counts the hours across both days', () {
      final session = WorkSessionItem(
        id: 'n',
        startTime: DateTime(2026, 10, 10, 22, 0),
        endTime: DateTime(2026, 10, 11, 6, 30),
        breakMinutes: 30,
        hourlyRate: 10,
      );
      expect(session.durationHours, closeTo(8.0, 0.001));
      final roundTrip = WorkSessionItem.fromJson(session.toJson());
      expect(roundTrip.durationHours, closeTo(8.0, 0.001));
      expect(roundTrip.endTime, session.endTime);
    });
  });

  group('Productivity Models & Logic Tests', () {
    test('NoteItem serialization and copyWith', () {
      final now = DateTime.now();
      final note = NoteItem(
        id: 'n1',
        title: 'Meeting Notes',
        content: 'Discuss Q4 roadmap',
        category: 'Work',
        colorValue: 0xFF10B981,
        isPinned: false,
        updatedAt: now,
      );

      final json = note.toJson();
      final fromJson = NoteItem.fromJson(json);

      expect(fromJson.id, 'n1');
      expect(fromJson.title, 'Meeting Notes');
      expect(fromJson.category, 'Work');
      expect(fromJson.isPinned, false);

      final updated = note.copyWith(title: 'Updated Notes', isPinned: true);
      expect(updated.title, 'Updated Notes');
      expect(updated.isPinned, true);
      expect(updated.content, 'Discuss Q4 roadmap');
    });

    test('CalendarEventItem serialization and PriorityLevel parsing', () {
      final event = CalendarEventItem(
        id: 'e1',
        title: 'Client Demo',
        date: DateTime(2026, 11, 15),
        time: '02:00 PM',
        location: 'Zoom',
        category: 'Work',
        priority: PriorityLevel.high,
      );

      final json = event.toJson();
      final fromJson = CalendarEventItem.fromJson(json);

      expect(fromJson.title, 'Client Demo');
      expect(fromJson.priority, PriorityLevel.high);
      expect(fromJson.location, 'Zoom');
      expect(PriorityLevel.fromString('low'), PriorityLevel.low);
      expect(PriorityLevel.fromString('HIGH'), PriorityLevel.high);
    });

    test('SubscriptionItem cost calculations and normalization', () {
      final monthly = SubscriptionItem(
        id: 's1',
        name: 'Music Stream',
        cost: 9.99,
        billingCycle: 'Monthly',
        nextRenewalDate: DateTime.now().add(const Duration(days: 5)),
      );

      final yearly = SubscriptionItem(
        id: 's2',
        name: 'Cloud Storage',
        cost: 120.0,
        billingCycle: 'Yearly',
        nextRenewalDate: DateTime.now().add(const Duration(days: 20)),
      );

      expect(monthly.monthlyNormalizedCost, closeTo(9.99, 0.001));
      expect(yearly.monthlyNormalizedCost, closeTo(10.0, 0.001));
      expect(monthly.daysUntilRenewal, greaterThanOrEqualTo(4));
    });

    test('BillItem due date and overdue logic', () {
      final today = DateTime.now();
      final futureBill = BillItem(
        id: 'b1',
        title: 'Electricity',
        payee: 'Power Corp',
        amount: 85.50,
        dueDate: today.add(const Duration(days: 7)),
      );

      final pastBill = BillItem(
        id: 'b2',
        title: 'Internet',
        payee: 'Fiber Co',
        amount: 60.00,
        dueDate: today.subtract(const Duration(days: 3)),
        isPaid: false,
      );

      final paidPastBill = BillItem(
        id: 'b3',
        title: 'Water',
        payee: 'City Water',
        amount: 45.00,
        dueDate: today.subtract(const Duration(days: 5)),
        isPaid: true,
      );

      expect(futureBill.isOverdue, isFalse);
      expect(futureBill.daysUntilDue, greaterThanOrEqualTo(6));
      expect(pastBill.isOverdue, isTrue);
      expect(pastBill.daysUntilDue, lessThan(0));
      expect(paidPastBill.isOverdue, isFalse); // Paid bills are never overdue
    });

    test('WorkSessionItem duration and earnings calculations', () {
      final start = DateTime(2026, 10, 10, 9, 0);
      final end = DateTime(2026, 10, 10, 17, 30); // 8.5 hours

      final session = WorkSessionItem(
        id: 'w1',
        startTime: start,
        endTime: end,
        breakMinutes: 30, // 8.0 billable hours
        hourlyRate: 40.0,
        taskDescription: 'Flutter Development',
      );

      expect(session.durationHours, closeTo(8.0, 0.01));
      expect(session.earnings, closeTo(320.0, 0.01));
    });

    test('TodoItem model and copyWith', () {
      final todo = TodoItem(
        id: 't1',
        title: 'Finish API Docs',
        isCompleted: false,
        priority: PriorityLevel.high,
        subtasks: ['Write overview', 'Add endpoints'],
      );

      expect(todo.isCompleted, isFalse);
      expect(todo.subtasks.length, 2);

      final done = todo.copyWith(isCompleted: true);
      expect(done.isCompleted, isTrue);
      expect(done.title, 'Finish API Docs');
    });
  });

  group('ProductivityService Integration & Storage Tests', () {
    late ProductivityService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = ProductivityService();
      await service.init();
    });

    test('Notes CRUD and Pinning & Search', () async {
      final note1 = NoteItem(
        id: 'custom_1',
        title: 'Groceries List',
        content: 'Milk, Eggs, Bread',
        category: 'Personal',
        updatedAt: DateTime.now(),
      );
      final note2 = NoteItem(
        id: 'custom_2',
        title: 'Architecture Review',
        content: 'Review microservices design',
        category: 'Work',
        updatedAt: DateTime.now(),
      );

      await service.addNote(note1);
      await service.addNote(note2);

      expect(service.notes.any((n) => n.id == 'custom_1'), isTrue);
      expect(service.notes.any((n) => n.id == 'custom_2'), isTrue);

      // Search by text
      final searchRes = service.searchNotes('groceries');
      expect(searchRes.length, 1);
      expect(searchRes.first.id, 'custom_1');

      // Search by category
      final workNotes = service.searchNotes('', category: 'Work');
      expect(workNotes.any((n) => n.id == 'custom_2'), isTrue);

      // Pinning note
      await service.togglePinNote('custom_1');
      expect(service.notes.first.id, 'custom_1');
      expect(service.notes.first.isPinned, isTrue);

      // Delete note
      await service.deleteNote('custom_1');
      expect(service.notes.any((n) => n.id == 'custom_1'), isFalse);
    });

    test('Calendar Events CRUD and day query', () async {
      final targetDate = DateTime(2026, 12, 25);
      final event = CalendarEventItem(
        id: 'evt_x',
        title: 'Holiday Party',
        date: targetDate,
        time: '06:00 PM',
      );

      await service.addEvent(event);
      final dayEvents = service.getEventsForDay(targetDate);
      expect(dayEvents.length, 1);
      expect(dayEvents.first.title, 'Holiday Party');

      await service.deleteEvent('evt_x');
      expect(service.getEventsForDay(targetDate).isEmpty, isTrue);
    });

    test('Subscriptions calculations and active toggle', () async {
      // Clear out default subs or check additions
      final initialCost = service.totalMonthlySubscriptionCost;

      final newSub = SubscriptionItem(
        id: 'sub_test',
        name: 'Streaming Premium',
        cost: 15.0,
        billingCycle: 'Monthly',
        nextRenewalDate: DateTime.now().add(const Duration(days: 10)),
      );

      await service.addSubscription(newSub);
      expect(service.totalMonthlySubscriptionCost, closeTo(initialCost + 15.0, 0.01));

      // Deactivate subscription
      await service.toggleSubscriptionActive('sub_test');
      expect(service.totalMonthlySubscriptionCost, closeTo(initialCost, 0.01));

      await service.deleteSubscription('sub_test');
    });

    test('Bills unpaid calculations and toggle paid', () async {
      final initialUnpaid = service.totalUnpaidBillsAmount;

      final newBill = BillItem(
        id: 'bill_test',
        title: 'Gym Membership',
        payee: 'Fit Club',
        amount: 50.0,
        dueDate: DateTime.now().add(const Duration(days: 4)),
      );

      await service.addBill(newBill);
      expect(service.totalUnpaidBillsAmount, closeTo(initialUnpaid + 50.0, 0.01));

      // Mark paid
      await service.toggleBillPaid('bill_test');
      expect(service.totalUnpaidBillsAmount, closeTo(initialUnpaid, 0.01));

      await service.deleteBill('bill_test');
    });

    test('Work session clock-in and clock-out workflow', () async {
      expect(service.activeWorkSession, isNull);

      await service.clockIn(hourlyRate: 50.0, task: 'UI Polish');
      expect(service.activeWorkSession, isNotNull);
      expect(service.activeWorkSession!.taskDescription, 'UI Polish');

      await service.clockOut(breakMinutes: 0);
      expect(service.activeWorkSession, isNull);
    });

    test('Todos completion rate and toggling', () async {
      final initialTodosCount = service.todos.length;
      final todo = TodoItem(
        id: 'todo_test',
        title: 'Ship Release v1.0.86',
        isCompleted: false,
      );

      await service.addTodo(todo);
      expect(service.todos.length, initialTodosCount + 1);

      await service.toggleTodo('todo_test');
      final checked = service.todos.firstWhere((t) => t.id == 'todo_test');
      expect(checked.isCompleted, isTrue);

      await service.deleteTodo('todo_test');
      expect(service.todos.length, initialTodosCount);
    });
  });

  group('ToolRegistry Verification for Productivity Suite', () {
    test('Productivity & Organization Suite is registered in ToolRegistry', () {
      final tool = ToolRegistry.allTools.firstWhere(
        (t) => t.id == 'productivity_toolkit',
        orElse: () => throw Exception('productivity_toolkit not found in ToolRegistry'),
      );

      expect(tool.title, 'Productivity & Organization Suite');
      expect(tool.category, ToolCategory.productivity);
      expect(tool.keywords.contains('notes'), isTrue);
      expect(tool.keywords.contains('calendar'), isTrue);
      expect(tool.keywords.contains('subscription'), isTrue);
      expect(tool.keywords.contains('bill'), isTrue);
      expect(tool.keywords.contains('work hours'), isTrue);
      expect(tool.keywords.contains('todo'), isTrue);
    });
  });

  group('To-do filters and subtasks', () {
    final todos = [
      TodoItem(id: 'a', title: 'A', category: 'Finance'),
      TodoItem(id: 'b', title: 'B', category: 'Finance', isCompleted: true),
      TodoItem(id: 'c', title: 'C', category: 'Tasks', isCompleted: true),
      TodoItem(id: 'd', title: 'D', category: 'Tasks'),
    ];

    test('status tabs combine with the category chip', () {
      List<String> ids(List<TodoItem> l) => l.map((t) => t.id).toList();
      expect(ids(filterTodos(todos)), ['a', 'b', 'c', 'd']);
      expect(ids(filterTodos(todos, status: TodoFilter.active)), ['a', 'd']);
      expect(ids(filterTodos(todos, status: TodoFilter.completed)), ['b', 'c']);
      expect(ids(filterTodos(todos, category: 'Finance')), ['a', 'b']);
      expect(ids(filterTodos(todos, category: 'Finance', status: TodoFilter.completed)), ['b']);
      expect(filterTodos(todos, category: 'Nope'), isEmpty);
    });

    test('subtasks can be added, ticked, removed and survive JSON', () {
      var t = TodoItem(id: 't', title: 'Trip');
      t = t.addSubtask('  Book hotel ').addSubtask('Pack').addSubtask('Buy tickets').addSubtask('   ');
      expect(t.subtasks, ['Book hotel', 'Pack', 'Buy tickets']);

      t = t.toggleSubtask(1).toggleSubtask(2);
      expect(t.doneSubtasks, [1, 2]);
      expect(t.isSubtaskDone(0), isFalse);
      t = t.toggleSubtask(1);
      expect(t.doneSubtasks, [2]);

      // Removing an earlier subtask shifts the done marker of the later one.
      t = t.removeSubtask(0);
      expect(t.subtasks, ['Pack', 'Buy tickets']);
      expect(t.doneSubtasks, [1]);
      expect(t.isSubtaskDone(1), isTrue);

      expect(t.toggleSubtask(9), same(t)); // out of range is a no-op
      final back = TodoItem.fromJson(t.toJson());
      expect(back.subtasks, t.subtasks);
      expect(back.doneSubtasks, [1]);
    });

    test('old stored todos without doneSubtasks, or with bad indexes, load cleanly', () {
      final old = TodoItem.fromJson({'id': 'o', 'title': 'Old', 'subtasks': ['x', 'y']});
      expect(old.doneSubtasks, isEmpty);
      final bad = TodoItem.fromJson({'id': 'b', 'title': 'Bad', 'subtasks': ['x'], 'doneSubtasks': [0, 5, -1, 'z']});
      expect(bad.doneSubtasks, [0]);
    });
  });

  group('ProductivityService additions', () {
    late ProductivityService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = ProductivityService();
      await service.init();
    });

    test('updateTodo persists a subtask change', () async {
      final todo = TodoItem(id: 'upd_todo', title: 'Plan').addSubtask('Step 1');
      await service.addTodo(todo);
      await service.updateTodo(service.todos.firstWhere((t) => t.id == 'upd_todo').toggleSubtask(0));
      expect(service.todos.firstWhere((t) => t.id == 'upd_todo').doneSubtasks, [0]);
      await service.updateTodo(TodoItem(id: 'unknown', title: 'x')); // unknown id is ignored
      expect(service.todos.any((t) => t.id == 'unknown'), isFalse);
      await service.deleteTodo('upd_todo');
    });

    test('upcomingEventsCount ignores past days but counts today', () async {
      final now = DateTime(2026, 6, 15, 18, 30);
      final before = service.upcomingEventsCount(now);
      await service.addEvent(CalendarEventItem(id: 'ev_past', title: 'Past', date: DateTime(2026, 6, 14, 23)));
      await service.addEvent(CalendarEventItem(id: 'ev_today', title: 'Today', date: DateTime(2026, 6, 15, 8)));
      await service.addEvent(CalendarEventItem(id: 'ev_next', title: 'Next', date: DateTime(2026, 6, 16)));
      expect(service.upcomingEventsCount(now), before + 2);
      await service.deleteEvent('ev_past');
      await service.deleteEvent('ev_today');
      await service.deleteEvent('ev_next');
    });
  });

  group('Notes and agenda PDFs', () {
    test('buildNotesPdf and buildAgendaPdf return real PDF bytes', () async {
      final notes = [
        NoteItem(id: '1', title: 'Groceries', content: 'Milk\nEggs', category: 'Personal', updatedAt: DateTime(2026, 1, 2), isPinned: true),
        NoteItem(id: '2', title: 'Tamil title தமிழ்', content: 'x' * 6000, updatedAt: DateTime(2026, 1, 3)),
        NoteItem(id: '3', title: 'Long prose', content: 'lorem ipsum dolor ' * 1500, updatedAt: DateTime(2026, 1, 4)),
      ];
      final notesPdf = await buildNotesPdf(notes);
      expect(String.fromCharCodes(notesPdf.take(5)), '%PDF-');

      final agendaPdf = await buildAgendaPdf(
        DateTime(2026, 1, 2),
        [CalendarEventItem(id: 'e', title: 'Standup', date: DateTime(2026, 1, 2), time: '10:00 AM', location: 'Room 4')],
      );
      expect(String.fromCharCodes(agendaPdf.take(5)), '%PDF-');
      expect((await buildAgendaPdf(DateTime(2026, 1, 2), const [])).isNotEmpty, isTrue);
    });

    test('pdfSafe replaces characters the built-in PDF fonts cannot draw', () {
      expect(pdfSafe('café plain'), 'café plain'); // Latin-1 is fine
      expect(pdfSafe('aதb'), 'a?b');
      // Unbreakable runs get a space every 60 chars so the PDF can paginate; normal text is untouched.
      expect(pdfSafe('hello world'), 'hello world');
      expect(pdfSafe('x' * 130), '${'x' * 60} ${'x' * 60} ${'x' * 10}');
    });
  });

  group('Notes Management Advanced Features', () {
    test('NoteItem supports folders, tags, checklist items, image attachments, and web links', () {
      final now = DateTime(2026, 11, 11, 12, 0);
      final note = NoteItem(
        id: 'note_full',
        title: 'Project Roadmap',
        content: '# Goals\n- Launch v1\n- Add docs',
        category: 'Work',
        folder: 'Q4 Initiatives',
        tags: ['release', 'urgent', 'roadmap'],
        isChecklist: true,
        checklist: [
          ChecklistItem(id: 'c1', text: 'Write specs', isDone: true),
          ChecklistItem(id: 'c2', text: 'Deploy apk', isDone: false),
        ],
        imagePaths: ['/storage/emulated/0/Pictures/spec.png'],
        webLinks: ['https://example.com/spec', 'https://github.com/project'],
        updatedAt: now,
        createdAt: now.subtract(const Duration(days: 3)),
      );

      final json = note.toJson();
      final restored = NoteItem.fromJson(json);

      expect(restored.id, 'note_full');
      expect(restored.title, 'Project Roadmap');
      expect(restored.folder, 'Q4 Initiatives');
      expect(restored.tags, ['release', 'urgent', 'roadmap']);
      expect(restored.isChecklist, isTrue);
      expect(restored.checklist.length, 2);
      expect(restored.checklist[0].isDone, isTrue);
      expect(restored.checklist[1].isDone, isFalse);
      expect(restored.imagePaths, ['/storage/emulated/0/Pictures/spec.png']);
      expect(restored.webLinks, ['https://example.com/spec', 'https://github.com/project']);
      expect(restored.createdAt, now.subtract(const Duration(days: 3)));
    });

    test('Checklist notes helpers add, toggle, and remove items', () {
      var note = NoteItem(
        id: 'n1',
        title: 'Grocery List',
        content: '',
        isChecklist: true,
        updatedAt: DateTime.now(),
      );

      note = note.addChecklistItem('Milk');
      note = note.addChecklistItem('Apples');
      expect(note.checklist.length, 2);
      expect(note.checklist[0].text, 'Milk');
      expect(note.checklist[0].isDone, isFalse);

      note = note.toggleChecklistItem(0);
      expect(note.checklist[0].isDone, isTrue);
      expect(note.checklist[1].isDone, isFalse);

      note = note.removeChecklistItem(0);
      expect(note.checklist.length, 1);
      expect(note.checklist[0].text, 'Apples');
    });

    test('ProductivityService searches notes across tags, folders, checklist, and content', () async {
      final service = ProductivityService();
      final n1 = NoteItem(
        id: 'search_1',
        title: 'Sprint Planning',
        content: 'Review the sprint backlog',
        folder: 'Work',
        category: 'Work',
        tags: ['agile', 'scrum'],
        updatedAt: DateTime.now(),
      );
      final n2 = NoteItem(
        id: 'search_2',
        title: 'Packing List',
        content: '',
        folder: 'Travel',
        category: 'Personal',
        tags: ['vacation'],
        isChecklist: true,
        checklist: [ChecklistItem(id: 'c1', text: 'Passport and tickets')],
        updatedAt: DateTime.now(),
      );

      await service.addNote(n1);
      await service.addNote(n2);

      // Search by tag
      expect(service.searchNotes('', tag: 'agile').map((n) => n.id), contains('search_1'));
      // Search by folder
      expect(service.searchNotes('', folder: 'Travel').map((n) => n.id), contains('search_2'));
      // Full text search in checklist text
      expect(service.searchNotes('passport').map((n) => n.id), contains('search_2'));
      // Search in content
      expect(service.searchNotes('backlog').map((n) => n.id), contains('search_1'));

      await service.deleteNote('search_1');
      await service.deleteNote('search_2');
    });
  });

  group('Calendar & Recurring Events Logic', () {
    test('CalendarEventItem occursOnDate correctly handles recurrence rules', () {
      final start = DateTime(2026, 11, 10); // Tuesday

      final oneTime = CalendarEventItem(
        id: 'e1',
        title: 'Single Meeting',
        date: start,
        recurrence: EventRecurrence.none,
      );
      expect(oneTime.occursOnDate(DateTime(2026, 11, 10)), isTrue);
      expect(oneTime.occursOnDate(DateTime(2026, 11, 11)), isFalse);
      expect(oneTime.occursOnDate(DateTime(2026, 11, 9)), isFalse);

      final daily = CalendarEventItem(
        id: 'e2',
        title: 'Daily Standup',
        date: start,
        recurrence: EventRecurrence.daily,
      );
      expect(daily.occursOnDate(DateTime(2026, 11, 10)), isTrue);
      expect(daily.occursOnDate(DateTime(2026, 11, 15)), isTrue);
      expect(daily.occursOnDate(DateTime(2026, 11, 9)), isFalse); // Before start date

      final weekly = CalendarEventItem(
        id: 'e3',
        title: 'Weekly 1:1',
        date: start, // Tuesday
        recurrence: EventRecurrence.weekly,
      );
      expect(weekly.occursOnDate(DateTime(2026, 11, 10)), isTrue); // Same Tuesday
      expect(weekly.occursOnDate(DateTime(2026, 11, 17)), isTrue); // Next Tuesday
      expect(weekly.occursOnDate(DateTime(2026, 11, 11)), isFalse); // Wednesday

      final monthly = CalendarEventItem(
        id: 'e4',
        title: 'Monthly Review',
        date: DateTime(2026, 1, 15),
        recurrence: EventRecurrence.monthly,
      );
      expect(monthly.occursOnDate(DateTime(2026, 2, 15)), isTrue);
      expect(monthly.occursOnDate(DateTime(2026, 3, 15)), isTrue);
      expect(monthly.occursOnDate(DateTime(2026, 3, 16)), isFalse);

      final yearly = CalendarEventItem(
        id: 'e5',
        title: 'Annual Anniversary',
        date: DateTime(2025, 4, 20),
        recurrence: EventRecurrence.yearly,
      );
      expect(yearly.occursOnDate(DateTime(2026, 4, 20)), isTrue);
      expect(yearly.occursOnDate(DateTime(2027, 4, 20)), isTrue);
      expect(yearly.occursOnDate(DateTime(2026, 4, 21)), isFalse);
    });

    test('CalendarEventItem supports linked notes, end time, and description', () {
      final event = CalendarEventItem(
        id: 'ev_adv',
        title: 'Architecture Review',
        date: DateTime(2026, 11, 12),
        time: '10:00 AM',
        endTime: '11:30 AM',
        location: 'Zoom Room #402',
        description: 'Review microservice architecture diagrams',
        recurrence: EventRecurrence.weekly,
        linkedNoteIds: ['note_arch_1', 'note_arch_2'],
        colorValue: 0xFF10B981,
        hasReminder: true,
        reminderMinutesBefore: 15,
      );

      final json = event.toJson();
      final restored = CalendarEventItem.fromJson(json);

      expect(restored.endTime, '11:30 AM');
      expect(restored.description, 'Review microservice architecture diagrams');
      expect(restored.recurrence, EventRecurrence.weekly);
      expect(restored.linkedNoteIds, ['note_arch_1', 'note_arch_2']);
      expect(restored.colorValue, 0xFF10B981);
      expect(restored.hasReminder, isTrue);
      expect(restored.reminderMinutesBefore, 15);
    });

    test('ProductivityService range and day queries include recurring events', () async {
      final service = ProductivityService();
      final recurringEvent = CalendarEventItem(
        id: 'ev_rec_test',
        title: 'Daily Checkin',
        date: DateTime(2026, 11, 1),
        recurrence: EventRecurrence.daily,
      );
      await service.addEvent(recurringEvent);

      final dayEvents = service.getEventsForDay(DateTime(2026, 11, 20));
      expect(dayEvents.any((e) => e.id == 'ev_rec_test'), isTrue);

      final rangeEvents = service.getEventsForRange(
        DateTime(2026, 11, 5),
        DateTime(2026, 11, 10),
      );
      expect(rangeEvents.any((e) => e.id == 'ev_rec_test'), isTrue);

      await service.deleteEvent('ev_rec_test');
    });
  });

  group('Tasks & Overdue Status Logic', () {
    test('TodoItem correctly computes isOverdue, isDueToday, and isUpcoming', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final overdue = TodoItem(
        id: 't_over',
        title: 'Overdue task',
        dueDate: today.subtract(const Duration(days: 2)),
      );
      expect(overdue.isOverdue, isTrue);
      expect(overdue.isDueToday, isFalse);
      expect(overdue.isUpcoming, isFalse);

      final dueToday = TodoItem(
        id: 't_today',
        title: 'Due today task',
        dueDate: today,
      );
      expect(dueToday.isOverdue, isFalse);
      expect(dueToday.isDueToday, isTrue);
      expect(dueToday.isUpcoming, isFalse);

      final upcoming = TodoItem(
        id: 't_up',
        title: 'Upcoming task',
        dueDate: today.add(const Duration(days: 3)),
      );
      expect(upcoming.isOverdue, isFalse);
      expect(upcoming.isDueToday, isFalse);
      expect(upcoming.isUpcoming, isTrue);

      // Completed task is never overdue
      final completedOverdue = overdue.copyWith(isCompleted: true);
      expect(completedOverdue.isOverdue, isFalse);
    });

    test('filterTodos supports overdue and today filters', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final tasks = [
        TodoItem(id: '1', title: 'Task 1', dueDate: today.subtract(const Duration(days: 1))),
        TodoItem(id: '2', title: 'Task 2', dueDate: today),
        TodoItem(id: '3', title: 'Task 3', dueDate: today.add(const Duration(days: 2))),
      ];

      final overdueList = filterTodos(tasks, status: TodoFilter.overdue);
      expect(overdueList.map((t) => t.id), ['1']);

      final todayList = filterTodos(tasks, status: TodoFilter.today);
      expect(todayList.map((t) => t.id), ['2']);
    });
  });

  group('Reminders & Notification Scheduling Model', () {
    test('ReminderItem serialization and deserialization', () {
      final time = DateTime(2026, 11, 15, 9, 30);
      final reminder = ReminderItem(
        id: 'rem_101',
        title: 'Call Doctor',
        body: 'Confirm routine checkup',
        scheduledAt: time,
        type: ReminderType.recurringWeekly,
        isEnabled: true,
        relatedId: 'event_42',
      );

      final json = reminder.toJson();
      final restored = ReminderItem.fromJson(json);

      expect(restored.id, 'rem_101');
      expect(restored.title, 'Call Doctor');
      expect(restored.body, 'Confirm routine checkup');
      expect(restored.scheduledAt, time);
      expect(restored.type, ReminderType.recurringWeekly);
      expect(restored.isEnabled, isTrue);
      expect(restored.relatedId, 'event_42');
    });

    test('ProductivityService manages reminders CRUD and toggles', () async {
      final service = ProductivityService();
      final r = ReminderItem(
        id: 'rem_test_toggle',
        title: 'Take vitamins',
        scheduledAt: DateTime.now().add(const Duration(hours: 2)),
        type: ReminderType.recurringDaily,
        isEnabled: true,
      );

      await service.addReminder(r);
      expect(service.reminders.any((rem) => rem.id == 'rem_test_toggle'), isTrue);

      await service.toggleReminderEnabled('rem_test_toggle');
      final toggled = service.reminders.firstWhere((rem) => rem.id == 'rem_test_toggle');
      expect(toggled.isEnabled, isFalse);

      await service.deleteReminder('rem_test_toggle');
      expect(service.reminders.any((rem) => rem.id == 'rem_test_toggle'), isFalse);
    });
  });

  group('Personal Planner Module Registry Verification', () {
    test('Notes, Calendar & Personal Planner tool is registered in ToolRegistry', () {
      final tool = ToolRegistry.allTools.firstWhere(
        (t) => t.id == 'personal_planner',
        orElse: () => throw Exception('personal_planner not found in ToolRegistry'),
      );

      expect(tool.title, 'Notes, Calendar & Personal Planner');
      expect(tool.category, ToolCategory.productivity);
      expect(tool.keywords, contains('planner'));
      expect(tool.keywords, contains('notes'));
      expect(tool.keywords, contains('calendar'));
      expect(tool.keywords, contains('agenda'));
      expect(tool.keywords, contains('todo'));
      expect(tool.keywords, contains('reminders'));
      expect(tool.builder, isNotNull);
    });
  });
}
