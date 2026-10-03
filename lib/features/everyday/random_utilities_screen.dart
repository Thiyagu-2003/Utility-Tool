import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/modern_text_field.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum EverydayTab {
  random('Random Number'),
  dice('Dice Roller'),
  coin('Coin Toss');

  final String label;
  const EverydayTab(this.label);
}

class RandomUtilitiesScreen extends StatefulWidget {
  const RandomUtilitiesScreen({super.key});

  @override
  State<RandomUtilitiesScreen> createState() => _RandomUtilitiesScreenState();
}

class _RandomUtilitiesScreenState extends State<RandomUtilitiesScreen> {
  EverydayTab _activeTab = EverydayTab.random;

  // Random Number state
  final TextEditingController _minController = TextEditingController(text: '1');
  final TextEditingController _maxController = TextEditingController(text: '100');
  String _randomNumberResult = '42';

  // Dice Roller state
  int _diceCount = 1;
  List<int> _diceResults = [6];

  // Coin Toss state
  String _coinResult = 'Heads';
  int _headsCount = 0;
  int _tailsCount = 0;

  final math.Random _random = math.Random();

  void _generateRandomNumber() {
    PreferencesService().triggerHaptic();
    final min = int.tryParse(_minController.text.trim()) ?? 1;
    final max = int.tryParse(_maxController.text.trim()) ?? 100;
    if (min >= max) {
      setState(() => _randomNumberResult = min.toString());
      return;
    }
    final res = min + _random.nextInt(max - min + 1);
    setState(() => _randomNumberResult = res.toString());
  }

  void _rollDice() {
    PreferencesService().triggerHaptic();
    setState(() {
      _diceResults = List.generate(_diceCount, (_) => 1 + _random.nextInt(6));
    });
  }

  void _tossCoin() {
    PreferencesService().triggerHaptic();
    final isHeads = _random.nextBool();
    setState(() {
      _coinResult = isHeads ? 'Heads' : 'Tails';
      if (isHeads) {
        _headsCount++;
      } else {
        _tailsCount++;
      }
    });
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Random & Decision Tools',
      category: ToolCategory.everyday,
      toolId: 'random_utilities',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: EverydayTab.values.map((tab) {
                final isSelected = tab == _activeTab;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(tab.label),
                    selected: isSelected,
                    selectedColor: AppColors.catEveryday,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) {
                      if (val) {
                        PreferencesService().triggerHaptic();
                        setState(() => _activeTab = tab);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Random Number Section
          if (_activeTab == EverydayTab.random) ...[
            ResultCard(
              title: 'Generated Number',
              primaryResult: _randomNumberResult,
              subtitle: 'Range: ${_minController.text} to ${_maxController.text}',
              accentColor: AppColors.catEveryday,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ModernTextField(
                    label: 'Min Value',
                    controller: _minController,
                    hintText: '1',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ModernTextField(
                    label: 'Max Value',
                    controller: _maxController,
                    hintText: '100',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.casino_rounded),
                label: const Text('Generate Number'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catEveryday,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _generateRandomNumber,
              ),
            ),
          ],

          // Dice Roller Section
          if (_activeTab == EverydayTab.dice) ...[
            ResultCard(
              title: 'Total Dice Sum',
              primaryResult: _diceResults.reduce((a, b) => a + b).toString(),
              subtitle: 'Rolled ${_diceResults.length} dice: ${_diceResults.join(", ")}',
              accentColor: AppColors.catEveryday,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _diceResults.map((die) {
                return Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.catEveryday, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.catEveryday.withOpacity(0.15),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    die.toString(),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Dice count: ', style: TextStyle(fontWeight: FontWeight.bold)),
                ...[1, 2, 3, 4].map((c) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Text('$c'),
                      selected: _diceCount == c,
                      selectedColor: AppColors.catEveryday,
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _diceCount = c;
                            _rollDice();
                          });
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Roll Dice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catEveryday,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _rollDice,
              ),
            ),
          ],

          // Coin Toss Section
          if (_activeTab == EverydayTab.coin) ...[
            ResultCard(
              title: 'Coin Result',
              primaryResult: _coinResult,
              subtitle: 'Lifetime: $_headsCount Heads • $_tailsCount Tails',
              accentColor: AppColors.catEveryday,
              breakdowns: [
                BreakdownItem(label: 'Total Heads', value: _headsCount.toString()),
                BreakdownItem(label: 'Total Tails', value: _tailsCount.toString()),
              ],
            ),
            const SizedBox(height: 30),
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.catEveryday.withOpacity(0.15),
                  border: Border.all(color: AppColors.catEveryday, width: 3),
                ),
                alignment: Alignment.center,
                child: Text(
                  _coinResult == 'Heads' ? '🪙 H' : '🪙 T',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.monetization_on_rounded),
                label: const Text('Flip Coin'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.catEveryday,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _tossCoin,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
