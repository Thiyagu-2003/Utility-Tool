import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'productivity_models.dart';

class ProductivityService {
  static const String _keyNotes = 'prod_notes_list';
  static const String _keyEvents = 'prod_events_list';
  static const String _keySubs = 'prod_subscriptions_list';
  static const String _keyBills = 'prod_bills_list';
  static const String _keyWork = 'prod_work_sessions_list';
  static const String _keyTodos = 'prod_todos_list';

  // In-memory caches
  List<NoteItem> _notes = [];
  List<CalendarEventItem> _events = [];
  List<SubscriptionItem> _subscriptions = [];
  List<BillItem> _bills = [];
  List<WorkSessionItem> _workSessions = [];
  List<TodoItem> _todos = [];
  bool _isInitialized = false;

  static final ProductivityService _instance = ProductivityService._internal();
  factory ProductivityService() => _instance;
  ProductivityService._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();

    // 1. Notes
    final notesRaw = prefs.getString(_keyNotes);
    if (notesRaw != null) {
      final List decoded = jsonDecode(notesRaw);
      _notes = decoded.map((e) => NoteItem.fromJson(e)).toList();
    } else {
      _notes = _defaultNotes();
      await _saveNotes(prefs);
    }

    // 2. Events
    final eventsRaw = prefs.getString(_keyEvents);
    if (eventsRaw != null) {
      final List decoded = jsonDecode(eventsRaw);
      _events = decoded.map((e) => CalendarEventItem.fromJson(e)).toList();
    } else {
      _events = _defaultEvents();
      await _saveEvents(prefs);
    }

    // 3. Subscriptions
    final subsRaw = prefs.getString(_keySubs);
    if (subsRaw != null) {
      final List decoded = jsonDecode(subsRaw);
      _subscriptions = decoded.map((e) => SubscriptionItem.fromJson(e)).toList();
    } else {
      _subscriptions = _defaultSubscriptions();
      await _saveSubs(prefs);
    }

    // 4. Bills
    final billsRaw = prefs.getString(_keyBills);
    if (billsRaw != null) {
      final List decoded = jsonDecode(billsRaw);
      _bills = decoded.map((e) => BillItem.fromJson(e)).toList();
    } else {
      _bills = _defaultBills();
      await _saveBills(prefs);
    }

    // 5. Work Hours
    final workRaw = prefs.getString(_keyWork);
    if (workRaw != null) {
      final List decoded = jsonDecode(workRaw);
      _workSessions = decoded.map((e) => WorkSessionItem.fromJson(e)).toList();
    } else {
      _workSessions = _defaultWorkSessions();
      await _saveWork(prefs);
    }

    // 6. Todos
    final todosRaw = prefs.getString(_keyTodos);
    if (todosRaw != null) {
      final List decoded = jsonDecode(todosRaw);
      _todos = decoded.map((e) => TodoItem.fromJson(e)).toList();
    } else {
      _todos = _defaultTodos();
      await _saveTodos(prefs);
    }

