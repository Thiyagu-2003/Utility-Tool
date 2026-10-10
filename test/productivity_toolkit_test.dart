import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utility_tool/core/models/tool_model.dart';
import 'package:utility_tool/core/registry/tool_registry.dart';
import 'package:utility_tool/features/productivity/productivity_models.dart';
import 'package:utility_tool/features/productivity/productivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(tool.category, ToolCategory.dateTime);
      expect(tool.keywords.contains('notes'), isTrue);
      expect(tool.keywords.contains('calendar'), isTrue);
      expect(tool.keywords.contains('subscription'), isTrue);
      expect(tool.keywords.contains('bill'), isTrue);
      expect(tool.keywords.contains('work hours'), isTrue);
      expect(tool.keywords.contains('todo'), isTrue);
    });
  });
}
