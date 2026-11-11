
/// Whole calendar days from [from] to [to], ignoring the time of day.
/// Uses UTC dates so a DST change (23h/25h local day) can't shift the count.
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// [date] plus [months], clamping the day to the target month's length
/// (Jan 31 + 1 month = Feb 28/29, not Mar 3).
DateTime _addMonthsClamped(DateTime date, int months) {
  final firstOfTarget = DateTime(date.year, date.month + months, 1);
  final lastDay = DateTime(firstOfTarget.year, firstOfTarget.month + 1, 0).day;
  return DateTime(firstOfTarget.year, firstOfTarget.month, date.day > lastDay ? lastDay : date.day);
}

/// Priority levels for tasks and events
enum PriorityLevel {
  low('Low'),
  medium('Medium'),
  high('High');

  final String label;
  const PriorityLevel(this.label);

  static PriorityLevel fromString(String val) {
    return PriorityLevel.values.firstWhere(
      (p) => p.name.toLowerCase() == val.toLowerCase() || p.label.toLowerCase() == val.toLowerCase(),
      orElse: () => PriorityLevel.medium,
    );
  }
}

/// Checklist entry inside a checklist note
class ChecklistItem {
  final String id;
  final String text;
  final bool isDone;

  ChecklistItem({
    required this.id,
    required this.text,
    this.isDone = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isDone': isDone,
  };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
    id: json['id'] ?? '',
    text: json['text'] ?? '',
    isDone: json['isDone'] ?? false,
  );

  ChecklistItem copyWith({String? text, bool? isDone}) => ChecklistItem(
    id: id,
    text: text ?? this.text,
    isDone: isDone ?? this.isDone,
  );
}

/// 1. Notes model
class NoteItem {
  final String id;
  final String title;
  final String content;
  final String category; // 'Personal', 'Work', 'Ideas', 'Urgent', etc.
  final int colorValue; // Color value
  final bool isPinned;
  final DateTime updatedAt;
  final DateTime createdAt;
  final String folder;
  final List<String> tags;
  final bool isChecklist;
  final List<ChecklistItem> checklist;
  final List<String> imagePaths;
  final List<String> webLinks;

