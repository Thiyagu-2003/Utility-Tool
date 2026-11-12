import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/feature_tab_selector.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';
import 'productivity_models.dart';
import 'productivity_pdf.dart';
import 'productivity_service.dart';

enum ProductivityTab {
  dashboard('Dashboard', Icons.dashboard_rounded),
  notes('Notes', Icons.note_alt_rounded),
  calendar('Calendar & Events', Icons.calendar_month_rounded),
  todos('To-Do & Checklists', Icons.checklist_rounded),
  reminders('Reminders', Icons.notifications_active_rounded),
  subscriptions('Subscriptions', Icons.autorenew_rounded),
  bills('Bill Due Dates', Icons.receipt_long_rounded),
  workHours('Work Hours', Icons.timer_rounded);

  final String label;
  final IconData icon;
  const ProductivityTab(this.label, this.icon);
}

enum CalendarViewType { month, week, day }

class ProductivityToolkitScreen extends StatefulWidget {
  final ProductivityTab initialTab;

  const ProductivityToolkitScreen({
    super.key,
    this.initialTab = ProductivityTab.dashboard,
  });

  @override
  State<ProductivityToolkitScreen> createState() => _ProductivityToolkitScreenState();
}

class _ProductivityToolkitScreenState extends State<ProductivityToolkitScreen> {
  final ProductivityService _service = ProductivityService();
  final NotificationService _notificationService = NotificationService();
  late ProductivityTab _activeTab;
  bool _isLoading = true;

  // 1. Notes State
  String _noteSearchQuery = '';
  String _selectedNoteCategory = 'All';
  String _selectedNoteFolder = 'All';
  String _selectedNoteTag = 'All';
  final List<String> _noteCategories = ['All', 'General', 'Work', 'Personal', 'Ideas', 'Urgent', 'Projects'];

  // 2. Calendar State
  CalendarViewType _calendarView = CalendarViewType.month;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedCalendarDay = DateTime.now();

  // 4. Tasks State
  String _selectedTodoCategory = 'All';
  TodoFilter _todoFilter = TodoFilter.all;

