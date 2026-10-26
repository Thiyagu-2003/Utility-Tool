import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

// Re-export pure math helper functions so existing callers/tests continue to resolve
export '../math/math_toolkit_screen.dart'
    show isPrimeInt, primesInRange, fmtNum, matAdd, matSub, matMul, matToString;

enum AcademicTab {
  marks('Marks & Grade', Icons.grade_rounded),
  examNeeded('Exam Needed', Icons.checklist_rounded),
  attendance('Attendance', Icons.event_available_rounded);

  final String label;
  final IconData icon;
  const AcademicTab(this.label, this.icon);
}

/// How many classes can still be skipped (canSkip) while staying at or above
/// [required] %, or how many must be attended in a row (mustAttend) to get there.
/// Both null means the target can no longer be reached. Integer-scaled maths so
/// 42/0.7 can't land on 59.999... and lose a class.
({int? canSkip, int? mustAttend}) attendancePlan(int attended, int total, double required) {
  if (attended * 100 >= required * total - 1e-9) {
    final maxTotal = (attended * 100 / required + 1e-9).floor();
    return (canSkip: math.max(0, maxTotal - total), mustAttend: null);
  }
  if (required >= 100) return (canSkip: null, mustAttend: null);
  final need = ((required * total - 100 * attended) / (100 - required) - 1e-9).ceil();
  return (canSkip: null, mustAttend: need);
}

class SubjectMark {
  String name;
  double maxMark;
  double scored;
  SubjectMark({required this.name, required this.maxMark, required this.scored});
}

class AcademicToolkitScreen extends StatefulWidget {
  final AcademicTab initialTab;

  const AcademicToolkitScreen({
    super.key,
    this.initialTab = AcademicTab.marks,
  });

  @override
  State<AcademicToolkitScreen> createState() => _AcademicToolkitScreenState();
}

class _AcademicToolkitScreenState extends State<AcademicToolkitScreen> {
  late AcademicTab _activeTab;

  // 1. MARKS PERCENTAGE
  final List<SubjectMark> _subjects = [
    SubjectMark(name: 'Mathematics', maxMark: 100, scored: 88),
    SubjectMark(name: 'Physics', maxMark: 100, scored: 82),
    SubjectMark(name: 'Chemistry', maxMark: 100, scored: 79),
    SubjectMark(name: 'Computer Science', maxMark: 100, scored: 94),
    SubjectMark(name: 'English', maxMark: 100, scored: 85),
  ];

  // 2. EXAM SCORE NEEDED
  final _examCurrentCtrl = TextEditingController(text: '78');
  final _examTargetCtrl = TextEditingController(text: '85');
  final _examWeightCtrl = TextEditingController(text: '30');

  // 3. ATTENDANCE ELIGIBILITY
  final _attTotalCtrl = TextEditingController(text: '60');
  final _attAttendedCtrl = TextEditingController(text: '42');
  final _attRequiredCtrl = TextEditingController(text: '75');

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  void dispose() {
    _examCurrentCtrl.dispose();
    _examTargetCtrl.dispose();
    _examWeightCtrl.dispose();
    _attTotalCtrl.dispose();
    _attAttendedCtrl.dispose();
    _attRequiredCtrl.dispose();
    super.dispose();
  }

  // --- CALCULATION HELPERS ---

  // 1. Marks
  Map<String, dynamic> _computeMarks() {
    if (_subjects.isEmpty) {
      return {'totalScored': 0.0, 'totalMax': 0.0, 'percent': 0.0, 'grade': 'N/A'};
    }
    double scored = 0.0;
    double maxM = 0.0;
    for (final s in _subjects) {
      scored += s.scored;
      maxM += s.maxMark;
    }
    final pct = maxM > 0 ? (scored / maxM) * 100 : 0.0;

    String grade = 'F';
    if (pct >= 90) {
      grade = 'A+ (Outstanding)';
    } else if (pct >= 80) {
      grade = 'A (Excellent)';
    } else if (pct >= 70) {
      grade = 'B (Good)';
    } else if (pct >= 60) {
      grade = 'C (Satisfactory)';
    } else if (pct >= 50) {
      grade = 'D (Pass)';
    }

    return {'totalScored': scored, 'totalMax': maxM, 'percent': pct, 'grade': grade};
  }

  // 2. Exam Score Needed
  Map<String, dynamic> _computeExamNeeded() {
    final cur = double.tryParse(_examCurrentCtrl.text.trim()) ?? 0.0;
    final target = double.tryParse(_examTargetCtrl.text.trim()) ?? 0.0;
    final weight = (double.tryParse(_examWeightCtrl.text.trim()) ?? 0.0) / 100.0;

    if (weight <= 0.0 || weight > 1.0) {
      return {'needed': 0.0, 'status': 'Invalid final exam weight percentage (must be between 1% and 100%)', 'isPossible': false};
    }

    final currentPortion = cur * (1.0 - weight);
    final needed = (target - currentPortion) / weight;

    if (needed > 100) {
      return {
        'needed': needed,
        'status': 'You need ${needed.toStringAsFixed(1)}%, which exceeds 100%. Target grade is statistically out of reach.',
        'isPossible': false,
      };
    } else if (needed <= 0) {
      return {
        'needed': 0.0,
        'status': 'You already secured this grade even with a 0% on the final exam!',
        'isPossible': true,
      };
    }

    return {
      'needed': needed,
      'status': 'You need to score at least ${needed.toStringAsFixed(1)}% on your final exam to achieve $target%.',
      'isPossible': true,
    };
  }