  NoteItem({
    required this.id,
    required this.title,
    required this.content,
    this.category = 'General',
    this.colorValue = 0xFF3B82F6,
    this.isPinned = false,
    required this.updatedAt,
    DateTime? createdAt,
    this.folder = 'General',
    this.tags = const [],
    this.isChecklist = false,
    this.checklist = const [],
    this.imagePaths = const [],
    this.webLinks = const [],
  }) : createdAt = createdAt ?? updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'category': category,
    'colorValue': colorValue,
    'isPinned': isPinned,
    'updatedAt': updatedAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'folder': folder,
    'tags': tags,
    'isChecklist': isChecklist,
    'checklist': checklist.map((c) => c.toJson()).toList(),
    'imagePaths': imagePaths,
    'webLinks': webLinks,
  };

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    final updated = DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now();
    final created = DateTime.tryParse(json['createdAt'] ?? '') ?? updated;
    final tagsList = (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
    final imagesList = (json['imagePaths'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
    final linksList = (json['webLinks'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
    final checklistRaw = (json['checklist'] as List<dynamic>?)?.map((e) {
      if (e is Map<String, dynamic>) {
        return ChecklistItem.fromJson(e);
      }
      return ChecklistItem(id: 'chk_${DateTime.now().microsecondsSinceEpoch}', text: e.toString());
    }).toList() ?? <ChecklistItem>[];

    return NoteItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? 'General',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF3B82F6,
      isPinned: json['isPinned'] ?? false,
      updatedAt: updated,
      createdAt: created,
      folder: json['folder'] ?? 'General',
      tags: tagsList,
      isChecklist: json['isChecklist'] ?? false,
      checklist: checklistRaw,
      imagePaths: imagesList,
      webLinks: linksList,
    );
  }

  NoteItem copyWith({
    String? title,
    String? content,
    String? category,
    int? colorValue,
    bool? isPinned,
    DateTime? updatedAt,
    DateTime? createdAt,
    String? folder,
    List<String>? tags,
    bool? isChecklist,
    List<ChecklistItem>? checklist,
    List<String>? imagePaths,
    List<String>? webLinks,
  }) {
    return NoteItem(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      colorValue: colorValue ?? this.colorValue,
      isPinned: isPinned ?? this.isPinned,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      folder: folder ?? this.folder,
      tags: tags ?? this.tags,
      isChecklist: isChecklist ?? this.isChecklist,
      checklist: checklist ?? this.checklist,
      imagePaths: imagePaths ?? this.imagePaths,
      webLinks: webLinks ?? this.webLinks,
    );
  }

  NoteItem addChecklistItem(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return this;
    final item = ChecklistItem(
      id: 'chk_${DateTime.now().microsecondsSinceEpoch}',
      text: clean,
      isDone: false,
    );
    return copyWith(
      checklist: [...checklist, item],
      updatedAt: DateTime.now(),
    );
  }

  NoteItem toggleChecklistItem(int index) {
    if (index < 0 || index >= checklist.length) return this;
    final updated = List<ChecklistItem>.from(checklist);
    final cur = updated[index];
    updated[index] = cur.copyWith(isDone: !cur.isDone);
    return copyWith(checklist: updated, updatedAt: DateTime.now());
  }

  NoteItem removeChecklistItem(int index) {
    if (index < 0 || index >= checklist.length) return this;
    final updated = List<ChecklistItem>.from(checklist)..removeAt(index);
    return copyWith(checklist: updated, updatedAt: DateTime.now());
  }
}

/// Event recurrence rule
enum EventRecurrence {
  none('None'),
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  yearly('Yearly');

  final String label;
  const EventRecurrence(this.label);

  static EventRecurrence fromString(String? val) {
    if (val == null) return EventRecurrence.none;
    return EventRecurrence.values.firstWhere(
      (r) => r.name.toLowerCase() == val.toLowerCase() || r.label.toLowerCase() == val.toLowerCase(),
      orElse: () => EventRecurrence.none,
    );
  }
}

/// 2. Calendar Event model
class CalendarEventItem {
  final String id;
  final String title;
  final DateTime date;
  final String time; // e.g. "10:30 AM" or "All Day"
  final String endTime; // e.g. "11:30 AM"
  final String location;
  final String category;
  final PriorityLevel priority;
  final bool isCompleted;
  final String description;
  final int colorValue;
  final EventRecurrence recurrence;
  final List<String> linkedNoteIds;
  final bool hasReminder;
  final int reminderMinutesBefore;

  CalendarEventItem({
    required this.id,
    required this.title,
    required this.date,
    this.time = 'All Day',
    this.endTime = '',
    this.location = '',
    this.category = 'Meeting',
    this.priority = PriorityLevel.medium,
    this.isCompleted = false,
    this.description = '',
    this.colorValue = 0xFF3B82F6,
    this.recurrence = EventRecurrence.none,
    this.linkedNoteIds = const [],
    this.hasReminder = false,
    this.reminderMinutesBefore = 0,
  });

  /// Evaluates whether this event (accounting for recurrence) occurs on [targetDate].
  bool occursOnDate(DateTime targetDate) {
    final startDay = DateTime(date.year, date.month, date.day);
    final checkDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
    if (checkDay.isBefore(startDay)) return false;

    switch (recurrence) {
      case EventRecurrence.none:
        return checkDay.year == startDay.year &&
            checkDay.month == startDay.month &&
            checkDay.day == startDay.day;
      case EventRecurrence.daily:
        return true;
      case EventRecurrence.weekly:
        return checkDay.weekday == startDay.weekday;
      case EventRecurrence.monthly:
        final daysInTargetMonth = DateTime(checkDay.year, checkDay.month + 1, 0).day;
        final effectiveDay = startDay.day > daysInTargetMonth ? daysInTargetMonth : startDay.day;
        return checkDay.day == effectiveDay;
      case EventRecurrence.yearly:
        final daysInTargetMonth = DateTime(checkDay.year, checkDay.month + 1, 0).day;
        final effectiveDay = startDay.day > daysInTargetMonth ? daysInTargetMonth : startDay.day;
        return checkDay.month == startDay.month && checkDay.day == effectiveDay;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
    'time': time,
    'endTime': endTime,
    'location': location,
    'category': category,
    'priority': priority.name,
    'isCompleted': isCompleted,
    'description': description,
    'colorValue': colorValue,
    'recurrence': recurrence.name,
    'linkedNoteIds': linkedNoteIds,
    'hasReminder': hasReminder,
    'reminderMinutesBefore': reminderMinutesBefore,
  };

  factory CalendarEventItem.fromJson(Map<String, dynamic> json) {
    final linkedNotes = (json['linkedNoteIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
    return CalendarEventItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      time: json['time'] ?? 'All Day',
      endTime: json['endTime'] ?? '',
      location: json['location'] ?? '',
      category: json['category'] ?? 'Meeting',
      priority: PriorityLevel.fromString(json['priority'] ?? 'medium'),
      isCompleted: json['isCompleted'] ?? false,
      description: json['description'] ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF3B82F6,
      recurrence: EventRecurrence.fromString(json['recurrence']),
      linkedNoteIds: linkedNotes,
      hasReminder: json['hasReminder'] ?? false,
      reminderMinutesBefore: (json['reminderMinutesBefore'] as num?)?.toInt() ?? 0,
    );
  }

  CalendarEventItem copyWith({
    String? title,
    DateTime? date,
    String? time,
    String? endTime,
    String? location,
    String? category,
    PriorityLevel? priority,
    bool? isCompleted,
    String? description,
    int? colorValue,
    EventRecurrence? recurrence,
    List<String>? linkedNoteIds,
    bool? hasReminder,
    int? reminderMinutesBefore,
  }) {
    return CalendarEventItem(
      id: id,
      title: title ?? this.title,
      date: date ?? this.date,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      recurrence: recurrence ?? this.recurrence,
      linkedNoteIds: linkedNoteIds ?? this.linkedNoteIds,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
    );
  }
}

/// 3. Subscription model
class SubscriptionItem {
  final String id;
  final String name;
  final double cost;
  final String billingCycle; // 'Monthly', 'Yearly'
  final DateTime nextRenewalDate;
  final String category; // 'Streaming', 'Software', 'Gym', etc.
  final int alertDaysBefore;
  final bool isActive;

  SubscriptionItem({
    required this.id,
    required this.name,
    required this.cost,
    this.billingCycle = 'Monthly',
    required this.nextRenewalDate,
    this.category = 'Streaming',
    this.alertDaysBefore = 3,
    this.isActive = true,
  });

  double get monthlyNormalizedCost {
    if (billingCycle == 'Yearly') return cost / 12.0;
    return cost;
  }

  /// A recurring subscription renews again once its stored date has passed, so
  /// roll the date forward by whole billing cycles until it is today or later.
  DateTime nextRenewalFrom(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final step = billingCycle == 'Yearly' ? 12 : 1;
    var target = DateTime(nextRenewalDate.year, nextRenewalDate.month, nextRenewalDate.day);
    for (var cycles = step; target.isBefore(today); cycles += step) {
      target = _addMonthsClamped(nextRenewalDate, cycles);
    }
    return target;
  }

  DateTime get upcomingRenewalDate => nextRenewalFrom(DateTime.now());

  int get daysUntilRenewal => calendarDaysBetween(DateTime.now(), upcomingRenewalDate);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cost': cost,
    'billingCycle': billingCycle,
    'nextRenewalDate': nextRenewalDate.toIso8601String(),
    'category': category,
    'alertDaysBefore': alertDaysBefore,
    'isActive': isActive,
  };

  factory SubscriptionItem.fromJson(Map<String, dynamic> json) => SubscriptionItem(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
    billingCycle: json['billingCycle'] ?? 'Monthly',
    nextRenewalDate: DateTime.tryParse(json['nextRenewalDate'] ?? '') ?? DateTime.now(),
    category: json['category'] ?? 'Streaming',
    alertDaysBefore: (json['alertDaysBefore'] as num?)?.toInt() ?? 3,
    isActive: json['isActive'] ?? true,
  );
}

/// 4. Bill Due Date model
class BillItem {
  final String id;
  final String title;
  final String payee;
  final double amount;
  final DateTime dueDate;
  final bool isPaid;
  final String category; // 'Utilities', 'Rent', 'Credit Card', 'Phone'

  BillItem({
    required this.id,
    required this.title,
    required this.payee,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
    this.category = 'Utilities',
  });

  int get daysUntilDue => calendarDaysBetween(DateTime.now(), dueDate);

  bool get isOverdue => !isPaid && daysUntilDue < 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'payee': payee,
    'amount': amount,
    'dueDate': dueDate.toIso8601String(),
    'isPaid': isPaid,
    'category': category,
  };

  factory BillItem.fromJson(Map<String, dynamic> json) => BillItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    payee: json['payee'] ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    dueDate: DateTime.tryParse(json['dueDate'] ?? '') ?? DateTime.now(),
    isPaid: json['isPaid'] ?? false,
    category: json['category'] ?? 'Utilities',
  );
}

/// 5. Work Hours Tracker model
class WorkSessionItem {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final int breakMinutes;
  final double hourlyRate;
  final String taskDescription;

  WorkSessionItem({
    required this.id,
    required this.startTime,
    this.endTime,
    this.breakMinutes = 0,
    this.hourlyRate = 25.0,
    this.taskDescription = 'General Work',
  });

  double get durationHours {
    final finish = endTime ?? DateTime.now();
    final diffMinutes = finish.difference(startTime).inMinutes - breakMinutes;
    return (diffMinutes > 0 ? diffMinutes : 0) / 60.0;
  }

  double get earnings => durationHours * hourlyRate;

  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'breakMinutes': breakMinutes,
    'hourlyRate': hourlyRate,
    'taskDescription': taskDescription,
  };

  factory WorkSessionItem.fromJson(Map<String, dynamic> json) => WorkSessionItem(
    id: json['id'] ?? '',
    startTime: DateTime.tryParse(json['startTime'] ?? '') ?? DateTime.now(),
    endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime']) : null,
    breakMinutes: (json['breakMinutes'] as num?)?.toInt() ?? 0,
    hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 25.0,
    taskDescription: json['taskDescription'] ?? 'General Work',
  );
}

