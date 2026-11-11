import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';
import 'productivity_models.dart';

class ProductivityService {
  static const String _keyNotes = 'prod_notes_list';
  static const String _keyEvents = 'prod_events_list';
  static const String _keySubs = 'prod_subscriptions_list';
  static const String _keyBills = 'prod_bills_list';
  static const String _keyWork = 'prod_work_sessions_list';
  static const String _keyTodos = 'prod_todos_list';
  static const String _keyReminders = 'prod_reminders_list';
  static const String _keyFolders = 'prod_note_folders_list';

  // In-memory caches
  List<NoteItem> _notes = [];
  List<CalendarEventItem> _events = [];
  List<SubscriptionItem> _subscriptions = [];
  List<BillItem> _bills = [];
  List<WorkSessionItem> _workSessions = [];
  List<TodoItem> _todos = [];
  List<ReminderItem> _reminders = [];
  List<String> _customFolders = ['General', 'Personal', 'Work', 'Projects', 'Archive'];
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
      _notes = _decodeList(notesRaw, NoteItem.fromJson);
    } else {
      _notes = <NoteItem>[];
      await _saveNotes(prefs);
    }

    // 2. Events
    final eventsRaw = prefs.getString(_keyEvents);
    if (eventsRaw != null) {
      _events = _decodeList(eventsRaw, CalendarEventItem.fromJson);
    } else {
      _events = <CalendarEventItem>[];
      await _saveEvents(prefs);
    }

    // 3. Subscriptions
    final subsRaw = prefs.getString(_keySubs);
    if (subsRaw != null) {
      _subscriptions = _decodeList(subsRaw, SubscriptionItem.fromJson);
    } else {
      _subscriptions = <SubscriptionItem>[];
      await _saveSubs(prefs);
    }

    // 4. Bills
    final billsRaw = prefs.getString(_keyBills);
    if (billsRaw != null) {
      _bills = _decodeList(billsRaw, BillItem.fromJson);
    } else {
      _bills = <BillItem>[];
      await _saveBills(prefs);
    }

    // 5. Work Hours
    final workRaw = prefs.getString(_keyWork);
    if (workRaw != null) {
      _workSessions = _decodeList(workRaw, WorkSessionItem.fromJson);
    } else {
      _workSessions = <WorkSessionItem>[];
      await _saveWork(prefs);
    }

    // 6. Todos
    final todosRaw = prefs.getString(_keyTodos);
    if (todosRaw != null) {
      _todos = _decodeList(todosRaw, TodoItem.fromJson);
    } else {
      _todos = <TodoItem>[];
      await _saveTodos(prefs);
    }

    // 7. Reminders
    final remindersRaw = prefs.getString(_keyReminders);
    if (remindersRaw != null) {
      _reminders = _decodeList(remindersRaw, ReminderItem.fromJson);
    } else {
      _reminders = <ReminderItem>[];
      await _saveReminders(prefs);
    }

    // 8. Custom Note Folders
    final foldersRaw = prefs.getStringList(_keyFolders);
    if (foldersRaw != null && foldersRaw.isNotEmpty) {
      _customFolders = List<String>.from(foldersRaw);
    }

    _isInitialized = true;

    // Reschedule active notifications in background
    try {
      NotificationService().rescheduleAll(_reminders).catchError((e) {
        debugPrint('ProductivityService init notification reschedule: $e');
      });
    } catch (_) {}
  }

  /// Decodes a stored list, skipping malformed entries instead of throwing.
  static List<T> _decodeList<T>(String raw, T Function(Map<String, dynamic>) fromJson) {
    final result = <T>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return result;
      for (final e in decoded) {
        try {
          result.add(fromJson(e as Map<String, dynamic>));
        } catch (_) {}
      }
    } catch (_) {}
    return result;
  }

  // --- 1. NOTES ---
  List<NoteItem> get notes => List.unmodifiable(_notes);

  List<NoteItem> get pinnedNotes => _notes.where((n) => n.isPinned).toList();

  List<NoteItem> get recentNotes {
    final sorted = List<NoteItem>.from(_notes);
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  List<String> get noteFolders {
    final set = Set<String>.from(_customFolders);
    for (final n in _notes) {
      if (n.folder.isNotEmpty) set.add(n.folder);
    }
    return set.toList();
  }

  List<String> get noteTags {
    final set = <String>{};
    for (final n in _notes) {
      set.addAll(n.tags);
    }
    return set.toList();
  }

  Future<void> addFolder(String folderName) async {
    final clean = folderName.trim();
    if (clean.isEmpty || _customFolders.contains(clean)) return;
    _customFolders.add(clean);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyFolders, _customFolders);
  }

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
      // Re-sort: pinned on top, then by updatedAt
      _notes.sort((a, b) {
        if (a.isPinned == b.isPinned) return b.updatedAt.compareTo(a.updatedAt);
        return a.isPinned ? -1 : 1;
      });
      final prefs = await SharedPreferences.getInstance();
      await _saveNotes(prefs);
    }
  }

  List<NoteItem> searchNotes(
    String query, {
    String? category,
    String? folder,
    String? tag,
  }) {
    final q = query.trim().toLowerCase();
    return _notes.where((n) {
      final matchesQuery = q.isEmpty ||
          n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q) ||
          n.checklist.any((c) => c.text.toLowerCase().contains(q)) ||
          n.tags.any((t) => t.toLowerCase().contains(q));
      final matchesCat = category == null || category == 'All' || n.category == category;
      final matchesFolder = folder == null || folder == 'All' || n.folder == folder;
      final matchesTag = tag == null || tag == 'All' || n.tags.contains(tag);
      return matchesQuery && matchesCat && matchesFolder && matchesTag;
    }).toList();
  }

  // --- 2. EVENTS ---
  List<CalendarEventItem> get events => List.unmodifiable(_events);

  Future<void> addEvent(CalendarEventItem event) async {
    _events.add(event);
    _events.sort((a, b) => a.date.compareTo(b.date));
    final prefs = await SharedPreferences.getInstance();
    await _saveEvents(prefs);

    if (event.hasReminder) {
      final reminderTime = event.date.subtract(Duration(minutes: event.reminderMinutesBefore));
      final reminder = ReminderItem(
        id: 'rem_ev_${event.id}',
        title: 'Event: ${event.title}',
        body: '${event.time} ${event.location.isNotEmpty ? "at ${event.location}" : ""}',
        scheduledAt: reminderTime,
        type: ReminderType.event,
        relatedId: event.id,
      );
      await addReminder(reminder);
    }
  }

  Future<void> updateEvent(CalendarEventItem updated) async {
    final idx = _events.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      _events[idx] = updated;
      _events.sort((a, b) => a.date.compareTo(b.date));
      final prefs = await SharedPreferences.getInstance();
      await _saveEvents(prefs);

      // Handle linked reminder
      await deleteReminderByRelatedId(updated.id);
      if (updated.hasReminder) {
        final reminderTime = updated.date.subtract(Duration(minutes: updated.reminderMinutesBefore));
        final reminder = ReminderItem(
          id: 'rem_ev_${updated.id}',
          title: 'Event: ${updated.title}',
          body: '${updated.time} ${updated.location.isNotEmpty ? "at ${updated.location}" : ""}',
          scheduledAt: reminderTime,
          type: ReminderType.event,
          relatedId: updated.id,
        );
        await addReminder(reminder);
      }
    }
  }

  Future<void> deleteEvent(String id) async {
    _events.removeWhere((e) => e.id == id);
    final prefs = await SharedPreferences.getInstance();
    await _saveEvents(prefs);
    await deleteReminderByRelatedId(id);
  }

  /// Events occurring today or in the future.
  int upcomingEventsCount([DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    return _events.where((e) {
      if (e.recurrence != EventRecurrence.none) return true;
      final evDate = DateTime(e.date.year, e.date.month, e.date.day);
      return !evDate.isBefore(today);
    }).length;
  }

  /// Returns all events (including recurring ones) occurring on [day].
  List<CalendarEventItem> getEventsForDay(DateTime day) {
    return _events.where((e) => e.occursOnDate(day)).toList();
  }

  /// Returns events occurring within a date range [start, end] inclusive.
  List<CalendarEventItem> getEventsForRange(DateTime start, DateTime end) {
    final list = <CalendarEventItem>[];
    for (var d = DateTime(start.year, start.month, start.day);
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      for (final ev in _events) {
        if (ev.occursOnDate(d) && !list.contains(ev)) {
          list.add(ev);
        }
      }
    }
    return list;
  }

  /// Today's agenda events.
  List<CalendarEventItem> get todayAgenda => getEventsForDay(DateTime.now());

  /// Upcoming events for the next [days] days.
  List<CalendarEventItem> getUpcomingEvents({int days = 7}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(Duration(days: days));
    return getEventsForRange(today, end);
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

  // --- 6. TODOS & TASKS ---
  List<TodoItem> get todos => List.unmodifiable(_todos);

  List<TodoItem> get overdueTodos => _todos.where((t) => t.isOverdue).toList();

  List<TodoItem> get dueTodayTodos => _todos.where((t) => t.isDueToday).toList();

  List<TodoItem> get upcomingTodos => _todos.where((t) => t.isUpcoming).toList();

  List<TodoItem> get pendingTodos => _todos.where((t) => !t.isCompleted).toList();

  double get todoCompletionRate {
    if (_todos.isEmpty) return 0.0;
    final completed = _todos.where((t) => t.isCompleted).length;
    return (completed / _todos.length) * 100.0;
  }

  Future<void> addTodo(TodoItem item) async {
    _todos.insert(0, item);
    final prefs = await SharedPreferences.getInstance();
    await _saveTodos(prefs);

    if (item.hasReminder && item.dueDate != null) {
      final reminderTime = item.dueDate!.subtract(Duration(minutes: item.reminderMinutesBefore));
      final reminder = ReminderItem(
        id: 'rem_td_${item.id}',
        title: 'Task Due: ${item.title}',
        body: 'Priority: ${item.priority.label} • ${item.category}',
        scheduledAt: reminderTime,
        type: ReminderType.task,
        relatedId: item.id,
      );
      await addReminder(reminder);
    }
  }

  Future<void> toggleTodo(String id) async {
    final idx = _todos.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final current = _todos[idx];
      final isNowDone = !current.isCompleted;
      _todos[idx] = current.copyWith(
        isCompleted: isNowDone,
        completedAt: isNowDone ? DateTime.now() : null,
      );
      final prefs = await SharedPreferences.getInstance();
      await _saveTodos(prefs);
    }
  }

  Future<void> updateTodo(TodoItem updated) async {
    final idx = _todos.indexWhere((t) => t.id == updated.id);
    if (idx == -1) return;
    _todos[idx] = updated;
    final prefs = await SharedPreferences.getInstance();
    await _saveTodos(prefs);

    // Update reminder if necessary
    await deleteReminderByRelatedId(updated.id);
    if (updated.hasReminder && updated.dueDate != null && !updated.isCompleted) {
      final reminderTime = updated.dueDate!.subtract(Duration(minutes: updated.reminderMinutesBefore));
      final reminder = ReminderItem(
        id: 'rem_td_${updated.id}',
        title: 'Task Due: ${updated.title}',
        body: 'Priority: ${updated.priority.label} • ${updated.category}',
        scheduledAt: reminderTime,
        type: ReminderType.task,
        relatedId: updated.id,
      );
      await addReminder(reminder);
    }
  }

  Future<void> deleteTodo(String id) async {
    _todos.removeWhere((t) => t.id == id);
    final prefs = await SharedPreferences.getInstance();
    await _saveTodos(prefs);
    await deleteReminderByRelatedId(id);
  }

  Future<void> clearCompletedTodos() async {
    _todos.removeWhere((t) => t.isCompleted);
    final prefs = await SharedPreferences.getInstance();
    await _saveTodos(prefs);
  }

  // --- 7. REMINDERS & NOTIFICATIONS ---
  List<ReminderItem> get reminders => List.unmodifiable(_reminders);

  Future<void> addReminder(ReminderItem reminder) async {
    _reminders.removeWhere((r) => r.id == reminder.id);
    _reminders.add(reminder);
    _reminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final prefs = await SharedPreferences.getInstance();
    await _saveReminders(prefs);

    if (reminder.isEnabled) {
      await NotificationService().scheduleReminder(reminder);
    }
  }

  Future<void> toggleReminderEnabled(String id) async {
    final idx = _reminders.indexWhere((r) => r.id == id);
    if (idx != -1) {
      final cur = _reminders[idx];
      final newEnabled = !cur.isEnabled;
      _reminders[idx] = cur.copyWith(isEnabled: newEnabled);
      final prefs = await SharedPreferences.getInstance();
      await _saveReminders(prefs);

      if (newEnabled) {
        await NotificationService().scheduleReminder(_reminders[idx]);
      } else {
        await NotificationService().cancelReminder(cur.id);
      }
    }
  }

  Future<void> deleteReminder(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    final prefs = await SharedPreferences.getInstance();
    await _saveReminders(prefs);
    await NotificationService().cancelReminder(id);
  }

  Future<void> deleteReminderByRelatedId(String relatedId) async {
    final toRemove = _reminders.where((r) => r.relatedId == relatedId).toList();
    for (final r in toRemove) {
      await deleteReminder(r.id);
    }
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

  Future<void> _saveReminders(SharedPreferences prefs) async {
    await prefs.setString(_keyReminders, jsonEncode(_reminders.map((r) => r.toJson()).toList()));
  }
}
