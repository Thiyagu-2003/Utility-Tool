import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/tool_scaffold.dart';

class CourseRecord {
  String name;
  double credits;
  String grade;

  CourseRecord({required this.name, required this.credits, required this.grade});
}

const Map<String, double> _gradePoints = {
  'O (Outstanding)': 10.0,
  'A+': 9.0,
  'A': 8.0,
  'B+': 7.0,
  'B': 6.0,
  'C': 5.0,
  'F (Fail)': 0.0,
};

String _cleanGradeKey(String grade) {
  if (grade == 'O') return 'O (Outstanding)';
  if (grade == 'F') return 'F (Fail)';
  return grade;
}

/// Credit-weighted GPA on the 10-point scale; 0 when there are no credits.
double calculateGpa(List<CourseRecord> courses) {
  var points = 0.0, credits = 0.0;
  for (final c in courses) {
    points += (_gradePoints[_cleanGradeKey(c.grade)] ?? 8.0) * c.credits;
    credits += c.credits;
  }
  return credits == 0 ? 0.0 : points / credits;
}

List<CourseRecord> _defaultCourses() => [
      CourseRecord(name: 'Mathematics III', credits: 4.0, grade: 'A'),
      CourseRecord(name: 'Data Structures', credits: 4.0, grade: 'A+'),
      CourseRecord(name: 'Operating Systems', credits: 3.0, grade: 'A'),
      CourseRecord(name: 'Algorithms Lab', credits: 2.0, grade: 'O'),
      CourseRecord(name: 'Digital Electronics', credits: 3.0, grade: 'B+'),
    ];

class GpaCalculatorScreen extends StatefulWidget {
  const GpaCalculatorScreen({super.key});

  @override
  State<GpaCalculatorScreen> createState() => _GpaCalculatorScreenState();
}

class _GpaCalculatorScreenState extends State<GpaCalculatorScreen> {
  List<CourseRecord> _courses = _defaultCourses();

  double get _totalCredits => _courses.fold(0.0, (sum, item) => sum + item.credits);

  // Standard conversion: CGPA * 9.5
  double get _percentageEstimate => (calculateGpa(_courses) * 9.5).clamp(0.0, 100.0);

  void _addCourse() {
    setState(() {
      _courses.add(CourseRecord(name: 'Course ${_courses.length + 1}', credits: 3.0, grade: 'A'));
    });
  }

  void _removeCourse(int index) {
    if (_courses.length > 1) {
      setState(() => _courses.removeAt(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gpa = calculateGpa(_courses);
    final pct = _percentageEstimate;

    return ToolScaffold(
      title: 'GPA & Grade Calculator',
      category: ToolCategory.education,
      toolId: 'gpa_calc',
      onReset: () => setState(() => _courses = _defaultCourses()),
      actions: [
        IconButton(
          tooltip: 'Add Subject',
          icon: const Icon(Icons.add_rounded),
          onPressed: _addCourse,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  const Color(0xFF6D28D9).withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.35), width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CUMULATIVE GPA (10.0 scale)',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            gpa.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B5CF6),
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Approx %', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: isDark ? Colors.white : const Color(0xFF6D28D9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.layers_outlined, size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Total Registered Credits: ${_totalCredits.toStringAsFixed(1)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${_courses.length} Subjects',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(child: Text('Course List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              TextButton.icon(
                onPressed: _addCourse,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Course'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var idx = 0; idx < _courses.length; idx++) _courseRow(idx, _courses[idx], isDark),
        ],
      ),
    );
  }

  Widget _courseRow(int idx, CourseRecord course, bool isDark) {
    return Container(
      // Keyed so removing a row doesn't hand its text field state to the next course.
      key: ObjectKey(course),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: course.name,
                  decoration: const InputDecoration(labelText: 'Subject', border: InputBorder.none, isDense: true),
                  onChanged: (val) => course.name = val,
                ),
              ),
              IconButton(
                tooltip: 'Remove subject',
                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                onPressed: () => _removeCourse(idx),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<double>(
                  initialValue: course.credits,
                  decoration: const InputDecoration(labelText: 'Credits', border: InputBorder.none, isDense: true),
                  items: [1.0, 2.0, 3.0, 4.0, 5.0]
                      .map((c) => DropdownMenuItem(value: c, child: Text('${c.toInt()}')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => course.credits = val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _cleanGradeKey(course.grade),
                  decoration: const InputDecoration(labelText: 'Grade', border: InputBorder.none, isDense: true),
                  items: _gradePoints.keys
                      .map((g) => DropdownMenuItem(
                            value: g,
                            child: Text(g.split(' ').first, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => course.grade = val);
                  },
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
        ],
      ),
    );
  }
}