/// Which tasks the To-Do tab shows.
enum TodoFilter { all, active, completed, overdue, today }

/// Applies the category chip ('All' = every category) and the status tab.
List<TodoItem> filterTodos(
  List<TodoItem> todos, {
  String category = 'All',
  TodoFilter status = TodoFilter.all,
}) {
  return todos.where((t) {
    if (category != 'All' && t.category != category) return false;
    switch (status) {
      case TodoFilter.all:
        return true;
      case TodoFilter.active:
        return !t.isCompleted;
      case TodoFilter.completed:
        return t.isCompleted;
      case TodoFilter.overdue:
        return t.isOverdue;
      case TodoFilter.today:
        return t.isDueToday;
    }
  }).toList();
}

/// 6. To-Do & Checklist Item model
class TodoItem {
  final String id;
  final String title;
  final bool isCompleted;
  final PriorityLevel priority;
  final DateTime? dueDate;
  final String dueTime;
  final String category;
  final String description;
  final List<String> subtasks;
  final List<int> doneSubtasks;
  final DateTime? completedAt;
  final bool hasReminder;
  final int reminderMinutesBefore;

  TodoItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.priority = PriorityLevel.medium,
    this.dueDate,
    this.dueTime = '',
    this.category = 'Tasks',
    this.description = '',
    this.subtasks = const [],
    this.doneSubtasks = const [],
    this.completedAt,
    this.hasReminder = false,
    this.reminderMinutesBefore = 0,
  });

  bool isSubtaskDone(int index) => doneSubtasks.contains(index);

  bool get isOverdue => !isCompleted && dueDate != null && calendarDaysBetween(DateTime.now(), dueDate!) < 0;

  bool get isDueToday => dueDate != null && calendarDaysBetween(DateTime.now(), dueDate!) == 0;

  bool get isUpcoming => dueDate != null && calendarDaysBetween(DateTime.now(), dueDate!) > 0;

  TodoItem addSubtask(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return this;
    return copyWith(subtasks: [...subtasks, clean]);
  }

  TodoItem toggleSubtask(int index) {
    if (index < 0 || index >= subtasks.length) return this;
    final done = isSubtaskDone(index) ? doneSubtasks.where((i) => i != index).toList() : [...doneSubtasks, index];
    return copyWith(doneSubtasks: done);
  }

  /// Removes a subtask and shifts the done markers of the ones after it.
  TodoItem removeSubtask(int index) {
    if (index < 0 || index >= subtasks.length) return this;
    return copyWith(
      subtasks: [...subtasks]..removeAt(index),
      doneSubtasks: [
        for (final i in doneSubtasks)
          if (i != index) i > index ? i - 1 : i,
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    'priority': priority.name,
    'dueDate': dueDate?.toIso8601String(),
    'dueTime': dueTime,
    'category': category,
    'description': description,
    'subtasks': subtasks,
    'doneSubtasks': doneSubtasks,
    'completedAt': completedAt?.toIso8601String(),
    'hasReminder': hasReminder,
    'reminderMinutesBefore': reminderMinutesBefore,
  };

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    final subtasks = (json['subtasks'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
    return TodoItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      isCompleted: json['isCompleted'] ?? false,
      priority: PriorityLevel.fromString(json['priority'] ?? 'medium'),
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
      dueTime: json['dueTime'] ?? '',
      category: json['category'] ?? 'Tasks',
      description: json['description'] ?? '',
      subtasks: subtasks,
      doneSubtasks: [
        for (final i in (json['doneSubtasks'] as List<dynamic>? ?? const []))
          if (i is int && i >= 0 && i < subtasks.length) i,
      ],
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt']) : null,
      hasReminder: json['hasReminder'] ?? false,
      reminderMinutesBefore: (json['reminderMinutesBefore'] as num?)?.toInt() ?? 0,
    );
  }

  TodoItem copyWith({
    String? title,
    bool? isCompleted,
    PriorityLevel? priority,
    DateTime? dueDate,
    String? dueTime,
    String? category,
    String? description,
    List<String>? subtasks,
    List<int>? doneSubtasks,
    DateTime? completedAt,
    bool? hasReminder,
    int? reminderMinutesBefore,
  }) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      category: category ?? this.category,
      description: description ?? this.description,
      subtasks: subtasks ?? this.subtasks,
      doneSubtasks: doneSubtasks ?? this.doneSubtasks,
      completedAt: completedAt ?? this.completedAt,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
    );
  }
}