  // 5. Work Hours Timer State
  Timer? _punchTimer;
  Duration _activeSessionDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _initData();
  }

  Future<void> _initData() async {
    await _service.init();
    await _notificationService.init();
    if (mounted) {
      setState(() => _isLoading = false);
      _checkActiveWorkSession();
    }
  }

  @override
  void dispose() {
    _punchTimer?.cancel();
    super.dispose();
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
    _activeSessionDuration = DateTime.now().difference(startTime);
    _punchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _activeSessionDuration = DateTime.now().difference(startTime);
        });
      }
    });
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _printPdf(String jobName, Future<Uint8List> Function() layout) async {
    try {
      await Printing.layoutPdf(name: jobName, onLayout: (_) => layout());
    } catch (e) {
      _showToast('Could not open print preview: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabs = ProductivityTab.values.map((tab) {
      return FeatureTabItem<ProductivityTab>(
        value: tab,
        label: tab.label,
        icon: tab.icon,
      );
    }).toList();

    return ToolScaffold(
      title: 'Personal Planner & Suite',
      category: ToolCategory.productivity,
      toolId: 'productivity_toolkit',
      actions: [
        if (_activeTab == ProductivityTab.notes)
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print / Save Notes as PDF',
            onPressed: _service.notes.isEmpty
                ? null
                : () => _printPdf('Notes', () => buildNotesPdf(_service.notes)),
          ),
        if (_activeTab == ProductivityTab.calendar)
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Print / Save Agenda as PDF',
            onPressed: () => _printPdf(
              'Agenda',
              () => buildAgendaPdf(
                _selectedCalendarDay,
                _service.getEventsForDay(_selectedCalendarDay),
              ),
            ),
          ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FeatureTabSelector<ProductivityTab>(
                    tabs: tabs,
                    activeTab: _activeTab,
                    accentColor: AppColors.catDate,
                    onTabSelected: (tab) {
                      PreferencesService().triggerHaptic();
                      setState(() => _activeTab = tab);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildActiveTab(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildActiveTab(bool isDark) {
    switch (_activeTab) {
      case ProductivityTab.dashboard:
        return _buildDashboardTab(isDark);
      case ProductivityTab.notes:
        return _buildNotesTab(isDark);
      case ProductivityTab.calendar:
        return _buildCalendarTab(isDark);
      case ProductivityTab.todos:
        return _buildTodosTab(isDark);
      case ProductivityTab.reminders:
        return _buildRemindersTab(isDark);
      case ProductivityTab.subscriptions:
        return _buildSubscriptionsTab(isDark);
      case ProductivityTab.bills:
        return _buildBillsTab(isDark);
      case ProductivityTab.workHours:
        return _buildWorkHoursTab(isDark);
    }
  }

  // ================= 0. DASHBOARD =================
  Widget _buildDashboardTab(bool isDark) {
    final today = DateTime.now();
    final todayAgenda = _service.todayAgenda;
    final overdueTodos = _service.overdueTodos;
    final pendingTodos = _service.pendingTodos;
    final pinnedNotes = _service.pinnedNotes;
    final recentNotes = _service.recentNotes.take(3).toList();
    final upcomingEvents = _service.getUpcomingEvents(days: 7);
    final completionRate = _service.todoCompletionRate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Greeting & Current Date Card
        ResultCard(
          title: 'Daily Planner Dashboard',
          primaryResult: DateFormat('EEEE, MMM d, yyyy').format(today),
          subtitle: 'Your offline personal organization system',
          accentColor: AppColors.catDate,
          breakdowns: [
            BreakdownItem(label: 'Today Events', value: '${todayAgenda.length}'),
            BreakdownItem(label: 'Pending Tasks', value: '${pendingTodos.length}'),
            BreakdownItem(label: 'Overdue', value: '${overdueTodos.length}'),
            BreakdownItem(label: 'Task Progress', value: '${completionRate.toStringAsFixed(0)}%'),
          ],
        ),
        const SizedBox(height: 14),

        // Quick-Add Buttons Row
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.note_add_rounded,
                label: 'Note',
                color: AppColors.catDate,
                onTap: () => _openNoteEditorDialog(null),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.add_task_rounded,
                label: 'Task',
                color: AppColors.catEveryday,
                onTap: _openAddTodoDialog,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.event_available_rounded,
                label: 'Event',
                color: AppColors.catFinance,
                onTap: () => _openEventDialog(DateTime.now()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickActionButton(
                icon: Icons.alarm_add_rounded,
                label: 'Reminder',
                color: AppColors.catHealth,
                onTap: _openAddReminderDialog,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Overdue Tasks Warning Banner (if any)
        if (overdueTodos.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '${overdueTodos.length} Overdue Task${overdueTodos.length > 1 ? "s" : ""} Require Attention',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...overdueTodos.take(3).map((task) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Checkbox(
                            value: task.isCompleted,
                            activeColor: AppColors.error,
                            visualDensity: VisualDensity.compact,
                            onChanged: (_) async {
                              await _service.toggleTodo(task.id);
                              if (mounted) setState(() {});
                            },
                          ),
                          Expanded(
                            child: Text(
                              task.title,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          Text(
                            task.dueDate != null
                                ? DateFormat('MMM d').format(task.dueDate!)
                                : 'Overdue',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('View All Overdue Tasks'),
                    onPressed: () {
                      setState(() {
                        _activeTab = ProductivityTab.todos;
                        _todoFilter = TodoFilter.overdue;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Today's Agenda Section
        _buildSectionHeader(
          title: "Today's Agenda",
          icon: Icons.calendar_today_rounded,
          count: todayAgenda.length,
          actionLabel: 'Full Calendar',
          onAction: () => setState(() => _activeTab = ProductivityTab.calendar),
        ),
        const SizedBox(height: 8),
        if (todayAgenda.isEmpty)
          _buildEmptyPlaceholder(
            message: 'No events scheduled for today. Enjoy your day or tap + Event to plan ahead.',
            isDark: isDark,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: todayAgenda.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final ev = todayAgenda[i];
              return _buildAgendaItemTile(ev, isDark);
            },
          ),
        const SizedBox(height: 22),

        // Pending Tasks Section
        _buildSectionHeader(
          title: 'Pending Tasks',
          icon: Icons.checklist_rounded,
          count: pendingTodos.length,
          actionLabel: 'All Tasks',
          onAction: () => setState(() => _activeTab = ProductivityTab.todos),
        ),
        const SizedBox(height: 8),
        if (pendingTodos.isEmpty)
          _buildEmptyPlaceholder(
            message: 'All tasks completed! Great work.',
            isDark: isDark,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingTodos.take(4).length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final task = pendingTodos[i];
              return Card(
                elevation: 0,
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: ListTile(
                  dense: true,
                  leading: Checkbox(
                    value: task.isCompleted,
                    activeColor: AppColors.catEveryday,
                    onChanged: (_) async {
                      await _service.toggleTodo(task.id);
                      if (mounted) setState(() {});
                    },
                  ),
                  title: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${task.category} • Priority: ${task.priority.label}'
                    '${task.dueDate != null ? " • Due ${DateFormat('MMM d').format(task.dueDate!)}" : ""}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(task.priority).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.priority.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getPriorityColor(task.priority),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 22),

        // Upcoming Events Preview
        if (upcomingEvents.isNotEmpty) ...[
          _buildSectionHeader(
            title: 'Upcoming Events (Next 7 Days)',
            icon: Icons.upcoming_rounded,
            count: upcomingEvents.length,
            actionLabel: 'Calendar',
            onAction: () => setState(() => _activeTab = ProductivityTab.calendar),
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: upcomingEvents.take(3).length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _buildAgendaItemTile(upcomingEvents[i], isDark),
          ),
          const SizedBox(height: 22),
        ],

        // Pinned & Recent Notes Section
        _buildSectionHeader(
          title: 'Pinned & Recent Notes',
          icon: Icons.push_pin_rounded,
          count: pinnedNotes.length,
          actionLabel: 'All Notes',
          onAction: () => setState(() => _activeTab = ProductivityTab.notes),
        ),
        const SizedBox(height: 8),
        if (pinnedNotes.isEmpty && recentNotes.isEmpty)
          _buildEmptyPlaceholder(
            message: 'No notes yet. Tap + Note to create your first note or checklist.',
            isDark: isDark,
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...pinnedNotes.map((n) => _buildDashboardNoteCard(n, isDark, isPinned: true)),
                ...recentNotes.where((n) => !n.isPinned).map((n) => _buildDashboardNoteCard(n, isDark)),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required int count,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.catDate),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.catDate.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.catDate,
                  ),
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(actionLabel, style: const TextStyle(fontSize: 12)),
              const Icon(Icons.chevron_right_rounded, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPlaceholder({required String message, required bool isDark}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildAgendaItemTile(CalendarEventItem ev, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(ev.colorValue).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.event_note_rounded, color: Color(ev.colorValue), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ev.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    if (ev.recurrence != EventRecurrence.none)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: AppColors.catDate.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ev.recurrence.label,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.catDate),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${ev.time}${ev.endTime.isNotEmpty ? " - ${ev.endTime}" : ""} • ${ev.category}'
                  '${ev.location.isNotEmpty ? " • ${ev.location}" : ""}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                if (ev.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    ev.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
                if (ev.linkedNoteIds.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: ev.linkedNoteIds.map((noteId) {
                      final linkedNote = _service.notes.cast<NoteItem?>().firstWhere(
                            (n) => n?.id == noteId,
                            orElse: () => null,
                          );
                      if (linkedNote == null) return const SizedBox();
                      return ActionChip(
                        avatar: const Icon(Icons.link_rounded, size: 14),
                        label: Text(
                          linkedNote.title,
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: () => _openNoteEditorDialog(linkedNote),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardNoteCard(NoteItem note, bool isDark, {bool isPinned = false}) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPinned ? AppColors.catDate : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isPinned ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _openNoteEditorDialog(note),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: Color(note.colorValue), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                if (isPinned)
                  const Icon(Icons.push_pin_rounded, size: 14, color: AppColors.catDate),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              note.isChecklist && note.checklist.isNotEmpty
                  ? '${note.checklist.where((c) => c.isDone).length}/${note.checklist.length} checklist items'
                  : note.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  note.folder,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  DateFormat('MMM d').format(note.updatedAt),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= 1. NOTES & CATEGORIES =================
  Widget _buildNotesTab(bool isDark) {
    final filteredNotes = _service.searchNotes(
      _noteSearchQuery,
      category: _selectedNoteCategory,
      folder: _selectedNoteFolder,
      tag: _selectedNoteTag,
    );
    final pinnedCount = _service.notes.where((n) => n.isPinned).length;
    final folders = ['All', ..._service.noteFolders];
    final tags = ['All', ..._service.noteTags];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Notes & Idea Pad',
          primaryResult: '${_service.notes.length} Notes Total',
          subtitle: 'Folders, tags, checklist notes, image attachments, and markdown formatting',
          accentColor: AppColors.catDate,
          breakdowns: [
            BreakdownItem(label: 'Pinned', value: '$pinnedCount'),
            BreakdownItem(label: 'Folder', value: _selectedNoteFolder),
            BreakdownItem(label: 'Category', value: _selectedNoteCategory),
          ],
        ),
        const SizedBox(height: 14),

        // Search Bar
        TextField(
          decoration: InputDecoration(
            hintText: 'Search title, content, checklist or #tags...',
            prefixIcon: const Icon(Icons.search_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (val) => setState(() => _noteSearchQuery = val),
        ),
        const SizedBox(height: 12),

        // Folders Filter Bar + Add Folder Button
        Row(
          children: [
            const Icon(Icons.folder_open_rounded, size: 18, color: AppColors.catDate),
            const SizedBox(width: 6),
            const Text('Folder: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...folders.map((f) {
                      final isSelected = _selectedNoteFolder == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: isSelected,
                          selectedColor: AppColors.catDate.withValues(alpha: 0.25),
                          onSelected: (_) => setState(() => _selectedNoteFolder = f),
                        ),
                      );
                    }),
                    IconButton(
                      icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                      tooltip: 'New Folder',
                      onPressed: _openNewFolderDialog,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Categories Filter Bar
        Row(
          children: [
            const Icon(Icons.label_outline_rounded, size: 18, color: AppColors.catDate),
            const SizedBox(width: 6),
            const Text('Category: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _noteCategories.map((cat) {
                    final isSelected = _selectedNoteCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
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
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Tags Filter Bar (if tags exist)
        if (tags.length > 1) ...[
          Row(
            children: [
              const Icon(Icons.tag_rounded, size: 18, color: AppColors.catDate),
              const SizedBox(width: 6),
              const Text('Tag: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: tags.map((t) {
                      final isSelected = _selectedNoteTag == t;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(t == 'All' ? 'All' : '#$t'),
                          selected: isSelected,
                          selectedColor: AppColors.catDate.withValues(alpha: 0.25),
                          onSelected: (_) => setState(() => _selectedNoteTag = t),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),

        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.note_add_rounded),
                label: const Text('New Note'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catDate,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _openNoteEditorDialog(null),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.checklist_rounded),
                label: const Text('Checklist Note'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _openNoteEditorDialog(null, startAsChecklist: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Notes List
        if (filteredNotes.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No notes found.',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredNotes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final note = filteredNotes[i];
              return _buildNoteCard(note, isDark);
            },
          ),
      ],
    );
  }

  Widget _buildNoteCard(NoteItem note, bool isDark) {
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
            // Top Row: Color circle, Title, Folder, Category, Pin
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    note.folder,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 4),
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
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Note Content or Checklist Preview
            if (note.isChecklist && note.checklist.isNotEmpty) ...[
              Column(
                children: [
                  for (var idx = 0; idx < note.checklist.length; idx++)
                    Row(
                      children: [
                        Checkbox(
                          value: note.checklist[idx].isDone,
                          visualDensity: VisualDensity.compact,
                          activeColor: AppColors.catDate,
                          onChanged: (_) async {
                            final updated = note.toggleChecklistItem(idx);
                            await _service.updateNote(updated);
                            if (mounted) setState(() {});
                          },
                        ),
                        Expanded(
                          child: Text(
                            note.checklist[idx].text,
                            style: TextStyle(
                              fontSize: 13,
                              decoration: note.checklist[idx].isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: note.checklist[idx].isDone ? Colors.grey : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ] else if (note.content.isNotEmpty) ...[
              MarkdownBody(
                data: note.content,
                selectable: false,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],

            // Image Thumbnails (if attached)
            if (note.imagePaths.isNotEmpty) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: note.imagePaths.map((path) {
                    final file = File(path);
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: file.existsSync()
                          ? Image.file(file, fit: BoxFit.cover)
                          : const Icon(Icons.image_not_supported_rounded, size: 24, color: Colors.grey),
                    );
                  }).toList(),
                ),
              ),
            ],

            // Web Links Chips (if attached)
            if (note.webLinks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: note.webLinks.map((url) {
                  return InputChip(
                    avatar: const Icon(Icons.link_rounded, size: 14),
                    label: Text(url, style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: url));
                      _showToast('Link copied to clipboard!');
                    },
                  );
                }).toList(),
              ),
            ],

            // Tags Chips
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: note.tags.map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.catDate.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#$t',
                      style: const TextStyle(fontSize: 10, color: AppColors.catDate, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),

            // Bottom Footer: Created & Modified timestamps + Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Created: ${DateFormat("MMM d, yyyy").format(note.createdAt)} • Modified: ${DateFormat("MMM d, h:mm a").format(note.updatedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy Note',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: '${note.title}\n\n${note.content}'));
                        _showToast('Note copied to clipboard!');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Note',
                      onPressed: () => _openNoteEditorDialog(note),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                      tooltip: 'Delete Note',
                      onPressed: () async {
                        await _service.deleteNote(note.id);
                        if (mounted) setState(() {});
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
  }

  void _openNewFolderDialog() {
    final folderCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: folderCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder Name', hintText: 'e.g. Travel, Recipes'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = folderCtrl.text.trim();
              if (name.isNotEmpty) {
                await _service.addFolder(name);
                if (mounted) {
                  setState(() => _selectedNoteFolder = name);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _openNoteEditorDialog(NoteItem? existing, {bool startAsChecklist = false}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final contentCtrl = TextEditingController(text: existing?.content ?? '');
    final tagCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    final checklistInputCtrl = TextEditingController();

    String folder = existing?.folder ?? 'General';
    String category = existing?.category ?? 'Personal';
    int colorVal = existing?.colorValue ?? 0xFF3B82F6;
    bool isChecklist = existing?.isChecklist ?? startAsChecklist;
    List<ChecklistItem> checklist = List.from(existing?.checklist ?? []);
    List<String> tags = List.from(existing?.tags ?? []);
    List<String> images = List.from(existing?.imagePaths ?? []);
    List<String> links = List.from(existing?.webLinks ?? []);
    bool isPreview = false;
    Timer? autoSaveTimer;

    final colorOptions = [
      0xFF3B82F6, // Blue
      0xFF10B981, // Emerald
      0xFFEF4444, // Red
      0xFFF59E0B, // Amber
      0xFF8B5CF6, // Purple
      0xFFEC4899, // Pink
      0xFF06B6D4, // Cyan
      0xFF64748B, // Slate
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Debounced auto-save function
          void triggerAutoSave() {
            autoSaveTimer?.cancel();
            autoSaveTimer = Timer(const Duration(milliseconds: 700), () async {
              final title = titleCtrl.text.trim();
              if (title.isNotEmpty && existing != null) {
                await _service.updateNote(existing.copyWith(
                  title: title,
                  content: contentCtrl.text,
                  folder: folder,
                  category: category,
                  colorValue: colorVal,
                  isChecklist: isChecklist,
                  checklist: checklist,
                  tags: tags,
                  imagePaths: images,
                  webLinks: links,
                  updatedAt: DateTime.now(),
                ));
              }
            });
          }

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(existing != null ? 'Edit Note' : 'New Note'),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isChecklist ? Icons.checklist_rounded : Icons.text_snippet_outlined,
                        color: AppColors.catDate,
                      ),
                      tooltip: isChecklist ? 'Switch to Markdown' : 'Switch to Checklist',
                      onPressed: () {
                        setDialogState(() => isChecklist = !isChecklist);
                        triggerAutoSave();
                      },
                    ),
                    if (!isChecklist)
                      IconButton(
                        icon: Icon(isPreview ? Icons.edit_note_rounded : Icons.visibility_rounded),
                        tooltip: isPreview ? 'Edit Mode' : 'Markdown Preview',
                        onPressed: () => setDialogState(() => isPreview = !isPreview),
                      ),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Title', hintText: 'Note Title'),
                      onChanged: (_) => triggerAutoSave(),
                    ),
                    const SizedBox(height: 10),

                    // Content Area (Checklist or Markdown)
                    if (isChecklist) ...[
                      const Text('Checklist Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: checklistInputCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Add an item...',
                                isDense: true,
                              ),
                              onSubmitted: (val) {
                                if (val.trim().isNotEmpty) {
                                  setDialogState(() {
                                    checklist.add(ChecklistItem(
                                      id: 'chk_${DateTime.now().microsecondsSinceEpoch}',
                                      text: val.trim(),
                                    ));
                                    checklistInputCtrl.clear();
                                  });
                                  triggerAutoSave();
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.catDate),
                            onPressed: () {
                              if (checklistInputCtrl.text.trim().isNotEmpty) {
                                setDialogState(() {
                                  checklist.add(ChecklistItem(
                                    id: 'chk_${DateTime.now().microsecondsSinceEpoch}',
                                    text: checklistInputCtrl.text.trim(),
                                  ));
                                  checklistInputCtrl.clear();
                                });
                                triggerAutoSave();
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...checklist.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return Row(
                          children: [
                            Checkbox(
                              value: item.isDone,
                              activeColor: AppColors.catDate,
                              visualDensity: VisualDensity.compact,
                              onChanged: (val) {
                                setDialogState(() {
                                  checklist[idx] = item.copyWith(isDone: val ?? false);
                                });
                                triggerAutoSave();
                              },
                            ),
                            Expanded(
                              child: Text(
                                item.text,
                                style: TextStyle(
                                  decoration: item.isDone ? TextDecoration.lineThrough : null,
                                  color: item.isDone ? Colors.grey : null,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                              onPressed: () {
                                setDialogState(() => checklist.removeAt(idx));
                                triggerAutoSave();
                              },
                            ),
                          ],
                        );
                      }),
                    ] else if (isPreview) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: contentCtrl.text.trim().isEmpty
                            ? const Text('Nothing to preview yet.', style: TextStyle(color: Colors.grey))
                            : MarkdownBody(data: contentCtrl.text),
                      ),
                    ] else ...[
                      TextField(
                        controller: contentCtrl,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Content (Markdown Supported: **bold**, *italic*, # header, etc.)',
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) => triggerAutoSave(),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Folder & Category Selectors
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _service.noteFolders.contains(folder) ? folder : 'General',
                            decoration: const InputDecoration(labelText: 'Folder', isDense: true),
                            items: _service.noteFolders
                                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                .toList(),
                            onChanged: (v) {
                              setDialogState(() => folder = v ?? 'General');
                              triggerAutoSave();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: category,
                            decoration: const InputDecoration(labelText: 'Category', isDense: true),
                            items: ['Personal', 'Work', 'Ideas', 'Urgent', 'General', 'Projects']
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) {
                              setDialogState(() => category = v ?? 'Personal');
                              triggerAutoSave();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Tags Input & Chips
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: tagCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Add Tag (e.g. urgent, travel)',
                              isDense: true,
                            ),
                            onSubmitted: (val) {
                              final clean = val.trim().replaceAll('#', '');
                              if (clean.isNotEmpty && !tags.contains(clean)) {
                                setDialogState(() {
                                  tags.add(clean);
                                  tagCtrl.clear();
                                });
                                triggerAutoSave();
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded),
                          onPressed: () {
                            final clean = tagCtrl.text.trim().replaceAll('#', '');
                            if (clean.isNotEmpty && !tags.contains(clean)) {
                              setDialogState(() {
                                tags.add(clean);
                                tagCtrl.clear();
                              });
                              triggerAutoSave();
                            }
                          },
                        ),
                      ],
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: tags.map((t) {
                          return Chip(
                            label: Text('#$t', style: const TextStyle(fontSize: 11)),
                            deleteIcon: const Icon(Icons.close_rounded, size: 14),
                            onDeleted: () {
                              setDialogState(() => tags.remove(t));
                              triggerAutoSave();
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Web Link Input & Chips
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: linkCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Attach Web Link',
                              hintText: 'https://...',
                              isDense: true,
                            ),
                            onSubmitted: (val) {
                              final url = val.trim();
                              if (url.isNotEmpty && !links.contains(url)) {
                                setDialogState(() {
                                  links.add(url);
                                  linkCtrl.clear();
                                });
                                triggerAutoSave();
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.link_rounded),
                          onPressed: () {
                            final url = linkCtrl.text.trim();
                            if (url.isNotEmpty && !links.contains(url)) {
                              setDialogState(() {
                                links.add(url);
                                linkCtrl.clear();
                              });
                              triggerAutoSave();
                            }
                          },
                        ),
                      ],
                    ),
                    if (links.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: links.map((l) {
                          return InputChip(
                            label: Text(l, style: const TextStyle(fontSize: 11)),
                            onDeleted: () {
                              setDialogState(() => links.remove(l));
                              triggerAutoSave();
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Attach Image via File Picker
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.photo_library_outlined, size: 18),
                          label: const Text('Attach Image'),
                          onPressed: () async {
                            final file = await FilePicker.pickFile(type: FileType.image);
                            if (file != null && file.path != null) {
                              setDialogState(() {
                                images.add(file.path!);
                              });
                              triggerAutoSave();
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        if (images.isNotEmpty)
                          Text('${images.length} attached', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    if (images.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: images.map((path) {
                            final file = File(path);
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: file.existsSync()
                                      ? Image.file(file, fit: BoxFit.cover)
                                      : const Icon(Icons.image, size: 20),
                                ),
                                Positioned(
                                  top: -4,
                                  right: 4,
                                  child: InkWell(
                                    onTap: () {
                                      setDialogState(() => images.remove(path));
                                      triggerAutoSave();
                                    },
                                    child: const CircleAvatar(
                                      radius: 9,
                                      backgroundColor: Colors.red,
                                      child: Icon(Icons.close, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Color Picker
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Color: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ...colorOptions.map((cv) {
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() => colorVal = cv);
                              triggerAutoSave();
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Color(cv),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorVal == cv ? Theme.of(ctx).colorScheme.onSurface : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catDate,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  if (title.isNotEmpty) {
                    if (existing != null) {
                      await _service.updateNote(existing.copyWith(
                        title: title,
                        content: contentCtrl.text.trim(),
                        folder: folder,
                        category: category,
                        colorValue: colorVal,
                        isChecklist: isChecklist,
                        checklist: checklist,
                        tags: tags,
                        imagePaths: images,
                        webLinks: links,
                        updatedAt: DateTime.now(),
                      ));
                    } else {
                      await _service.addNote(NoteItem(
                        id: 'note_${DateTime.now().millisecondsSinceEpoch}',
                        title: title,
                        content: contentCtrl.text.trim(),
                        folder: folder,
                        category: category,
                        colorValue: colorVal,
                        isChecklist: isChecklist,
                        checklist: checklist,
                        tags: tags,
                        imagePaths: images,
                        webLinks: links,
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
          );
        },
      ),
    );
  }

  // ================= 2. CALENDAR & 3 VIEWS =================
  Widget _buildCalendarTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Event & Meeting Schedule',
          primaryResult: '${_service.upcomingEventsCount()} Upcoming Events',
          subtitle: 'Monthly grid, weekly view, daily agenda, recurring events, and note links',
          accentColor: AppColors.catDate,
        ),
        const SizedBox(height: 14),

        // View Selector (Month / Week / Day)
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<CalendarViewType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: CalendarViewType.month,
                label: Text('Month'),
                icon: Icon(Icons.calendar_view_month_rounded, size: 16),
              ),
              ButtonSegment(
                value: CalendarViewType.week,
                label: Text('Week'),
                icon: Icon(Icons.calendar_view_week_rounded, size: 16),
              ),
              ButtonSegment(
                value: CalendarViewType.day,
                label: Text('Day Agenda'),
                icon: Icon(Icons.calendar_view_day_rounded, size: 16),
              ),
            ],
            selected: {_calendarView},
            onSelectionChanged: (val) => setState(() => _calendarView = val.first),
          ),
        ),
        const SizedBox(height: 14),

        // Active View Widget
        if (_calendarView == CalendarViewType.month)
          _buildMonthCalendarView(isDark)
        else if (_calendarView == CalendarViewType.week)
          _buildWeekCalendarView(isDark)
        else
          _buildDayAgendaView(isDark),
      ],
    );
  }

  Widget _buildMonthCalendarView(bool isDark) {
    final daysInMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_calendarMonth.year, _calendarMonth.month, 1).weekday;
    final dayEvents = _service.getEventsForDay(_selectedCalendarDay);
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month Header & Navigation
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
        const SizedBox(height: 6),

        // Weekday header
        Row(
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) {
            return Expanded(
              child: Center(
                child: Text(
                  d,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // 42-cell Monthly Grid
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
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
            final eventsOnDay = _service.getEventsForDay(date);

            return GestureDetector(
              onTap: () => setState(() => _selectedCalendarDay = date),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.catDate
                      : (isDark ? AppColors.darkCard : AppColors.lightCard),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isToday
                        ? AppColors.catDate
                        : (isSelected
                            ? AppColors.catDate
                            : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                    width: isToday ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontWeight: (isSelected || isToday) ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : (isToday ? AppColors.catDate : null),
                      ),
                    ),
                    if (eventsOnDay.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 5,
                        height: 5,
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

        // Selected Day Agenda Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Agenda for ${DateFormat('MMM d, yyyy').format(_selectedCalendarDay)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
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
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No events scheduled for this day.',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dayEvents.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _buildEventCard(dayEvents[i], isDark),
          ),
      ],
    );
  }

  Widget _buildWeekCalendarView(bool isDark) {
    final today = DateTime.now();
    // Calculate week start (Monday)
    final diffToMonday = _selectedCalendarDay.weekday - 1;
    final weekStart = _selectedCalendarDay.subtract(Duration(days: diffToMonday));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Week Navigator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => setState(() {
                _selectedCalendarDay = _selectedCalendarDay.subtract(const Duration(days: 7));
              }),
            ),
            Text(
              '${DateFormat("MMM d").format(weekStart)} - ${DateFormat("MMM d, yyyy").format(weekEnd)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => setState(() {
                _selectedCalendarDay = _selectedCalendarDay.add(const Duration(days: 7));
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 7-day strip
        Row(
          children: weekDays.map((d) {
            final isSelected = d.year == _selectedCalendarDay.year &&
                d.month == _selectedCalendarDay.month &&
                d.day == _selectedCalendarDay.day;
            final isToday = d.year == today.year &&
                d.month == today.month &&
                d.day == today.day;
            final count = _service.getEventsForDay(d).length;

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedCalendarDay = d),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.catDate
                        : (isDark ? AppColors.darkCard : AppColors.lightCard),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isToday
                          ? AppColors.catDate
                          : (isSelected
                              ? AppColors.catDate
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                      width: isToday ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('E').format(d),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : (isToday ? AppColors.catDate : null),
                        ),
                      ),
                      if (count > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white24 : AppColors.catDate.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppColors.catDate,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Events for selected day in the week
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('EEEE, MMM d, yyyy').format(_selectedCalendarDay),
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

        ..._buildDayEventList(_selectedCalendarDay, isDark),
      ],
    );
  }

  Widget _buildDayAgendaView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day Navigator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => setState(() {
                _selectedCalendarDay = _selectedCalendarDay.subtract(const Duration(days: 1));
              }),
            ),
            Row(
              children: [
                Text(
                  DateFormat('EEEE, MMM d, yyyy').format(_selectedCalendarDay),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _selectedCalendarDay = DateTime.now()),
                  child: const Text('Today'),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => setState(() {
                _selectedCalendarDay = _selectedCalendarDay.add(const Duration(days: 1));
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Chronological Timeline',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
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

        ..._buildDayEventList(_selectedCalendarDay, isDark),
      ],
    );
  }

  List<Widget> _buildDayEventList(DateTime day, bool isDark) {
    final events = _service.getEventsForDay(day);
    if (events.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No events scheduled for ${DateFormat("MMM d, yyyy").format(day)}.',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ),
      ];
    }
    return [
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: events.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _buildEventCard(events[i], isDark),
      ),
    ];
  }

  Widget _buildEventCard(CalendarEventItem ev, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? AppColors.darkCard : AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(ev.colorValue).withValues(alpha: 0.2),
                  child: Icon(Icons.event_rounded, color: Color(ev.colorValue), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ev.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        '${ev.time}${ev.endTime.isNotEmpty ? " - ${ev.endTime}" : ""} • ${ev.category}'
                        '${ev.location.isNotEmpty ? " • ${ev.location}" : ""}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit Event',
                  onPressed: () => _openEventDialog(ev.date, existing: ev),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  tooltip: 'Delete Event',
                  onPressed: () async {
                    await _service.deleteEvent(ev.id);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
            if (ev.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                ev.description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
            if (ev.recurrence != EventRecurrence.none || ev.linkedNoteIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (ev.recurrence != EventRecurrence.none)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.catDate.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Repeats ${ev.recurrence.label}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.catDate),
                      ),
                    ),
                  ...ev.linkedNoteIds.map((noteId) {
                    final linkedNote = _service.notes.cast<NoteItem?>().firstWhere(
                          (n) => n?.id == noteId,
                          orElse: () => null,
                        );
                    if (linkedNote == null) return const SizedBox();
                    return ActionChip(
                      avatar: const Icon(Icons.link_rounded, size: 14),
                      label: Text(linkedNote.title, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openNoteEditorDialog(linkedNote),
                    );
                  }),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openEventDialog(DateTime defaultDate, {CalendarEventItem? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final timeCtrl = TextEditingController(text: existing?.time ?? '10:00 AM');
    final endTimeCtrl = TextEditingController(text: existing?.endTime ?? '11:00 AM');
    final locCtrl = TextEditingController(text: existing?.location ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');

    DateTime eventDate = existing?.date ?? defaultDate;
    String category = existing?.category ?? 'Meeting';
    PriorityLevel priority = existing?.priority ?? PriorityLevel.medium;
    EventRecurrence recurrence = existing?.recurrence ?? EventRecurrence.none;
    int colorVal = existing?.colorValue ?? 0xFF3B82F6;
    List<String> linkedNotes = List.from(existing?.linkedNoteIds ?? []);
    bool hasReminder = existing?.hasReminder ?? false;
    int reminderMinutes = existing?.reminderMinutesBefore ?? 15;

    final colorOptions = [
      0xFF3B82F6,
      0xFF10B981,
      0xFFEF4444,
      0xFFF59E0B,
      0xFF8B5CF6,
      0xFFEC4899,
      0xFF06B6D4,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Edit Calendar Event' : 'Add Calendar Event'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Event Title')),
                  const SizedBox(height: 10),

                  // Date Picker Row
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Date: ${DateFormat("MMM d, yyyy").format(eventDate)}'),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: eventDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2040),
                          );
                          if (picked != null) {
                            setDialogState(() => eventDate = picked);
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Start & End Time
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: timeCtrl,
                          decoration: const InputDecoration(labelText: 'Start Time (e.g. 10:00 AM)', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: endTimeCtrl,
                          decoration: const InputDecoration(labelText: 'End Time (e.g. 11:30 AM)', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: locCtrl,
                    decoration: const InputDecoration(labelText: 'Location or Meeting Link', isDense: true),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description / Details', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 10),

                  // Category & Priority
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(labelText: 'Category', isDense: true),
                          items: ['Meeting', 'Milestone', 'Work', 'Personal', 'Appointment', 'Birthday', 'Health']
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setDialogState(() => category = v ?? 'Meeting'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<PriorityLevel>(
                          initialValue: priority,
                          decoration: const InputDecoration(labelText: 'Priority', isDense: true),
                          items: PriorityLevel.values
                              .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                              .toList(),
                          onChanged: (v) => setDialogState(() => priority = v ?? PriorityLevel.medium),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Recurrence rule
                  DropdownButtonFormField<EventRecurrence>(
                    initialValue: recurrence,
                    decoration: const InputDecoration(labelText: 'Recurrence', isDense: true),
                    items: EventRecurrence.values
                        .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => recurrence = v ?? EventRecurrence.none),
                  ),
                  const SizedBox(height: 10),

                  // Reminder Notification Toggle
                  SwitchListTile(
                    title: const Text('Schedule Reminder Notification', style: TextStyle(fontSize: 14)),
                    subtitle: Text(
                      hasReminder ? '$reminderMinutes minutes before event' : 'No notification scheduled',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: hasReminder,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDialogState(() => hasReminder = val),
                  ),
                  if (hasReminder) ...[
                    DropdownButtonFormField<int>(
                      initialValue: reminderMinutes,
                      decoration: const InputDecoration(labelText: 'Reminder Timing', isDense: true),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('At time of event')),
                        DropdownMenuItem(value: 10, child: Text('10 minutes before')),
                        DropdownMenuItem(value: 15, child: Text('15 minutes before')),
                        DropdownMenuItem(value: 30, child: Text('30 minutes before')),
                        DropdownMenuItem(value: 60, child: Text('1 hour before')),
                        DropdownMenuItem(value: 1440, child: Text('1 day before')),
                      ],
                      onChanged: (v) => setDialogState(() => reminderMinutes = v ?? 15),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Link Existing Notes
                  if (_service.notes.isNotEmpty) ...[
                    const Text('Link Notes to Event:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _service.notes.map((n) {
                        final isLinked = linkedNotes.contains(n.id);
                        return FilterChip(
                          label: Text(n.title, style: const TextStyle(fontSize: 11)),
                          selected: isLinked,
                          selectedColor: AppColors.catDate.withValues(alpha: 0.25),
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                linkedNotes.add(n.id);
                              } else {
                                linkedNotes.remove(n.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Color Picker
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Color: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                              border: Border.all(
                                color: colorVal == cv ? Theme.of(ctx).colorScheme.onSurface : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catDate,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isNotEmpty) {
                  final event = CalendarEventItem(
                    id: existing?.id ?? 'event_${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    date: eventDate,
                    time: timeCtrl.text.trim(),
                    endTime: endTimeCtrl.text.trim(),
                    location: locCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    category: category,
                    priority: priority,
                    recurrence: recurrence,
                    colorValue: colorVal,
                    linkedNoteIds: linkedNotes,
                    hasReminder: hasReminder,
                    reminderMinutesBefore: reminderMinutes,
                  );

                  if (existing != null) {
                    await _service.updateEvent(event);
                  } else {
                    await _service.addEvent(event);
                  }
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

  // ================= 3. TO-DO & TASKS =================
  Widget _buildTodosTab(bool isDark) {
    final todos = _service.todos;
    final rate = _service.todoCompletionRate;
    final categories = ['All', 'Development', 'Finance', 'Testing', 'Tasks', 'Personal', 'Work', 'Shopping'];
    final filtered = filterTodos(todos, category: _selectedTodoCategory, status: _todoFilter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'To-Do & Productivity Checklists',
          primaryResult: '${rate.toStringAsFixed(0)}% Completed',
          subtitle: '${_service.pendingTodos.length} tasks pending • ${_service.overdueTodos.length} overdue',
          accentColor: AppColors.catEveryday,
          breakdowns: [
            BreakdownItem(label: 'Pending', value: '${_service.pendingTodos.length}'),
            BreakdownItem(label: 'Overdue', value: '${_service.overdueTodos.length}'),
            BreakdownItem(label: 'Done', value: '${todos.where((t) => t.isCompleted).length}'),
          ],
        ),
        const SizedBox(height: 14),

        // Action Buttons Row
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _openAddTodoDialog,
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(120, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await _service.clearCompletedTodos();
                if (mounted) setState(() {});
              },
              child: const Text('Clear Done'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Filter Segmented Button
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<TodoFilter>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: TodoFilter.all, label: Text('All')),
              ButtonSegment(value: TodoFilter.active, label: Text('Active')),
              ButtonSegment(value: TodoFilter.completed, label: Text('Completed')),
            ],
            selected: {_todoFilter == TodoFilter.overdue || _todoFilter == TodoFilter.today ? TodoFilter.all : _todoFilter},
            onSelectionChanged: (s) => setState(() => _todoFilter = s.first),
          ),
        ),
        const SizedBox(height: 10),

        // Categories Chips
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

        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No tasks in this view.',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _buildTodoCard(filtered[i], isDark),
          ),
      ],
    );
  }

  Widget _buildTodoCard(TodoItem t, bool isDark) {
    final doneSubs = t.doneSubtasks.length;
    Future<void> save(TodoItem updated) async {
      await _service.updateTodo(updated);
      if (mounted) setState(() {});
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: t.isOverdue
              ? AppColors.error.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: t.isOverdue ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Checkbox(
              value: t.isCompleted,
              activeColor: AppColors.catEveryday,
              onChanged: (_) async {
                await _service.toggleTodo(t.id);
                if (mounted) setState(() {});
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.category} • Priority: ${t.priority.label}'
                  '${t.subtasks.isEmpty ? "" : " • $doneSubs/${t.subtasks.length} subtasks"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                if (t.dueDate != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: t.isOverdue ? AppColors.error : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Due: ${DateFormat("MMM d, yyyy").format(t.dueDate!)}${t.dueTime.isNotEmpty ? " • ${t.dueTime}" : ""}'
                        '${t.isOverdue ? " (Overdue)" : ""}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: t.isOverdue ? FontWeight.bold : FontWeight.normal,
                          color: t.isOverdue ? AppColors.error : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
                if (t.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    t.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit task',
                  onPressed: () => _openAddTodoDialog(existing: t),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                  tooltip: 'Delete task',
                  onPressed: () async {
                    await _service.deleteTodo(t.id);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),

          // Subtasks list
          for (var s = 0; s < t.subtasks.length; s++)
            Padding(
              padding: const EdgeInsets.only(left: 36, right: 12),
              child: Row(
                children: [
                  Checkbox(
                    value: t.isSubtaskDone(s),
                    visualDensity: VisualDensity.compact,
                    activeColor: AppColors.catEveryday,
                    onChanged: (_) => save(t.toggleSubtask(s)),
                  ),
                  Expanded(
                    child: Text(
                      t.subtasks[s],
                      style: TextStyle(
                        fontSize: 13,
                        decoration: t.isSubtaskDone(s) ? TextDecoration.lineThrough : null,
                        color: t.isSubtaskDone(s) ? Colors.grey : null,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Remove subtask',
                    onPressed: () => save(t.removeSubtask(s)),
                  ),
                ],
              ),
            ),

          // Quick add subtask inline field
          Padding(
            padding: const EdgeInsets.only(left: 48, right: 16, bottom: 8, top: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Add a subtask...',
                      isDense: true,
                      border: InputBorder.none,
                      hintStyle: TextStyle(fontSize: 12),
                    ),
                    onSubmitted: (txt) {
                      if (txt.trim().isNotEmpty) {
                        save(t.addSubtask(txt));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAddTodoDialog({TodoItem? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final timeCtrl = TextEditingController(text: existing?.dueTime ?? '');
    final subtaskCtrl = TextEditingController();

    DateTime? dueDate = existing?.dueDate;
    String category = existing?.category ?? 'Tasks';
    PriorityLevel priority = existing?.priority ?? PriorityLevel.medium;
    List<String> subtasks = List.from(existing?.subtasks ?? []);
    bool hasReminder = existing?.hasReminder ?? false;
    int reminderMinutes = existing?.reminderMinutesBefore ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Edit Task' : 'Add New Task'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Task Title')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description / Notes', isDense: true),
                  ),
                  const SizedBox(height: 10),

                  // Due Date picker
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded, size: 20),
                    title: Text(
                      dueDate != null ? DateFormat('MMM d, yyyy').format(dueDate!) : 'No due date set',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dueDate != null)
                          TextButton(
                            onPressed: () => setDialogState(() => dueDate = null),
                            child: const Text('Clear'),
                          ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: dueDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2040),
                            );
                            if (picked != null) {
                              setDialogState(() => dueDate = picked);
                            }
                          },
                          child: Text(dueDate != null ? 'Change' : 'Pick Date'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: timeCtrl,
                    decoration: const InputDecoration(labelText: 'Due Time (optional, e.g. 5:00 PM)', isDense: true),
                  ),
                  const SizedBox(height: 10),

                  // Category & Priority as stacked full-width fields
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category', isDense: true),
                    items: ['Tasks', 'Development', 'Finance', 'Testing', 'Personal', 'Work', 'Shopping']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => category = v ?? 'Tasks'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<PriorityLevel>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority', isDense: true),
                    items: PriorityLevel.values
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => priority = v ?? PriorityLevel.medium),
                  ),
                  const SizedBox(height: 10),

                  // Reminder Notification
                  if (dueDate != null) ...[
                    SwitchListTile(
                      title: const Text('Schedule Deadline Notification', style: TextStyle(fontSize: 14)),
                      value: hasReminder,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setDialogState(() => hasReminder = val),
                    ),
                    if (hasReminder)
                      DropdownButtonFormField<int>(
                        initialValue: reminderMinutes,
                        decoration: const InputDecoration(labelText: 'Alert Timing', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('On Due Date')),
                          DropdownMenuItem(value: 60, child: Text('1 hour before')),
                          DropdownMenuItem(value: 1440, child: Text('1 day before')),
                        ],
                        onChanged: (v) => setDialogState(() => reminderMinutes = v ?? 0),
                      ),
                    const SizedBox(height: 10),
                  ],

                  // Checklist / Subtasks
                  const Text('Subtasks / Checklist:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: subtaskCtrl,
                          decoration: const InputDecoration(labelText: 'Subtask (optional)', isDense: true),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              setDialogState(() {
                                subtasks.add(val.trim());
                                subtaskCtrl.clear();
                              });
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded),
                        onPressed: () {
                          if (subtaskCtrl.text.trim().isNotEmpty) {
                            setDialogState(() {
                              subtasks.add(subtaskCtrl.text.trim());
                              subtaskCtrl.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  ...subtasks.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return Row(
                      children: [
                        const Icon(Icons.circle_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item, style: const TextStyle(fontSize: 13))),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                          onPressed: () => setDialogState(() => subtasks.removeAt(idx)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catEveryday,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isNotEmpty) {
                  final task = TodoItem(
                    id: existing?.id ?? 'todo_${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    description: descCtrl.text.trim(),
                    dueDate: dueDate,
                    dueTime: timeCtrl.text.trim(),
                    category: category,
                    priority: priority,
                    subtasks: subtasks,
                    doneSubtasks: existing?.doneSubtasks ?? const [],
                    isCompleted: existing?.isCompleted ?? false,
                    hasReminder: hasReminder,
                    reminderMinutesBefore: reminderMinutes,
                  );

                  if (existing != null) {
                    await _service.updateTodo(task);
                  } else {
                    await _service.addTodo(task);
                  }
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

  // ================= 4. REMINDERS & NOTIFICATIONS =================
  Widget _buildRemindersTab(bool isDark) {
    final reminders = _service.reminders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Reminders & Notifications',
          primaryResult: '${reminders.where((r) => r.isEnabled).length} Active Reminders',
          subtitle: 'Completely offline local reminders, birthday countdowns, and scheduled alerts',
          accentColor: AppColors.catHealth,
          breakdowns: [
            BreakdownItem(label: 'Total', value: '${reminders.length}'),
            BreakdownItem(label: 'Active', value: '${reminders.where((r) => r.isEnabled).length}'),
            BreakdownItem(label: 'Serverless', value: '100% Offline'),
          ],
        ),
        const SizedBox(height: 14),

        // Permission Request Banner (if permission not yet confirmed)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.catHealth.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.catHealth.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: AppColors.catHealth, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Local Offline Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      'Ensure notifications are allowed in system settings to receive timely alerts.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () async {
                  final granted = await _notificationService.requestPermissions();
                  _showToast(granted ? 'Notification permission granted!' : 'Permission status updated.');
                  if (mounted) setState(() {});
                },
                child: const Text('Check Status'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_alert_rounded),
                label: const Text('Add Reminder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catHealth,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _openAddReminderDialog,
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Test Alert'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(120, 46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await _notificationService.showTestNotification();
                _showToast('Test notification triggered!');
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Reminders List
        if (reminders.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No reminders scheduled yet.\nTap + Add Reminder to schedule one-time or recurring alerts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reminders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = reminders[i];
              return Card(
                elevation: 0,
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.catHealth.withValues(alpha: 0.15),
                    child: Icon(
                      r.type == ReminderType.birthday
                          ? Icons.cake_rounded
                          : (r.type == ReminderType.event
                              ? Icons.event_rounded
                              : (r.type == ReminderType.task
                                  ? Icons.task_alt_rounded
                                  : Icons.alarm_rounded)),
                      color: AppColors.catHealth,
                      size: 20,
                    ),
                  ),
                  title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    '${DateFormat("MMM d, yyyy • h:mm a").format(r.scheduledAt)} • ${r.type.label}'
                    '${r.body.isNotEmpty ? "\n${r.body}" : ""}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: r.isEnabled,
                        activeThumbColor: AppColors.catHealth,
                        onChanged: (_) async {
                          await _service.toggleReminderEnabled(r.id);
                          if (mounted) setState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                        onPressed: () async {
                          await _service.deleteReminder(r.id);
                          if (mounted) setState(() {});
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

  void _openAddReminderDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    DateTime scheduledDate = DateTime.now().add(const Duration(hours: 1));
    TimeOfDay scheduledTime = TimeOfDay.fromDateTime(scheduledDate);
    ReminderType reminderType = ReminderType.oneTime;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Reminder'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Reminder Title')),
                  const SizedBox(height: 10),
                  TextField(controller: bodyCtrl, decoration: const InputDecoration(labelText: 'Description / Note')),
                  const SizedBox(height: 12),

                  // Date Picker
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Date: ${DateFormat("MMM d, yyyy").format(scheduledDate)}'),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: scheduledDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2040),
                          );
                          if (picked != null) {
                            setDialogState(() => scheduledDate = picked);
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Time Picker
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Time: ${scheduledTime.format(ctx)}'),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: scheduledTime,
                          );
                          if (picked != null) {
                            setDialogState(() => scheduledTime = picked);
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Reminder Type
                  DropdownButtonFormField<ReminderType>(
                    initialValue: reminderType,
                    decoration: const InputDecoration(labelText: 'Reminder Recurrence', isDense: true),
                    items: ReminderType.values
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => reminderType = v ?? ReminderType.oneTime),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.catHealth,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isNotEmpty) {
                  final finalDateTime = DateTime(
                    scheduledDate.year,
                    scheduledDate.month,
                    scheduledDate.day,
                    scheduledTime.hour,
                    scheduledTime.minute,
                  );

                  final reminder = ReminderItem(
                    id: 'rem_${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    body: bodyCtrl.text.trim(),
                    scheduledAt: finalDateTime,
                    type: reminderType,
                  );

                  await _service.addReminder(reminder);
                  if (mounted) setState(() {});
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Schedule Reminder'),
            ),
          ],
        ),
      ),
    );
  }

  // ================= 5. SUBSCRIPTIONS =================
  Widget _buildSubscriptionsTab(bool isDark) {
    final subs = _service.subscriptions;
    final monthlyTotal = _service.totalMonthlySubscriptionCost;
    final annualTotal = _service.totalAnnualSubscriptionCost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Recurring Subscriptions',
          primaryResult: '\$${monthlyTotal.toStringAsFixed(2)} / month',
          subtitle: 'Annualized Spend: \$${annualTotal.toStringAsFixed(2)} / yr',
          accentColor: AppColors.catFinance,
          breakdowns: [
            BreakdownItem(label: 'Active', value: '${subs.where((s) => s.isActive).length}'),
            BreakdownItem(label: 'Total', value: '${subs.length}'),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
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
        if (subs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No subscriptions added yet.',
                style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: subs.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final s = subs[i];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                leading: CircleAvatar(
                  backgroundColor: AppColors.catFinance.withValues(alpha: 0.2),
                  child: const Icon(Icons.credit_card_rounded, color: AppColors.catFinance),
                ),
                title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${s.category} • Renews in ${s.daysUntilRenewal} days'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '\$${s.cost.toStringAsFixed(2)}/${s.billingCycle == "Yearly" ? "yr" : "mo"}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: s.isActive,
                      activeThumbColor: AppColors.catFinance,
                      onChanged: (_) async {
                        await _service.toggleSubscriptionActive(s.id);
                        if (mounted) setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                      onPressed: () async {
                        await _service.deleteSubscription(s.id);
                        if (mounted) setState(() {});
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

  void _openAddSubscriptionDialog() {
    final nameCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    String cycle = 'Monthly';
    String category = 'Streaming';
    DateTime renewal = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Subscription'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name (e.g. Netflix)')),
                const SizedBox(height: 10),
                TextField(
                  controller: costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cost', prefixText: '\$'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: cycle,
                  decoration: const InputDecoration(labelText: 'Billing Cycle'),
                  items: ['Monthly', 'Yearly'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => cycle = v ?? 'Monthly'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ['Streaming', 'Software', 'Gym', 'Gaming', 'Cloud', 'News']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? 'Streaming'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Next renewal date', style: TextStyle(fontSize: 14)),
                  subtitle: Text(DateFormat('MMM d, yyyy').format(renewal)),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: renewal,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) {
                      setDialogState(() => renewal = picked);
                    }
                  },
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
                if (name.isNotEmpty && cost > 0) {
                  await _service.addSubscription(SubscriptionItem(
                    id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    cost: cost,
                    billingCycle: cycle,
                    category: category,
                    nextRenewalDate: renewal,
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

  // ================= 6. BILLS =================
  Widget _buildBillsTab(bool isDark) {
    final bills = _service.bills;
    final unpaid = _service.totalUnpaidBillsAmount;
    final overdueCount = _service.overdueBillsCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Bill Due Date Tracker',
          primaryResult: '\$${unpaid.toStringAsFixed(2)} Unpaid',
          subtitle: '$overdueCount bills currently overdue',
          accentColor: AppColors.catFinance,
          breakdowns: [
            BreakdownItem(label: 'Unpaid', value: '\$${unpaid.toStringAsFixed(2)}'),
            BreakdownItem(label: 'Overdue', value: '$overdueCount'),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.add),
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
        if (bills.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No bills logged.',
                style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: bills.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final b = bills[i];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: b.isOverdue
                        ? AppColors.error
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                leading: CircleAvatar(
                  backgroundColor: (b.isPaid ? Colors.green : (b.isOverdue ? AppColors.error : AppColors.catFinance))
                      .withValues(alpha: 0.2),
                  child: Icon(
                    b.isPaid ? Icons.check_circle_rounded : Icons.receipt_rounded,
                    color: b.isPaid ? Colors.green : (b.isOverdue ? AppColors.error : AppColors.catFinance),
                  ),
                ),
                title: Text(
                  b.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: b.isPaid ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text('${b.payee} • Due: ${DateFormat('MMM d, yyyy').format(b.dueDate)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('\$${b.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Checkbox(
                      value: b.isPaid,
                      activeColor: Colors.green,
                      onChanged: (_) async {
                        await _service.toggleBillPaid(b.id);
                        if (mounted) setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                      onPressed: () async {
                        await _service.deleteBill(b.id);
                        if (mounted) setState(() {});
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

  void _openAddBillDialog() {
    final titleCtrl = TextEditingController();
    final payeeCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 7));
    String category = 'Utilities';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Upcoming Bill'),
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
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: ['Utilities', 'Rent', 'Credit Card', 'Phone', 'Internet', 'Insurance']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v ?? 'Utilities'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due date', style: TextStyle(fontSize: 14)),
                  subtitle: Text(DateFormat('MMM d, yyyy').format(dueDate)),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 20),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: dueDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2040),
                    );
                    if (picked != null) {
                      setDialogState(() => dueDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (title.isNotEmpty) {
                  await _service.addBill(BillItem(
                    id: 'bill_${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    payee: payeeCtrl.text.trim(),
                    amount: amt,
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

  // ================= 7. WORK HOURS =================
  Widget _buildWorkHoursTab(bool isDark) {
    final active = _service.activeWorkSession;
    final totalHours = _service.totalTrackedHours;
    final totalEarned = _service.totalEarnings;
    final sessions = _service.workSessions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Work Hours & Timesheet',
          primaryResult: '${totalHours.toStringAsFixed(1)} Total Hours',
          subtitle: 'Gross Earnings: \$${totalEarned.toStringAsFixed(2)}',
          accentColor: AppColors.catDev,
          breakdowns: [
            BreakdownItem(label: 'Tracked', value: '${totalHours.toStringAsFixed(1)}h'),
            BreakdownItem(label: 'Sessions', value: '${sessions.length}'),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            children: [
              Text(
                active != null ? 'ACTIVE CLOCK-IN' : 'CURRENT STATUS: OFF THE CLOCK',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: active != null ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                active != null
                    ? '${_activeSessionDuration.inHours.toString().padLeft(2, '0')}:'
                        '${(_activeSessionDuration.inMinutes % 60).toString().padLeft(2, '0')}:'
                        '${(_activeSessionDuration.inSeconds % 60).toString().padLeft(2, '0')}'
                    : '00:00:00',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 36, letterSpacing: 2),
              ),
              const SizedBox(height: 16),
              if (active == null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Clock In Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    await _service.clockIn();
                    _checkActiveWorkSession();
                    if (mounted) setState(() {});
                  },
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Clock Out & Log'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    await _service.clockOut();
                    _checkActiveWorkSession();
                    if (mounted) setState(() {});
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (sessions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No work sessions logged.',
                style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sessions.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final w = sessions[i];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                leading: CircleAvatar(
                  backgroundColor: AppColors.catDev.withValues(alpha: 0.2),
                  child: const Icon(Icons.timer_outlined, color: AppColors.catDev),
                ),
                title: Text(w.taskDescription, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${DateFormat('MMM d').format(w.startTime)} • '
                  '${w.durationHours.toStringAsFixed(1)} hrs • \$${w.hourlyRate.toStringAsFixed(0)}/hr',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('\$${w.earnings.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                      onPressed: () async {
                        await _service.deleteWorkSession(w.id);
                        if (mounted) setState(() {});
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

  Color _getPriorityColor(PriorityLevel priority) {
    switch (priority) {
      case PriorityLevel.high:
        return AppColors.error;
      case PriorityLevel.medium:
        return AppColors.warning;
      case PriorityLevel.low:
        return AppColors.catFinance;
    }
  }
}