  // 3. Attendance
  Map<String, dynamic> _computeAttendance() {
    final total = int.tryParse(_attTotalCtrl.text.trim()) ?? 0;
    final attended = int.tryParse(_attAttendedCtrl.text.trim()) ?? 0;
    final req = double.tryParse(_attRequiredCtrl.text.trim()) ?? 75.0;

    if (total <= 0 || attended < 0 || attended > total) {
      return {'pct': 0.0, 'status': 'Invalid numbers', 'action': 'Check total and attended classes'};
    }

    final pct = (attended / total) * 100;
    final plan = attendancePlan(attended, total, req);

    String action;
    if (plan.canSkip != null) {
      final s = plan.canSkip!;
      action = s == 0
          ? 'On the line: missing 1 more class drops you below ${req.toStringAsFixed(0)}%.'
          : 'You can safely skip up to $s more ${s == 1 ? 'class' : 'classes'} and stay above ${req.toStringAsFixed(0)}%.';
    } else if (plan.mustAttend != null) {
      final a = plan.mustAttend!;
      action = 'You must attend the next $a consecutive ${a == 1 ? 'class' : 'classes'} to reach ${req.toStringAsFixed(0)}%.';
    } else {
      action = 'Mathematically impossible to reach ${req.toStringAsFixed(0)}% attendance.';
    }

    return {'pct': pct, 'status': pct >= req ? 'Eligible / Safe' : 'Attendance Shortage', 'action': action};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Academic & Education Suite',
      category: ToolCategory.education,
      toolId: 'academic_toolkit',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabChips(isDark),
          const SizedBox(height: 16),
          if (_activeTab == AcademicTab.marks) _buildMarksTab(isDark),
          if (_activeTab == AcademicTab.examNeeded) _buildExamNeededTab(isDark),
          if (_activeTab == AcademicTab.attendance) _buildAttendanceTab(isDark),
        ],
      ),
    );
  }

  Widget _buildTabChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AcademicTab.values.map((tab) {
          final isSelected = _activeTab == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              avatar: Icon(tab.icon, size: 16, color: isSelected ? Colors.white : AppColors.catEducation),
              label: Text(tab.label),
              selected: isSelected,
              onSelected: (_) {
                PreferencesService().triggerHaptic();
                setState(() => _activeTab = tab);
              },
              selectedColor: AppColors.catEducation,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- TAB 1: MARKS PERCENTAGE ---
  Widget _buildMarksTab(bool isDark) {
    final res = _computeMarks();
    final pct = res['percent'] as double;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Total Score & Grade',
          primaryResult: '${pct.toStringAsFixed(2)}%',
          subtitle: '${(res['totalScored'] as double).toStringAsFixed(0)} / ${(res['totalMax'] as double).toStringAsFixed(0)} Marks • Grade: ${res['grade']}',
          accentColor: AppColors.catEducation,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subject Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton.icon(
              onPressed: () {
                PreferencesService().triggerHaptic();
                setState(() {
                  _subjects.add(SubjectMark(name: 'Subject ${_subjects.length + 1}', maxMark: 100, scored: 0));
                });
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Subject'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._subjects.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      initialValue: s.name,
                      decoration: const InputDecoration(isDense: true, labelText: 'Subject'),
                      onChanged: (v) => s.name = v,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: s.scored.toStringAsFixed(0),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(isDense: true, labelText: 'Scored'),
                      onChanged: (v) => setState(() => s.scored = double.tryParse(v) ?? 0.0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: s.maxMark.toStringAsFixed(0),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(isDense: true, labelText: 'Out of'),
                      onChanged: (v) => setState(() => s.maxMark = double.tryParse(v) ?? 100.0),
                    ),
                  ),
                  if (_subjects.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                      onPressed: () {
                        PreferencesService().triggerHaptic();
                        setState(() => _subjects.removeAt(idx));
                      },
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- TAB 2: EXAM NEEDED ---
  Widget _buildExamNeededTab(bool isDark) {
    final res = _computeExamNeeded();
    final needed = res['needed'] as double;
    final isPossible = res['isPossible'] as bool;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Target Final Exam Score Needed',
          primaryResult: '${needed.toStringAsFixed(1)}%',
          subtitle: res['status'] as String,
          accentColor: isPossible ? AppColors.catEducation : Colors.redAccent,
        ),
        const SizedBox(height: 16),
        ModernTextField(
          label: 'Current Grade / Internal Score (%)',
          controller: _examCurrentCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        ModernTextField(
          label: 'Desired Target Overall Grade (%)',
          controller: _examTargetCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        ModernTextField(
          label: 'Final Exam Weight (%)',
          controller: _examWeightCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          hintText: 'e.g. 30 for 30% of course grade',
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // --- TAB 3: ATTENDANCE ---
  Widget _buildAttendanceTab(bool isDark) {
    final res = _computeAttendance();
    final pct = res['pct'] as double;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Current Attendance Status',
          primaryResult: '${pct.toStringAsFixed(1)}%',
          subtitle: res['status'] as String,
          accentColor: (res['status'] as String).contains('Eligible') ? AppColors.success : Colors.amber.shade700,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(res['action'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Total Classes Held', controller: _attTotalCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 10),
            Expanded(child: ModernTextField(label: 'Classes Attended', controller: _attAttendedCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: 12),
        ModernTextField(
          label: 'Required Minimum Attendance (%)',
          controller: _attRequiredCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          hintText: 'e.g. 75',
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}
