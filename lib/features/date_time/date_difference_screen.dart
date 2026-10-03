import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

class DateDifferenceScreen extends StatefulWidget {
  const DateDifferenceScreen({super.key});

  @override
  State<DateDifferenceScreen> createState() => _DateDifferenceScreenState();
}

class _DateDifferenceScreenState extends State<DateDifferenceScreen> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _includeEndDay = false;

  final DateFormat _displayFormat = DateFormat('dd MMM yyyy');

  Future<void> _pickDate({required bool isStartDate}) async {
    PreferencesService().triggerSelectionHaptic();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Map<String, dynamic> _computeDifference() {
    DateTime s = DateTime(_startDate.year, _startDate.month, _startDate.day);
    DateTime e = DateTime(_endDate.year, _endDate.month, _endDate.day);

    if (e.isBefore(s)) {
      final temp = s;
      s = e;
      e = temp;
    }

    int diffDays = e.difference(s).inDays;
    if (_includeEndDay) diffDays += 1;

    // Working days & weekends count
    int workingDays = 0;
    int weekendDays = 0;
    DateTime cur = s;
    final until = _includeEndDay ? e.add(const Duration(days: 1)) : e;

    while (cur.isBefore(until)) {
      if (cur.weekday == DateTime.saturday || cur.weekday == DateTime.sunday) {
        weekendDays++;
      } else {
        workingDays++;
      }
      cur = cur.add(const Duration(days: 1));
    }

    final weeks = (diffDays / 7).floor();
    final remainingDays = diffDays % 7;
    final totalHours = diffDays * 24;

    return {
      'totalDays': diffDays,
      'workingDays': workingDays,
      'weekendDays': weekendDays,
      'weeks': weeks,
      'remainingDays': remainingDays,
      'totalHours': totalHours,
    };
  }

  @override
  Widget build(BuildContext context) {
    final diff = _computeDifference();
    final totalDays = diff['totalDays'] as int;

    return ToolScaffold(
      title: 'Date Difference',
      category: ToolCategory.dateAge,
      toolId: 'date_diff',
      onReset: () {
        setState(() {
          _startDate = DateTime.now();
          _endDate = DateTime.now().add(const Duration(days: 30));
          _includeEndDay = false;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: 'Difference',
            primaryResult: '$totalDays ${totalDays == 1 ? 'Day' : 'Days'}',
            subtitle: '${diff['weeks']} weeks and ${diff['remainingDays']} days',
            accentColor: AppColors.catDate,
            breakdowns: [
              BreakdownItem(
                label: 'Working Days (Mon-Fri)',
                value: '${diff['workingDays']} days',
              ),
              BreakdownItem(
                label: 'Weekend Days (Sat-Sun)',
                value: '${diff['weekendDays']} days',
              ),
              BreakdownItem(
                label: 'Total Hours',
                value: NumberFormat('#,###').format(diff['totalHours']),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ModernTextField(
            label: 'Start Date',
            hintText: _displayFormat.format(_startDate),
            readOnly: true,
            prefixIcon: Icons.calendar_today_outlined,
            suffix: TextButton(
              onPressed: () => _pickDate(isStartDate: true),
              child: const Text('Change'),
            ),
            onTap: () => _pickDate(isStartDate: true),
          ),
          const SizedBox(height: 16),
          ModernTextField(
            label: 'End Date',
            hintText: _displayFormat.format(_endDate),
            readOnly: true,
            prefixIcon: Icons.event_outlined,
            suffix: TextButton(
              onPressed: () => _pickDate(isStartDate: false),
              child: const Text('Change'),
            ),
            onTap: () => _pickDate(isStartDate: false),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Include End Day in Count (+1)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: const Text('Add 1 day to include the final date itself'),
            value: _includeEndDay,
            activeColor: AppColors.primaryOrange,
            onChanged: (val) {
              PreferencesService().triggerHaptic();
              setState(() {
                _includeEndDay = val;
              });
            },
          ),
        ],
      ),
    );
  }
}