/// 7. Reminders and Scheduled Notifications model
enum ReminderType {
  oneTime('One-Time'),
  recurringDaily('Daily'),
  recurringWeekly('Weekly'),
  recurringMonthly('Monthly'),
  recurringYearly('Yearly'),
  birthday('Birthday'),
  event('Event'),
  task('Task Deadline');

  final String label;
  const ReminderType(this.label);

  static ReminderType fromString(String? val) {
    if (val == null) return ReminderType.oneTime;
    return ReminderType.values.firstWhere(
      (r) => r.name.toLowerCase() == val.toLowerCase() || r.label.toLowerCase() == val.toLowerCase(),
      orElse: () => ReminderType.oneTime,
    );
  }
}

class ReminderItem {
  final String id;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final ReminderType type;
  final bool isEnabled;
  final String? relatedId; // eventId, todoId, noteId

  ReminderItem({
    required this.id,
    required this.title,
    this.body = '',
    required this.scheduledAt,
    this.type = ReminderType.oneTime,
    this.isEnabled = true,
    this.relatedId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'scheduledAt': scheduledAt.toIso8601String(),
    'type': type.name,
    'isEnabled': isEnabled,
    'relatedId': relatedId,
  };

  factory ReminderItem.fromJson(Map<String, dynamic> json) => ReminderItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    body: json['body'] ?? '',
    scheduledAt: DateTime.tryParse(json['scheduledAt'] ?? '') ?? DateTime.now(),
    type: ReminderType.fromString(json['type']),
    isEnabled: json['isEnabled'] ?? true,
    relatedId: json['relatedId'],
  );

  ReminderItem copyWith({
    String? title,
    String? body,
    DateTime? scheduledAt,
    ReminderType? type,
    bool? isEnabled,
    String? relatedId,
  }) {
    return ReminderItem(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      type: type ?? this.type,
      isEnabled: isEnabled ?? this.isEnabled,
      relatedId: relatedId ?? this.relatedId,
    );
  }
}