    _isInitialized = true;
  }

  // --- 1. NOTES ---
  List<NoteItem> get notes => List.unmodifiable(_notes);

  Future<void> addNote(NoteItem note) async {
    _notes.insert(0, note);
    final prefs = await SharedPreferences.getInstance();
    await _saveNotes(prefs);
  }

  Future<void> updateNote(NoteItem updated) async {
    final idx = _notes.indexWhere((n) => n.id == updated.id);
    if (idx != -1) {
      _notes[idx] = updated;
      final prefs = await SharedPreferences.getInstance();
      await _saveNotes(prefs);
    }
  }

  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    final prefs = await SharedPreferences.getInstance();
    await _saveNotes(prefs);
  }

  Future<void> togglePinNote(String id) async {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notes[idx] = _notes[idx].copyWith(isPinned: !_notes[idx].isPinned);
      // Re-sort: pinned on top
      _notes.sort((a, b) {
        if (a.isPinned == b.isPinned) return b.updatedAt.compareTo(a.updatedAt);
        return a.isPinned ? -1 : 1;
      });
      final prefs = await SharedPreferences.getInstance();
      await _saveNotes(prefs);
    }
  }

  List<NoteItem> searchNotes(String query, {String? category}) {
    final q = query.trim().toLowerCase();
    return _notes.where((n) {
      final matchesQuery = q.isEmpty ||
          n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q);
      final matchesCat = category == null || category == 'All' || n.category == category;
      return matchesQuery && matchesCat;
    }).toList();
  }

  // --- 2. EVENTS ---
  List<CalendarEventItem> get events => List.unmodifiable(_events);

  Future<void> addEvent(CalendarEventItem event) async {
    _events.add(event);
    _events.sort((a, b) => a.date.compareTo(b.date));
    final prefs = await SharedPreferences.getInstance();
    await _saveEvents(prefs);
  }

  Future<void> deleteEvent(String id) async {
    _events.removeWhere((e) => e.id == id);
    final prefs = await SharedPreferences.getInstance();
    await _saveEvents(prefs);
  }

  List<CalendarEventItem> getEventsForDay(DateTime day) {
    return _events.where((e) =>
      e.date.year == day.year && e.date.month == day.month && e.date.day == day.day
    ).toList();
  }

  // --- 3. SUBSCRIPTIONS ---
  List<SubscriptionItem> get subscriptions => List.unmodifiable(_subscriptions);

  double get totalMonthlySubscriptionCost {
    return _subscriptions
        .where((s) => s.isActive)
        .fold(0.0, (sum, s) => sum + s.monthlyNormalizedCost);
  }

  double get totalAnnualSubscriptionCost => totalMonthlySubscriptionCost * 12.0;

  Future<void> addSubscription(SubscriptionItem item) async {
    _subscriptions.add(item);
    _subscriptions.sort((a, b) => a.daysUntilRenewal.compareTo(b.daysUntilRenewal));
    final prefs = await SharedPreferences.getInstance();
    await _saveSubs(prefs);
  }

  Future<void> toggleSubscriptionActive(String id) async {
    final idx = _subscriptions.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final cur = _subscriptions[idx];
      _subscriptions[idx] = SubscriptionItem(
        id: cur.id,
        name: cur.name,
        cost: cur.cost,
        billingCycle: cur.billingCycle,
        nextRenewalDate: cur.nextRenewalDate,
        category: cur.category,
        alertDaysBefore: cur.alertDaysBefore,
        isActive: !cur.isActive,
      );
      final prefs = await SharedPreferences.getInstance();
      await _saveSubs(prefs);
    }
  }

  Future<void> deleteSubscription(String id) async {
    _subscriptions.removeWhere((s) => s.id == id);
    final prefs = await SharedPreferences.getInstance();
    await _saveSubs(prefs);
  }

  // --- 4. BILLS ---
  List<BillItem> get bills => List.unmodifiable(_bills);

  double get totalUnpaidBillsAmount {
    return _bills.where((b) => !b.isPaid).fold(0.0, (sum, b) => sum + b.amount);
  }

  int get overdueBillsCount {
    return _bills.where((b) => b.isOverdue).length;
  }

  Future<void> addBill(BillItem bill) async {
    _bills.add(bill);
    _bills.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final prefs = await SharedPreferences.getInstance();
    await _saveBills(prefs);
  }

  Future<void> toggleBillPaid(String id) async {
    final idx = _bills.indexWhere((b) => b.id == id);
    if (idx != -1) {
      final cur = _bills[idx];
      _bills[idx] = BillItem(
        id: cur.id,
        title: cur.title,
        payee: cur.payee,
        amount: cur.amount,
        dueDate: cur.dueDate,
        isPaid: !cur.isPaid,
        category: cur.category,
      );
      final prefs = await SharedPreferences.getInstance();
      await _saveBills(prefs);
    }
  }

  Future<void> deleteBill(String id) async {
    _bills.removeWhere((b) => b.id == id);
    final prefs = await SharedPreferences.getInstance();
    await _saveBills(prefs);
  }

  // --- 5. WORK HOURS ---
  List<WorkSessionItem> get workSessions => List.unmodifiable(_workSessions);

  WorkSessionItem? get activeWorkSession {
    try {
      return _workSessions.firstWhere((w) => w.endTime == null);
    } catch (_) {
      return null;
    }
  }

  double get totalTrackedHours {
    return _workSessions.fold(0.0, (sum, w) => sum + w.durationHours);
  }

  double get totalEarnings {
    return _workSessions.fold(0.0, (sum, w) => sum + w.earnings);
  }

  Future<void> clockIn({double hourlyRate = 35.0, String task = 'General Project'}) async {
    if (activeWorkSession != null) return;
    final session = WorkSessionItem(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      startTime: DateTime.now(),
      hourlyRate: hourlyRate,
      taskDescription: task,
    );
    _workSessions.insert(0, session);
    final prefs = await SharedPreferences.getInstance();
    await _saveWork(prefs);
  }

  Future<void> clockOut({int breakMinutes = 0}) async {
    final current = activeWorkSession;
    if (current == null) return;
    final idx = _workSessions.indexOf(current);
    if (idx != -1) {
      _workSessions[idx] = WorkSessionItem(
        id: current.id,
        startTime: current.startTime,
        endTime: DateTime.now(),
        breakMinutes: breakMinutes,
        hourlyRate: current.hourlyRate,
        taskDescription: current.taskDescription,
      );
      final prefs = await SharedPreferences.getInstance();
      await _saveWork(prefs);
    }
  }

  Future<void> addCompletedWorkSession(WorkSessionItem session) async {
    _workSessions.insert(0, session);
    final prefs = await SharedPreferences.getInstance();
    await _saveWork(prefs);
  }

  Future<void> deleteWorkSession(String id) async {
    _workSessions.removeWhere((w) => w.id == id);
    final prefs = await SharedPreferences.getInstance();
    await _saveWork(prefs);
  }

  // --- 6. TODOS ---
  List<TodoItem> get todos => List.unmodifiable(_todos);

  double get todoCompletionRate {
    if (_todos.isEmpty) return 0.0;
    final completed = _todos.where((t) => t.isCompleted).length;
    return (completed / _todos.length) * 100.0;
  }

  Future<void> addTodo(TodoItem item) async {
    _todos.insert(0, item);
    final prefs = await SharedPreferences.getInstance();
    await _saveTodos(prefs);
  }

  Future<void> toggleTodo(String id) async {
    final idx = _todos.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _todos[idx] = _todos[idx].copyWith(isCompleted: !_todos[idx].isCompleted);
      final prefs = await SharedPreferences.getInstance();
      await _saveTodos(prefs);
    }
  }

  Future<void> deleteTodo(String id) async {
    _todos.removeWhere((t) => t.id == id);
    final prefs = await SharedPreferences.getInstance();
    await _saveTodos(prefs);
  }

  Future<void> clearCompletedTodos() async {
    _todos.removeWhere((t) => t.isCompleted);
    final prefs = await SharedPreferences.getInstance();
    await _saveTodos(prefs);
  }

  // --- PRIVATE PERSISTENCE ---
  Future<void> _saveNotes(SharedPreferences prefs) async {
    await prefs.setString(_keyNotes, jsonEncode(_notes.map((n) => n.toJson()).toList()));
  }

  Future<void> _saveEvents(SharedPreferences prefs) async {
    await prefs.setString(_keyEvents, jsonEncode(_events.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveSubs(SharedPreferences prefs) async {
    await prefs.setString(_keySubs, jsonEncode(_subscriptions.map((s) => s.toJson()).toList()));
  }

  Future<void> _saveBills(SharedPreferences prefs) async {
    await prefs.setString(_keyBills, jsonEncode(_bills.map((b) => b.toJson()).toList()));
  }

  Future<void> _saveWork(SharedPreferences prefs) async {
    await prefs.setString(_keyWork, jsonEncode(_workSessions.map((w) => w.toJson()).toList()));
  }

  Future<void> _saveTodos(SharedPreferences prefs) async {
    await prefs.setString(_keyTodos, jsonEncode(_todos.map((t) => t.toJson()).toList()));
  }

  // --- DEFAULTS ---
  List<NoteItem> _defaultNotes() => [
    NoteItem(
      id: 'note_1',
      title: 'Project Roadmap & Goals',
      content: '1. Review offline app architecture.\n2. Add productivity & event reminders.\n3. Verify test coverage & haptic performance.',
      category: 'Work',
      colorValue: 0xFF3B82F6,
      isPinned: true,
      updatedAt: DateTime.now(),
    ),
    NoteItem(
      id: 'note_2',
      title: 'Design System & Color Tokens',
      content: 'Maintain high contrast dark/light theme surfaces. Use vibrant primary orange and category theme colors for badges.',
      category: 'Ideas',
      colorValue: 0xFF10B981,
      isPinned: false,
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  List<CalendarEventItem> _defaultEvents() {
    final now = DateTime.now();
    return [
      CalendarEventItem(
        id: 'event_1',
        title: 'Team Sprint Retrospective',
        date: now.add(const Duration(days: 1)),
        time: '11:00 AM',
        location: 'Virtual Conference',
        category: 'Work',
        priority: PriorityLevel.high,
      ),
      CalendarEventItem(
        id: 'event_2',
        title: 'Quarterly Project Review',
        date: now.add(const Duration(days: 3)),
        time: '03:30 PM',
        location: 'Main Boardroom',
        category: 'Milestone',
        priority: PriorityLevel.medium,
      ),
    ];
  }

  List<SubscriptionItem> _defaultSubscriptions() {
    final now = DateTime.now();
    return [
      SubscriptionItem(
        id: 'sub_1',
        name: 'GitHub Copilot / Cloud',
        cost: 10.00,
        billingCycle: 'Monthly',
        nextRenewalDate: now.add(const Duration(days: 5)),
        category: 'Software',
        alertDaysBefore: 3,
      ),
      SubscriptionItem(
        id: 'sub_2',
        name: 'Spotify Premium Music',
        cost: 11.99,
        billingCycle: 'Monthly',
        nextRenewalDate: now.add(const Duration(days: 14)),
        category: 'Streaming',
        alertDaysBefore: 2,
      ),
      SubscriptionItem(
        id: 'sub_3',
        name: 'Domain & Cloud Hosting',
        cost: 96.00,
        billingCycle: 'Yearly',
        nextRenewalDate: now.add(const Duration(days: 42)),
        category: 'Cloud',
        alertDaysBefore: 7,
      ),
    ];
  }

  List<BillItem> _defaultBills() {
    final now = DateTime.now();
    return [
      BillItem(
        id: 'bill_1',
        title: 'Electricity & Power Bill',
        payee: 'City Energy Corp',
        amount: 85.50,
        dueDate: now.add(const Duration(days: 4)),
        category: 'Utilities',
        isPaid: false,
      ),
      BillItem(
        id: 'bill_2',
        title: 'Fiber Internet Service',
        payee: 'Telecom Broadband',
        amount: 60.00,
        dueDate: now.add(const Duration(days: 9)),
        category: 'Internet',
        isPaid: false,
      ),
    ];
  }

  List<WorkSessionItem> _defaultWorkSessions() {
    final now = DateTime.now();
    return [
      WorkSessionItem(
        id: 'work_1',
        startTime: now.subtract(const Duration(hours: 6)),
        endTime: now.subtract(const Duration(hours: 1)),
        breakMinutes: 30,
        hourlyRate: 40.0,
        taskDescription: 'Flutter App Suite Implementation',
      ),
    ];
  }

  List<TodoItem> _defaultTodos() {
    final now = DateTime.now();
    return [
      TodoItem(
        id: 'todo_1',
        title: 'Finalize Productivity & Personal Suite',
        isCompleted: true,
        priority: PriorityLevel.high,
        dueDate: now,
        category: 'Development',
      ),
      TodoItem(
        id: 'todo_2',
        title: 'Check bill due-date countdowns and renewal alerts',
        isCompleted: false,
        priority: PriorityLevel.medium,
        dueDate: now.add(const Duration(days: 2)),
        category: 'Finance',
      ),
      TodoItem(
        id: 'todo_3',
        title: 'Run test suite verification with 100% pass rate',
        isCompleted: false,
        priority: PriorityLevel.high,
        dueDate: now.add(const Duration(days: 1)),
        category: 'Testing',
      ),
    ];
  }
}
