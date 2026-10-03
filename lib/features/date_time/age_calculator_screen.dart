import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

class AgeCalculatorScreen extends StatefulWidget {
  const AgeCalculatorScreen({super.key});

  @override
  State<AgeCalculatorScreen> createState() => _AgeCalculatorScreenState();
}

class _AgeCalculatorScreenState extends State<AgeCalculatorScreen> {
  DateTime _birthDate = DateTime(2000, 1, 1);
  DateTime _asOfDate = DateTime.now();

  final DateFormat _displayFormat = DateFormat('dd MMM yyyy');

  Future<void> _pickDate({required bool isBirthDate}) async {
    PreferencesService().triggerSelectionHaptic();
    final picked = await showDatePicker(
      context: context,
      initialDate: isBirthDate ? _birthDate : _asOfDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isBirthDate) {
          _birthDate = picked;
        } else {
          _asOfDate = picked;
        }
      });
    }
  }

  Map<String, dynamic> _computeAge() {
    if (_asOfDate.isBefore(_birthDate)) {
      return {
        'error': 'Target date cannot be before birth date',
        'years': 0,
        'months': 0,
        'days': 0,
      };
    }

    int years = _asOfDate.year - _birthDate.year;
    int months = _asOfDate.month - _birthDate.month;
    int days = _asOfDate.day - _birthDate.day;

    if (days < 0) {
      final prevMonth = DateTime(_asOfDate.year, _asOfDate.month, 0);
      days += prevMonth.day;
      months -= 1;
    }

    if (months < 0) {
      years -= 1;
      months += 12;
    }

    final totalDifference = _asOfDate.difference(_birthDate);
    final totalDays = totalDifference.inDays;
    final totalHours = totalDays * 24;
    final totalWeeks = (totalDays / 7).floor();

    // Next birthday calculation
    DateTime nextBirthday = DateTime(_asOfDate.year, _birthDate.month, _birthDate.day);
    if (nextBirthday.isBefore(_asOfDate) || nextBirthday.isAtSameMomentAs(_asOfDate)) {
      nextBirthday = DateTime(_asOfDate.year + 1, _birthDate.month, _birthDate.day);
    }
    final daysToNextBirthday = nextBirthday.difference(_asOfDate).inDays;
    final nextBirthdayDayOfWeek = DateFormat('EEEE').format(nextBirthday);
    final birthDayOfWeek = DateFormat('EEEE').format(_birthDate);

    return {
      'years': years,
      'months': months,
      'days': days,
      'totalDays': totalDays,
      'totalHours': totalHours,
      'totalWeeks': totalWeeks,
      'daysToNextBirthday': daysToNextBirthday,
      'nextBirthdayDayOfWeek': nextBirthdayDayOfWeek,
      'birthDayOfWeek': birthDayOfWeek,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ageData = _computeAge();
    final hasError = ageData.containsKey('error');
    final primaryResult = hasError
        ? 'Invalid Range'
        : '${ageData['years']} yrs ${ageData['months']} mos ${ageData['days']} d';

    final breakdowns = hasError
        ? <BreakdownItem>[]
        : [
            BreakdownItem(
              label: 'Next Birthday',
              value: '${ageData['daysToNextBirthday']} days (${ageData['nextBirthdayDayOfWeek']})',
            ),
            BreakdownItem(
              label: 'Total Days',
              value: NumberFormat('#,###').format(ageData['totalDays']),
            ),
            BreakdownItem(
              label: 'Total Weeks',
              value: NumberFormat('#,###').format(ageData['totalWeeks']),
            ),
            BreakdownItem(
              label: 'Total Hours',
              value: NumberFormat('#,###').format(ageData['totalHours']),
            ),
            BreakdownItem(
              label: 'Born On',
              value: ageData['birthDayOfWeek'],
            ),
          ];

    return ToolScaffold(
      title: 'Age Calculator',
      category: ToolCategory.dateAge,
      toolId: 'age_calc',
      onReset: () {
        setState(() {
          _birthDate = DateTime(2000, 1, 1);
          _asOfDate = DateTime.now();
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: 'Current Age',
            primaryResult: primaryResult,
            subtitle: hasError ? ageData['error'] : 'Born on ${_displayFormat.format(_birthDate)}',
            accentColor: AppColors.catDate,
            breakdowns: breakdowns,
          ),
          const SizedBox(height: 24),
          ModernTextField(
            label: 'Date of Birth',
            hintText: _displayFormat.format(_birthDate),
            readOnly: true,
            prefixIcon: Icons.cake_outlined,
            suffix: TextButton(
              onPressed: () => _pickDate(isBirthDate: true),
              child: const Text('Change'),
            ),
            onTap: () => _pickDate(isBirthDate: true),
          ),
          const SizedBox(height: 16),
          ModernTextField(
            label: 'Age as of Date',
            hintText: _displayFormat.format(_asOfDate),
            readOnly: true,
            prefixIcon: Icons.event_available_outlined,
            suffix: TextButton(
              onPressed: () => _pickDate(isBirthDate: false),
              child: const Text('Change'),
            ),
            onTap: () => _pickDate(isBirthDate: false),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _asOfDate = DateTime.now();
                    });
                  },
                  icon: const Icon(Icons.today_rounded, size: 18),
                  label: const Text('Set As Of Today'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
