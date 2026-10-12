
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

/// 1. Notes model
class NoteItem {
  final String id;
  final String title;
  final String content;
  final String category; // 'Personal', 'Work', 'Ideas', 'Urgent', etc.
  final int colorValue; // Color value
  final bool isPinned;
  final DateTime updatedAt;

  NoteItem({
    required this.id,
    required this.title,
    required this.content,
    this.category = 'General',
    this.colorValue = 0xFF3B82F6,
    this.isPinned = false,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'category': category,
    'colorValue': colorValue,
    'isPinned': isPinned,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory NoteItem.fromJson(Map<String, dynamic> json) => NoteItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    content: json['content'] ?? '',
    category: json['category'] ?? 'General',
    colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF3B82F6,
    isPinned: json['isPinned'] ?? false,
    updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
  );

  NoteItem copyWith({
    String? title,
    String? content,
    String? category,
    int? colorValue,
    bool? isPinned,
    DateTime? updatedAt,
  }) {
    return NoteItem(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      colorValue: colorValue ?? this.colorValue,
      isPinned: isPinned ?? this.isPinned,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 2. Calendar Event model
class CalendarEventItem {
  final String id;
  final String title;
  final DateTime date;
  final String time; // e.g. "10:30 AM"
  final String location;
  final String category;
  final PriorityLevel priority;
  final bool isCompleted;

  CalendarEventItem({
    required this.id,
    required this.title,
    required this.date,
    this.time = 'All Day',
    this.location = '',
    this.category = 'Meeting',
    this.priority = PriorityLevel.medium,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date.toIso8601String(),
    'time': time,
    'location': location,
    'category': category,
    'priority': priority.name,
    'isCompleted': isCompleted,
  };

  factory CalendarEventItem.fromJson(Map<String, dynamic> json) => CalendarEventItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    time: json['time'] ?? 'All Day',
    location: json['location'] ?? '',
    category: json['category'] ?? 'Meeting',
    priority: PriorityLevel.fromString(json['priority'] ?? 'medium'),
    isCompleted: json['isCompleted'] ?? false,
  );
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
enum TodoFilter { all, active, completed }

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
  final String category;
  final List<String> subtasks;

  /// Indexes into [subtasks] that are ticked off.
  final List<int> doneSubtasks;

  TodoItem({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.priority = PriorityLevel.medium,
    this.dueDate,
    this.category = 'Tasks',
    this.subtasks = const [],
    this.doneSubtasks = const [],
  });

  bool isSubtaskDone(int index) => doneSubtasks.contains(index);

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
    'category': category,
    'subtasks': subtasks,
    'doneSubtasks': doneSubtasks,
  };

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    final subtasks = (json['subtasks'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[];
    return TodoItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      isCompleted: json['isCompleted'] ?? false,
      priority: PriorityLevel.fromString(json['priority'] ?? 'medium'),
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
      category: json['category'] ?? 'Tasks',
      subtasks: subtasks,
      doneSubtasks: [
        for (final i in (json['doneSubtasks'] as List<dynamic>? ?? const []))
          if (i is int && i >= 0 && i < subtasks.length) i,
      ],
    );
  }

  TodoItem copyWith({
    String? title,
    bool? isCompleted,
    PriorityLevel? priority,
    DateTime? dueDate,
    String? category,
    List<String>? subtasks,
    List<int>? doneSubtasks,
  }) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      category: category ?? this.category,
      subtasks: subtasks ?? this.subtasks,
      doneSubtasks: doneSubtasks ?? this.doneSubtasks,
    );
  }
}
