import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validation_utils.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

class TripExpenseItem {
  final String title;
  final double amount;
  final String paidBy;
  TripExpenseItem({required this.title, required this.amount, required this.paidBy});
}

class TipSplitScreen extends StatefulWidget {
  const TipSplitScreen({super.key});

  @override
  State<TipSplitScreen> createState() => _TipSplitScreenState();
}

class _TipSplitScreenState extends State<TipSplitScreen> {
  int _modeIndex = 0; // 0 = Restaurant / Quick Split, 1 = Group & Trip Splitter

  // 1. QUICK SPLIT
  final TextEditingController _billController = TextEditingController(text: '1200');
  final TextEditingController _customTipController = TextEditingController();
  double _tipPercent = 10;
  int _splitCount = 3;
  final List<double> _tipPresets = [0, 5, 10, 15, 18, 20];

  // 2. GROUP & TRIP SPLITTER
  final List<String> _tripMembers = ['Alice', 'Bob', 'Charlie'];
  final List<TripExpenseItem> _tripExpenses = [
    TripExpenseItem(title: 'Hotel Stay', amount: 240, paidBy: 'Alice'),
    TripExpenseItem(title: 'Rental Car & Fuel', amount: 150, paidBy: 'Bob'),
    TripExpenseItem(title: 'Dinner & Groceries', amount: 90, paidBy: 'Charlie'),
  ];
  final _newExpTitleCtrl = TextEditingController();
  final _newExpAmtCtrl = TextEditingController();
  String _newExpPayer = 'Alice';
  final _newMemberCtrl = TextEditingController();

  Map<String, double> _calculateSplit() {
    final bill = ValidationUtils.safeParseDouble(_billController.text);
    final tipAmount = bill * (_tipPercent / 100);
    final totalBill = bill + tipAmount;
    final count = _splitCount < 1 ? 1 : _splitCount;

    final perPersonTotal = totalBill / count;
    final perPersonTip = tipAmount / count;
    final perPersonBill = bill / count;

    return {
      'bill': bill,
      'tipAmount': tipAmount,
      'totalBill': totalBill,
      'perPersonTotal': perPersonTotal,
      'perPersonTip': perPersonTip,
      'perPersonBill': perPersonBill,
    };
  }

  Map<String, dynamic> _computeTripSettlement() {
    if (_tripMembers.isEmpty) {
      return {'total': '₹0.00', 'perPerson': '₹0.00', 'settlements': <String>[]};
    }
    double totalExp = 0.0;
    final Map<String, double> paidMap = {for (final m in _tripMembers) m: 0.0};

    for (final exp in _tripExpenses) {
      totalExp += exp.amount;
      paidMap[exp.paidBy] = (paidMap[exp.paidBy] ?? 0) + exp.amount;
    }

    final perPerson = totalExp / _tripMembers.length;
    final Map<String, double> netBalance = {};
    for (final m in _tripMembers) {
      netBalance[m] = (paidMap[m] ?? 0) - perPerson;
    }

    final List<MapEntry<String, double>> debtors = [];
    final List<MapEntry<String, double>> creditors = [];

    netBalance.forEach((name, bal) {
      if (bal < -0.01) {
        debtors.add(MapEntry(name, -bal));
      } else if (bal > 0.01) {
        creditors.add(MapEntry(name, bal));
      }
    });

    final List<String> settlements = [];
    int dIdx = 0, cIdx = 0;
    while (dIdx < debtors.length && cIdx < creditors.length) {
      final debtor = debtors[dIdx];
      final creditor = creditors[cIdx];
      final settleAmt = math.min(debtor.value, creditor.value);

      settlements.add('${debtor.key} pays ${creditor.key}: ₹${settleAmt.toStringAsFixed(2)}');

      debtors[dIdx] = MapEntry(debtor.key, debtor.value - settleAmt);
      creditors[cIdx] = MapEntry(creditor.key, creditor.value - settleAmt);

      if (debtors[dIdx].value <= 0.01) dIdx++;
      if (creditors[cIdx].value <= 0.01) cIdx++;
    }

    return {
      'total': '₹${totalExp.toStringAsFixed(2)}',
      'perPerson': '₹${perPerson.toStringAsFixed(2)}',
      'settlements': settlements,
    };
  }

  void _addMember() {
    final name = _newMemberCtrl.text.trim();
    if (name.isEmpty || _tripMembers.any((m) => m.toLowerCase() == name.toLowerCase())) return;
    setState(() {
      _tripMembers.add(name);
      _newMemberCtrl.clear();
    });
  }

