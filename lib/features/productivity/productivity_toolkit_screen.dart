import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';
import 'productivity_models.dart';
import 'productivity_service.dart';

enum ProductivityTab {
  notes('Notes', Icons.note_alt_rounded),
  calendar('Calendar & Events', Icons.calendar_month_rounded),
  subscriptions('Subscriptions', Icons.autorenew_rounded),
  bills('Bill Due Dates', Icons.receipt_long_rounded),
  workHours('Work Hours', Icons.timer_rounded),
  todos('To-Do & Checklists', Icons.checklist_rounded);

  final String label;
  final IconData icon;
  const ProductivityTab(this.label, this.icon);
}

class ProductivityToolkitScreen extends StatefulWidget {
  const ProductivityToolkitScreen({super.key});

  @override
  State<ProductivityToolkitScreen> createState() => _ProductivityToolkitScreenState();
}

class _ProductivityToolkitScreenState extends State<ProductivityToolkitScreen> {
  final ProductivityService _service = ProductivityService();
  ProductivityTab _activeTab = ProductivityTab.notes;
  bool _isLoading = true;

  // 1. Notes State
  String _noteSearchQuery = '';
  String _selectedNoteCategory = 'All';
  final List<String> _noteCategories = ['All', 'Work', 'Personal', 'Ideas', 'Urgent'];

  // 2. Calendar State
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedCalendarDay = DateTime.now();

  // 5. Work Hours Timer State
  Timer? _punchTimer;
  Duration _activeSessionDuration = Duration.zero;

