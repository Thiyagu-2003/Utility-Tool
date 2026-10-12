import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

/// Calendar age between two dates (time of day ignored; [asOf] must not be
/// before [birth]). A month-end birth date anniversaries on the last day of
/// shorter months, so 31 Jan -> 1 Mar 2023 is 1 month 1 day, never negative.
({int years, int months, int days}) calculateAgeParts(DateTime birth, DateTime asOf) {
  final b = DateTime.utc(birth.year, birth.month, birth.day);
  final a = DateTime.utc(asOf.year, asOf.month, asOf.day);
  DateTime anniversary(int months) {
    final m = b.month - 1 + months;
    final y = b.year + m ~/ 12;
    final mo = m % 12 + 1;
    return DateTime.utc(y, mo, math.min(b.day, DateTime.utc(y, mo + 1, 0).day));
  }

  var totalMonths = (a.year - b.year) * 12 + a.month - b.month;
  if (anniversary(totalMonths).isAfter(a)) totalMonths--;
  final days = a.difference(anniversary(totalMonths)).inDays;
  return (years: totalMonths ~/ 12, months: totalMonths % 12, days: days);
}

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
    // Date-only UTC values: no time-of-day or DST skew in day counts.
    final birth = DateTime.utc(_birthDate.year, _birthDate.month, _birthDate.day);
    final asOf = DateTime.utc(_asOfDate.year, _asOfDate.month, _asOfDate.day);
    if (asOf.isBefore(birth)) {
      return {
        'error': 'Target date cannot be before birth date',
        'years': 0,
        'months': 0,
        'days': 0,
      };
    }

    final (:years, :months, :days) = calculateAgeParts(birth, asOf);

    final totalDifference = asOf.difference(birth);
    final totalDays = totalDifference.inDays;
    final totalHours = totalDays * 24;
    final totalWeeks = (totalDays / 7).floor();

    // Next birthday calculation
    DateTime nextBirthday = DateTime.utc(asOf.year, birth.month, birth.day);
    if (nextBirthday.isBefore(asOf) || nextBirthday.isAtSameMomentAs(asOf)) {
      nextBirthday = DateTime.utc(asOf.year + 1, birth.month, birth.day);
    }
    final daysToNextBirthday = nextBirthday.difference(asOf).inDays;
    final untilBirthday = calculateAgeParts(asOf, nextBirthday);
    final nextBirthdayDayOfWeek = DateFormat('EEEE').format(nextBirthday);
    final birthDayOfWeek = DateFormat('EEEE').format(_birthDate);

    return {
      'years': years,
      'months': months,
      'days': days,
      'totalDays': totalDays,
      'totalHours': totalHours,
      'totalWeeks': totalWeeks,
      'totalMonths': years * 12 + months,
      'daysToNextBirthday': daysToNextBirthday,
      'untilBirthday': '${untilBirthday.months} mo ${untilBirthday.days} d',
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
              value: '${ageData['untilBirthday']} (${ageData['daysToNextBirthday']} days, ${ageData['nextBirthdayDayOfWeek']})',
            ),
            BreakdownItem(
              label: 'Total Months',
              value: NumberFormat('#,###').format(ageData['totalMonths']),
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
