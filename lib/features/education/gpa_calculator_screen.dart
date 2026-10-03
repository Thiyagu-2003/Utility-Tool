import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class CourseRecord {
  String name;
  double credits;
  String grade;

  CourseRecord({required this.name, required this.credits, required this.grade});
}

class GpaCalculatorScreen extends StatefulWidget {
  const GpaCalculatorScreen({super.key});

  @override
  State<GpaCalculatorScreen> createState() => _GpaCalculatorScreenState();
}

class _GpaCalculatorScreenState extends State<GpaCalculatorScreen> {
  final List<CourseRecord> _courses = [
    CourseRecord(name: 'Mathematics III', credits: 4.0, grade: 'A'),
    CourseRecord(name: 'Data Structures', credits: 4.0, grade: 'A+'),
    CourseRecord(name: 'Operating Systems', credits: 3.0, grade: 'A'),
    CourseRecord(name: 'Algorithms Lab', credits: 2.0, grade: 'O'),
    CourseRecord(name: 'Digital Electronics', credits: 3.0, grade: 'B+'),
  ];

  static const Map<String, double> _gradePoints = {
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

  double get _calculatedGpa {
    double totalPoints = 0;
    double totalCredits = 0;

    for (var c in _courses) {
      final pts = _gradePoints[_cleanGradeKey(c.grade)] ?? 8.0;
      totalPoints += (pts * c.credits);
      totalCredits += c.credits;
    }

    if (totalCredits == 0) return 0.0;
    return totalPoints / totalCredits;
  }

  double get _totalCredits {
    return _courses.fold(0.0, (sum, item) => sum + item.credits);
  }

  double get _percentageEstimate {
    // Standard conversion: (CGPA * 9.5) or (CGPA * 10 - 7.5)
    final gpa = _calculatedGpa;
    return (gpa * 9.5).clamp(0.0, 100.0);
  }

  void _addCourse() {
    setState(() {
      _courses.add(CourseRecord(
        name: 'Course ${_courses.length + 1}',
        credits: 3.0,
        grade: 'A',
      ));
    });
  }

  void _removeCourse(int index) {
    if (_courses.length > 1) {
      setState(() {
        _courses.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gpa = _calculatedGpa;
    final pct = _percentageEstimate;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('GPA & Grade Calculator'),
        actions: [
          IconButton(
            tooltip: 'Add Subject',
            icon: const Icon(Icons.add_rounded),
            onPressed: _addCourse,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Luxury Double-bezel Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B5CF6).withOpacity(0.2),
                  const Color(0xFF6D28D9).withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withOpacity(0.35),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Approx %',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.layers_outlined,
                        size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      'Total Registered Credits: ${_totalCredits.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                    const Spacer(),
                    Text(
                      '${_courses.length} Subjects',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B5CF6),
                      ),
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
              const Text(
                'Course List',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _addCourse,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Course'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ..._courses.asMap().entries.map((entry) {
            final idx = entry.key;
            final course = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      initialValue: course.name,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (val) => course.name = val,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: DropdownButtonFormField<double>(
                      value: course.credits,
                      decoration: const InputDecoration(
                        labelText: 'Credits',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      items: [1.0, 2.0, 3.0, 4.0, 5.0].map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text('${c.toInt()}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => course.credits = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 75,
                    child: DropdownButtonFormField<String>(
                      value: _cleanGradeKey(course.grade),
                      decoration: const InputDecoration(
                        labelText: 'Grade',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      items: _gradePoints.keys.map((g) {
                        return DropdownMenuItem(
                          value: g,
                          child: Text(
                            g.split(' ').first,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => course.grade = val);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.redAccent, size: 20),
                    onPressed: () => _removeCourse(idx),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