  void _removeMember(String name) {
    if (_tripExpenses.any((e) => e.paidBy == name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete $name\'s expenses before removing them.')),
      );
      return;
    }
    setState(() {
      _tripMembers.remove(name);
      if (_newExpPayer == name && _tripMembers.isNotEmpty) {
        _newExpPayer = _tripMembers.first;
      }
    });
  }

  void _addExpense() {
    final title = _newExpTitleCtrl.text.trim();
    final amt = double.tryParse(_newExpAmtCtrl.text.trim());
    if (title.isEmpty || amt == null || amt <= 0) return;

    setState(() {
      _tripExpenses.add(TripExpenseItem(title: title, amount: amt, paidBy: _newExpPayer));
      _newExpTitleCtrl.clear();
      _newExpAmtCtrl.clear();
    });
  }

  @override
  void dispose() {
    _billController.dispose();
    _customTipController.dispose();
    _newExpTitleCtrl.dispose();
    _newExpAmtCtrl.dispose();
    _newMemberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Tip & Split Bill',
      category: ToolCategory.finance,
      toolId: 'tip_split_calc',
      onReset: () {
        setState(() {
          _billController.text = '1200';
          _customTipController.clear();
          _tipPercent = 10;
          _splitCount = 3;
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Quick Tip & Split'), icon: Icon(Icons.receipt_rounded)),
                ButtonSegment(value: 1, label: Text('Group & Trip Splitter'), icon: Icon(Icons.group_rounded)),
              ],
              selected: {_modeIndex},
              onSelectionChanged: (set) => setState(() => _modeIndex = set.first),
            ),
          ),
          const SizedBox(height: 16),
          if (_modeIndex == 0) _buildQuickSplitView(isDark) else _buildGroupSplitView(isDark),
        ],
      ),
    );
  }

  Widget _buildQuickSplitView(bool isDark) {
    final data = _calculateSplit();
    final currencyFmt = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Per Person Amount',
          primaryResult: currencyFmt.format(data['perPersonTotal']),
          subtitle: 'Split across $_splitCount people (incl. ${currencyFmt.format(data['perPersonTip'])} tip each)',
          accentColor: AppColors.catFinance,
          breakdowns: [
            BreakdownItem(
              label: 'Total with Tip',
              value: currencyFmt.format(data['totalBill']),
            ),
            BreakdownItem(
              label: 'Total Tip (${_tipPercent == _tipPercent.roundToDouble() ? _tipPercent.toInt() : _tipPercent}%)',
              value: currencyFmt.format(data['tipAmount']),
            ),
            BreakdownItem(
              label: 'Base Per Person',
              value: currencyFmt.format(data['perPersonBill']),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ModernTextField(
          label: 'Total Bill Amount',
          controller: _billController,
          hintText: '1200',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixText: '₹',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        const Text(
          'Select Tip Percentage',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tipPresets.map((tip) {
            final isSelected = _tipPercent == tip && _customTipController.text.isEmpty;
            return ChoiceChip(
              label: Text('${tip.toInt()}%'),
              selected: isSelected,
              selectedColor: AppColors.catFinance,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (val) {
                if (val) {
                  PreferencesService().triggerHaptic();
                  setState(() {
                    _customTipController.clear();
                    _tipPercent = tip;
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        ModernTextField(
          label: 'Custom Tip (%)',
          controller: _customTipController,
          hintText: 'e.g. 12.5',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          suffixText: '%',
          onChanged: (v) => setState(() {
            if (v.trim().isNotEmpty) _tipPercent = ValidationUtils.safeParseDouble(v).clamp(0.0, 100.0);
          }),
        ),
        const SizedBox(height: 24),
        Text(
          'Split Among People'.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    const Icon(Icons.people_outline_rounded, size: 22),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        '$_splitCount ${_splitCount == 1 ? 'Person' : 'People'}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.darkCard : AppColors.lightCardHover,
                      ),
                      child: const Icon(Icons.remove, size: 18),
                    ),
                    onPressed: _splitCount > 1
                        ? () {
                            PreferencesService().triggerHaptic();
                            setState(() => _splitCount--);
                          }
                        : null,
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.darkCard : AppColors.lightCardHover,
                      ),
                      child: const Icon(Icons.add, size: 18),
                    ),
                    onPressed: () {
                      PreferencesService().triggerHaptic();
                      setState(() => _splitCount++);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupSplitView(bool isDark) {
    final trip = _computeTripSettlement();
    final settlements = trip['settlements'] as List<String>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultCard(
          title: 'Group Total & Per-Person Cost',
          primaryResult: trip['perPerson'] as String,
          subtitle: 'Each person\'s fair share (Total: ${trip['total']})',
          accentColor: AppColors.catFinance,
        ),
        const SizedBox(height: 16),
        const Text('Trip & Group Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _tripMembers.map((m) {
            return Chip(
              label: Text(m),
              deleteIcon: const Icon(Icons.close_rounded, size: 16),
              onDeleted: _tripMembers.length > 2 ? () => _removeMember(m) : null,
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: ModernTextField(label: 'Add Member', controller: _newMemberCtrl)),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _addMember, icon: const Icon(Icons.add_rounded)),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Group Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(flex: 3, child: ModernTextField(label: 'Expense Title', controller: _newExpTitleCtrl)),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: ModernTextField(label: 'Amount (₹)', controller: _newExpAmtCtrl, keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Paid By: ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _tripMembers.contains(_newExpPayer) ? _newExpPayer : (_tripMembers.isNotEmpty ? _tripMembers.first : null),
              items: _tripMembers.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _newExpPayer = v);
              },
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _addExpense,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('Add Expense'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._tripExpenses.asMap().entries.map((entry) {
          final idx = entry.key;
          final exp = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text(exp.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Paid by ${exp.paidBy}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('₹${exp.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                    onPressed: () => setState(() => _tripExpenses.removeAt(idx)),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        const Text('Recommended Debt Settlements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        if (settlements.isEmpty)
          const Text('All expenses are perfectly settled! Nobody owes anything.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
        else
          ...settlements.map((s) => Card(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz_rounded, color: AppColors.catFinance, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}