  // 6. To-Do State
  String _selectedTodoCategory = 'All';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _service.init();
    if (mounted) {
      setState(() => _isLoading = false);
      _checkActiveWorkSession();
    }
  }

  void _checkActiveWorkSession() {
    final active = _service.activeWorkSession;
    if (active != null) {
      _startPunchTimer(active.startTime);
    } else {
      _punchTimer?.cancel();
      _activeSessionDuration = Duration.zero;
    }
  }

  void _startPunchTimer(DateTime startTime) {
    _punchTimer?.cancel();
    _punchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _activeSessionDuration = DateTime.now().difference(startTime);
        });
      }
    });
  }

  @override
  void dispose() {
    _punchTimer?.cancel();
    super.dispose();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.catFinance,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Productivity & Organization',
      category: ToolCategory.dateTime,
      toolId: 'productivity_toolkit',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FeatureTabSelector<ProductivityTab>(
                  accentColor: AppColors.catDate,
                  activeTab: _activeTab,
                  onTabSelected: (tab) {
                    PreferencesService().triggerHaptic();
                    setState(() => _activeTab = tab);
                  },
                  tabs: ProductivityTab.values
                      .map((t) => FeatureTabItem(value: t, label: t.label, icon: t.icon))
                      .toList(),
                ),
                const SizedBox(height: 16),
                _buildActiveTab(isDark),
              ],
            ),
    );
  }

  Widget _buildActiveTab(bool isDark) {
    switch (_activeTab) {
      case ProductivityTab.notes:
        return _buildNotesTab(isDark);
      case ProductivityTab.calendar:
        return _buildCalendarTab(isDark);
      case ProductivityTab.subscriptions:
        return _buildSubscriptionsTab(isDark);
      case ProductivityTab.bills:
        return _buildBillsTab(isDark);
      case ProductivityTab.workHours:
        return _buildWorkHoursTab(isDark);
      case ProductivityTab.todos:
        return _buildTodosTab(isDark);
    }
  }

  // ================= 1. NOTES & CATEGORIES =================
  Widget _buildNotesTab(bool isDark) {
    final filteredNotes = _service.searchNotes(_noteSearchQuery, category: _selectedNoteCategory);
    final pinnedCount = _service.notes.where((n) => n.isPinned).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Notes & Idea Pad',
          primaryResult: '${_service.notes.length} Notes Total',
          subtitle: 'Categorize, color-code, pin important items, and search full text',
          accentColor: AppColors.catDate,
          breakdowns: [
            BreakdownItem(label: 'Pinned', value: '$pinnedCount'),
            BreakdownItem(label: 'Category', value: _selectedNoteCategory),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          decoration: InputDecoration(
            hintText: 'Search notes by title or content...',
            prefixIcon: const Icon(Icons.search_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (val) => setState(() => _noteSearchQuery = val),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _noteCategories.map((cat) {
              final isSelected = _selectedNoteCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppColors.catDate.withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _selectedNoteCategory = cat),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          icon: const Icon(Icons.note_add_rounded),
          label: const Text('Create New Note'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catDate,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => _openNoteEditorDialog(null),
        ),
        const SizedBox(height: 16),
        if (filteredNotes.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No notes found.',
                style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredNotes.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final note = filteredNotes[i];
              return Card(
                elevation: 0,
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: note.isPinned ? AppColors.catDate : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    width: note.isPinned ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: Color(note.colorValue), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              note.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Chip(
                            label: Text(note.category, style: const TextStyle(fontSize: 10)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          IconButton(
                            icon: Icon(
                              note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                              size: 20,
                              color: note.isPinned ? AppColors.catDate : Colors.grey,
                            ),
                            onPressed: () async {
                              await _service.togglePinNote(note.id);
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        note.content,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMM d, yyyy • h:mm a').format(note.updatedAt),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                tooltip: 'Copy',
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: '${note.title}\n\n${note.content}'));
                                  _showToast('Note copied to clipboard!');
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit',
                                onPressed: () => _openNoteEditorDialog(note),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                tooltip: 'Delete',
                                onPressed: () async {
                                  await _service.deleteNote(note.id);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _openNoteEditorDialog(NoteItem? existing) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    String category = existing?.category ?? 'Personal';
    int colorVal = existing?.colorValue ?? 0xFF3B82F6;

    final colorOptions = [0xFF3B82F6, 0xFF10B981, 0xFFEF4444, 0xFFF59E0B, 0xFF8B5CF6, 0xFFEC4899];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Edit Note' : 'New Note'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 10),
                TextField(controller: contentCtrl, maxLines: 5, decoration: const InputDecoration(labelText: 'Content')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ['Personal', 'Work', 'Ideas', 'Urgent', 'General']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? 'Personal'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Color: '),
                    ...colorOptions.map((cv) {
                      return GestureDetector(
                        onTap: () => setDialogState(() => colorVal = cv),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Color(cv),
                            shape: BoxShape.circle,
                            border: Border.all(color: colorVal == cv ? Colors.white : Colors.transparent, width: 2),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final content = contentCtrl.text.trim();
                if (title.isNotEmpty) {
                  if (existing != null) {
                    await _service.updateNote(existing.copyWith(
                      title: title,
                      content: content,
                      category: category,
                      colorValue: colorVal,
                      updatedAt: DateTime.now(),
                    ));
                  } else {
                    await _service.addNote(NoteItem(
                      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
                      title: title,
                      content: content,
                      category: category,
                      colorValue: colorVal,
                      updatedAt: DateTime.now(),
                    ));
                  }
                  if (mounted) setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save Note'),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 2. CALENDAR & EVENTS =================
  Widget _buildCalendarTab(bool isDark) {
    final dayEvents = _service.getEventsForDay(_selectedCalendarDay);
    final daysInMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_calendarMonth.year, _calendarMonth.month, 1).weekday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Event & Meeting Schedule',
          primaryResult: '${_service.events.length} Upcoming Events',
          subtitle: 'Day planner, location alerts, and calendar agenda view',
          accentColor: AppColors.catDate,
        ),
        const SizedBox(height: 16),
        // Month navigator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => setState(() {
                _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
              }),
            ),
            Text(
              DateFormat('MMMM yyyy').format(_calendarMonth),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => setState(() {
                _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Weekday header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) {
            return SizedBox(
              width: 38,
              child: Center(
                child: Text(d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Calendar Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (context, index) {
            final dayOffset = index - (firstWeekday - 1);
            if (dayOffset < 0 || dayOffset >= daysInMonth) {
              return const SizedBox();
            }
            final day = dayOffset + 1;
            final date = DateTime(_calendarMonth.year, _calendarMonth.month, day);
            final isSelected = date.year == _selectedCalendarDay.year &&
                date.month == _selectedCalendarDay.month &&
                date.day == _selectedCalendarDay.day;
            final hasEvents = _service.getEventsForDay(date).isNotEmpty;

            return GestureDetector(
              onTap: () => setState(() => _selectedCalendarDay = date),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.catDate
                      : (isDark ? AppColors.darkCard : AppColors.lightCard),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.catDate : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                    if (hasEvents)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : AppColors.catDate,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Agenda for ${DateFormat('MMM d, yyyy').format(_selectedCalendarDay)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catDate,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _openEventDialog(_selectedCalendarDay),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (dayEvents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No events scheduled for this day.',
                style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dayEvents.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final ev = dayEvents[i];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                leading: CircleAvatar(
                  backgroundColor: AppColors.catDate.withValues(alpha: 0.2),
                  child: const Icon(Icons.event_rounded, color: AppColors.catDate),
                ),
                title: Text(ev.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${ev.time} • ${ev.location.isNotEmpty ? ev.location : ev.category}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () async {
                    await _service.deleteEvent(ev.id);
                    setState(() {});
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  void _openEventDialog(DateTime defaultDate) {
    final titleCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: '10:00 AM');
    final locCtrl = TextEditingController();
    String category = 'Meeting';
    PriorityLevel priority = PriorityLevel.medium;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Calendar Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Event Title')),
                const SizedBox(height: 10),
                TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: 'Time (e.g. 10:00 AM)')),
                const SizedBox(height: 10),
                TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Location / Link')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ['Meeting', 'Milestone', 'Work', 'Personal', 'Appointment']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? 'Meeting'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<PriorityLevel>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: PriorityLevel.values
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => priority = v ?? PriorityLevel.medium),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isNotEmpty) {
                  await _service.addEvent(CalendarEventItem(
                    id: 'event_${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    date: defaultDate,
                    time: timeCtrl.text.trim(),
                    location: locCtrl.text.trim(),
                    category: category,
                    priority: priority,
                  ));
                  if (mounted) setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save Event'),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 3. SUBSCRIPTIONS =================
  Widget _buildSubscriptionsTab(bool isDark) {
    final subs = _service.subscriptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Subscription Renewal Monitor',
          primaryResult: '\$${_service.totalMonthlySubscriptionCost.toStringAsFixed(2)} / mo',
          subtitle: 'Annualized: \$${_service.totalAnnualSubscriptionCost.toStringAsFixed(2)} / year',
          accentColor: AppColors.catFinance,
          breakdowns: [
            BreakdownItem(label: 'Active Subs', value: '${subs.where((s) => s.isActive).length}'),
            BreakdownItem(label: 'Total Tracked', value: '${subs.length}'),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_card_rounded),
          label: const Text('Add Recurring Subscription'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catFinance,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _openAddSubscriptionDialog,
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: subs.length,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final s = subs[i];
            final days = s.daysUntilRenewal;

            return Card(
              elevation: 0,
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.catFinance.withValues(alpha: 0.15),
                      child: const Icon(Icons.autorenew_rounded, color: AppColors.catFinance),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 8),
                              Chip(label: Text(s.category, style: const TextStyle(fontSize: 10)), padding: EdgeInsets.zero),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${s.cost.toStringAsFixed(2)} • ${s.billingCycle}',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.catFinance),
                          ),
                          Text(
                            days < 0 ? 'Renewed recently' : 'Renews in $days days (${DateFormat('MMM d').format(s.nextRenewalDate)})',
                            style: TextStyle(fontSize: 12, color: days <= s.alertDaysBefore ? AppColors.warning : Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: s.isActive,
                      activeColor: AppColors.catFinance,
                      onChanged: (_) async {
                        await _service.toggleSubscriptionActive(s.id);
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                      onPressed: () async {
                        await _service.deleteSubscription(s.id);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _openAddSubscriptionDialog() {
    final nameCtrl = TextEditingController();
    final costCtrl = TextEditingController(text: '9.99');
    String cycle = 'Monthly';
    String category = 'Streaming';
    DateTime renewalDate = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Subscription'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Service Name')),
                const SizedBox(height: 10),
                TextField(
                  controller: costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cost (\$)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: cycle,
                  decoration: const InputDecoration(labelText: 'Billing Cycle'),
                  items: ['Monthly', 'Yearly'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => cycle = v ?? 'Monthly'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ['Streaming', 'Software', 'Cloud', 'Gym', 'Gaming', 'Other']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? 'Streaming'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                if (name.isNotEmpty) {
                  await _service.addSubscription(SubscriptionItem(
                    id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    cost: cost,
                    billingCycle: cycle,
                    nextRenewalDate: renewalDate,
                    category: category,
                  ));
                  if (mounted) setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save Subscription'),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 4. BILL DUE DATES =================
  Widget _buildBillsTab(bool isDark) {
    final bills = _service.bills;
    final unpaidTotal = _service.totalUnpaidBillsAmount;
    final overdueCount = _service.overdueBillsCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Bill Due Date Tracker',
          primaryResult: '\$${unpaidTotal.toStringAsFixed(2)} Unpaid',
          subtitle: overdueCount > 0 ? '⚠️ $overdueCount overdue bills requiring attention!' : 'All scheduled bills on track',
          accentColor: overdueCount > 0 ? AppColors.error : AppColors.catFinance,
          breakdowns: [
            BreakdownItem(label: 'Pending', value: '${bills.where((b) => !b.isPaid).length}'),
            BreakdownItem(label: 'Paid', value: '${bills.where((b) => b.isPaid).length}'),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_task_rounded),
          label: const Text('Add Upcoming Bill'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.catFinance,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _openAddBillDialog,
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: bills.length,
          separatorBuilder: (_, index) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final b = bills[i];
            final days = b.daysUntilDue;

            return Card(
              elevation: 0,
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: b.isOverdue ? AppColors.error : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        b.isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: b.isPaid ? AppColors.success : Colors.grey,
                        size: 26,
                      ),
                      onPressed: () async {
                        await _service.toggleBillPaid(b.id);
                        setState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              decoration: b.isPaid ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          Text('${b.payee} • ${b.category}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            b.isPaid
                                ? 'Paid'
                                : (b.isOverdue
                                    ? 'OVERDUE by ${days.abs()} days'
                                    : 'Due in $days days (${DateFormat('MMM d').format(b.dueDate)})'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: b.isPaid ? AppColors.success : (b.isOverdue ? AppColors.error : AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${b.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                      onPressed: () async {
                        await _service.deleteBill(b.id);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _openAddBillDialog() {
    final titleCtrl = TextEditingController();
    final payeeCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '75.00');
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    String category = 'Utilities';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Bill Due Date'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Bill Name')),
                const SizedBox(height: 10),
                TextField(controller: payeeCtrl, decoration: const InputDecoration(labelText: 'Payee / Provider')),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (\$)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ['Utilities', 'Rent', 'Credit Card', 'Internet', 'Phone', 'Insurance', 'Other']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? 'Utilities'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (title.isNotEmpty) {
                  await _service.addBill(BillItem(
                    id: 'bill_${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    payee: payeeCtrl.text.trim(),
                    amount: amount,
                    dueDate: dueDate,
                    category: category,
                  ));
                  if (mounted) setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save Bill'),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 5. WORK HOURS TRACKER =================
  Widget _buildWorkHoursTab(bool isDark) {
    final active = _service.activeWorkSession;
    final totalHours = _service.totalTrackedHours;
    final totalEarnings = _service.totalEarnings;

    final hoursStr = _activeSessionDuration.inHours.toString().padLeft(2, '0');
    final minsStr = (_activeSessionDuration.inMinutes % 60).toString().padLeft(2, '0');
    final secsStr = (_activeSessionDuration.inSeconds % 60).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Work Hours & Timesheet',
          primaryResult: '${totalHours.toStringAsFixed(1)} Hours Total',
          subtitle: 'Gross Earnings: \$${totalEarnings.toStringAsFixed(2)}',
          accentColor: AppColors.catTime,
          breakdowns: [
            BreakdownItem(label: 'Status', value: active != null ? 'Clocked In' : 'Idle'),
            BreakdownItem(label: 'Sessions', value: '${_service.workSessions.length}'),
          ],
        ),
        const SizedBox(height: 16),
        // Live punch clock container
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active != null ? AppColors.success : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: active != null ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                active != null ? 'ACTIVE WORK SESSION' : 'READY TO WORK',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active != null ? AppColors.success : Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$hoursStr:$minsStr:$secsStr',
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(active != null ? Icons.stop_rounded : Icons.play_arrow_rounded),
                      label: Text(active != null ? 'Clock Out' : 'Clock In'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: active != null ? AppColors.error : AppColors.success,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        PreferencesService().triggerHaptic();
                        if (active != null) {
                          await _service.clockOut();
                          _punchTimer?.cancel();
                          setState(() => _activeSessionDuration = Duration.zero);
                        } else {
                          await _service.clockIn();
                          final newActive = _service.activeWorkSession;
                          if (newActive != null) _startPunchTimer(newActive.startTime);
                          setState(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Work Session History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            OutlinedButton.icon(
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('Export Timesheet'),
              onPressed: () {
                final buffer = StringBuffer('WORK TIMESHEET REPORT\n');
                buffer.writeln('Total Hours: ${totalHours.toStringAsFixed(1)} hrs');
                buffer.writeln('Total Earnings: \$${totalEarnings.toStringAsFixed(2)}\n');
                for (final w in _service.workSessions) {
                  buffer.writeln('${DateFormat('yyyy-MM-dd').format(w.startTime)}: ${w.durationHours.toStringAsFixed(1)} hrs - \$${w.earnings.toStringAsFixed(2)} (${w.taskDescription})');
                }
                Clipboard.setData(ClipboardData(text: buffer.toString()));
                _showToast('Timesheet copied to clipboard!');
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _service.workSessions.length,
          separatorBuilder: (_, index) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final w = _service.workSessions[i];
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              leading: const Icon(Icons.history_toggle_off_rounded, color: AppColors.catTime),
              title: Text(w.taskDescription, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${DateFormat('MMM d').format(w.startTime)} • ${w.durationHours.toStringAsFixed(1)} hrs @ \$${w.hourlyRate.round()}/hr',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '\$${w.earnings.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                    onPressed: () async {
                      await _service.deleteWorkSession(w.id);
                      setState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ================= 6. TO-DO & CHECKLISTS =================
  Widget _buildTodosTab(bool isDark) {
    final todos = _service.todos;
    final rate = _service.todoCompletionRate;
    final categories = ['All', 'Development', 'Finance', 'Testing', 'Tasks'];

    final filtered = todos.where((t) {
      if (_selectedTodoCategory == 'All') return true;
      return t.category == _selectedTodoCategory;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'To-Do & Productivity Checklists',
          primaryResult: '${rate.toStringAsFixed(0)}% Completed',
          subtitle: '${todos.where((t) => !t.isCompleted).length} tasks pending',
          accentColor: AppColors.catEveryday,
          breakdowns: [
            BreakdownItem(label: 'Pending', value: '${todos.where((t) => !t.isCompleted).length}'),
            BreakdownItem(label: 'Done', value: '${todos.where((t) => t.isCompleted).length}'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Add Task'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catEveryday,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                ),
                onPressed: _openAddTodoDialog,
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () async {
                await _service.clearCompletedTodos();
                setState(() {});
              },
              child: const Text('Clear Done'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((c) {
              final isSelected = _selectedTodoCategory == c;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c),
                  selected: isSelected,
                  selectedColor: AppColors.catEveryday.withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _selectedTodoCategory = c),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (_, index) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final t = filtered[i];
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              leading: Checkbox(
                value: t.isCompleted,
                activeColor: AppColors.catEveryday,
                onChanged: (_) async {
                  await _service.toggleTodo(t.id);
                  setState(() {});
                },
              ),
              title: Text(
                t.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                  color: t.isCompleted ? Colors.grey : null,
                ),
              ),
              subtitle: Text('${t.category} • Priority: ${t.priority.label}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                onPressed: () async {
                  await _service.deleteTodo(t.id);
                  setState(() {});
                },
              ),
            );
          },
        ),
      ],
    );
  }

  void _openAddTodoDialog() {
    final titleCtrl = TextEditingController();
    String category = 'Tasks';
    PriorityLevel priority = PriorityLevel.medium;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Task Title')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ['Tasks', 'Development', 'Finance', 'Testing', 'Personal']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDialogState(() => category = v ?? 'Tasks'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<PriorityLevel>(
                value: priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: PriorityLevel.values
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                    .toList(),
                onChanged: (v) => setDialogState(() => priority = v ?? PriorityLevel.medium),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isNotEmpty) {
                  await _service.addTodo(TodoItem(
                    id: 'todo_${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    category: category,
                    priority: priority,
                  ));
                  if (mounted) setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Save Task'),
            ),
          ],
        ),
      ),
    );
  }
}
