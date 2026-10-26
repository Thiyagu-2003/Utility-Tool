import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/tool_scaffold.dart';

enum EverydayTab {
  random('Random Number', Icons.tag_rounded),
  dice('Dice Roller', Icons.grid_view_rounded),
  coin('Coin Toss', Icons.monetization_on_rounded);

  final String label;
  final IconData icon;
  const EverydayTab(this.label, this.icon);
}

/// Uniform random integer in [a, b] (either order). Random.nextInt only takes
/// ranges up to 2^32, so wider ranges fall back to nextDouble.
int randomIntInRange(math.Random random, int a, int b) {
  final lo = math.min(a, b);
  final span = math.max(a, b) - lo + 1;
  if (span <= 0) return lo; // overflowed int64; nothing sensible to pick from
  if (span <= 1 << 32) return lo + random.nextInt(span);
  return lo + (random.nextDouble() * span).floor();
}

class RandomUtilitiesScreen extends StatefulWidget {
  const RandomUtilitiesScreen({super.key});

  @override
  State<RandomUtilitiesScreen> createState() => _RandomUtilitiesScreenState();
}

class _RandomUtilitiesScreenState extends State<RandomUtilitiesScreen>
    with SingleTickerProviderStateMixin {
  EverydayTab _activeTab = EverydayTab.random;

  // Random Number state
  final TextEditingController _minController = TextEditingController(text: '1');
  final TextEditingController _maxController =
      TextEditingController(text: '100');
  String _randomNumberResult = '42';
  final List<String> _recentNumbers = ['17', '88', '42', '5', '63'];

  // Dice Roller state
  int _diceCount = 2;
  int _selectedSides = 6;
  List<int> _diceResults = [4, 3];
  final List<String> _recentDice = ['7', '11', '4', '9', '12'];

  // Coin Toss state
  String _coinResult = 'Heads';
  int _headsCount = 6;
  int _tailsCount = 4;
  final List<String> _recentCoins = ['H', 'T', 'H', 'H', 'T'];

  final math.Random _random = math.Random();

  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _generateRandomNumber() {
    PreferencesService().triggerHaptic();
    final min = int.tryParse(_minController.text.trim()) ?? 1;
    final max = int.tryParse(_maxController.text.trim()) ?? 100;
    final res = randomIntInRange(_random, min, max);

    _animController.forward(from: 0.0);
    setState(() {
      _randomNumberResult = res.toString();
      _recentNumbers.insert(0, _randomNumberResult);
      if (_recentNumbers.length > 5) {
        _recentNumbers.removeLast();
      }
    });
  }

  void _rollDice() {
    PreferencesService().triggerHaptic();
    _animController.forward(from: 0.0);
    setState(() {
      _diceResults = List.generate(
        _diceCount,
        (_) => 1 + _random.nextInt(_selectedSides),
      );
      final sum = _diceResults.fold<int>(0, (a, b) => a + b);
      _recentDice.insert(0, sum.toString());
      if (_recentDice.length > 5) {
        _recentDice.removeLast();
      }
    });
  }

  void _tossCoin() {
    PreferencesService().triggerHaptic();
    final isHeads = _random.nextBool();
    _animController.forward(from: 0.0);
    setState(() {
      _coinResult = isHeads ? 'Heads' : 'Tails';
      if (isHeads) {
        _headsCount++;
      } else {
        _tailsCount++;
      }
      _recentCoins.insert(0, isHeads ? 'H' : 'T');
      if (_recentCoins.length > 5) {
        _recentCoins.removeLast();
      }
    });
  }

  void _copyToClipboard(String text, String description) {
    PreferencesService().triggerHaptic();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$description copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ToolScaffold(
      title: 'Random & Decision',
      subtitle: _activeTab.label,
      category: ToolCategory.moreTools,
      toolId: 'random_utilities',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented Navigation Pill Bar
          _buildSegmentedTabSelector(isDark),
          const SizedBox(height: 20),

          // Main Hero Dark Navy Card
          _buildHeroDisplayCard(isDark),
          const SizedBox(height: 22),

          // Tab-specific controls (Inputs / Selectors)
          if (_activeTab == EverydayTab.random)
            _buildRandomNumberControls(isDark),
          if (_activeTab == EverydayTab.dice)
            _buildDiceRollerControls(isDark),
          if (_activeTab == EverydayTab.coin)
            _buildCoinTossControls(isDark),

          const SizedBox(height: 22),

          // Large Vibrant Orange Action Button
          _buildActionButton(),

          const SizedBox(height: 24),

          // Recent Results History Section
          _buildRecentSection(isDark),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabSelector(bool isDark) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE6EAF2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildTabItem(EverydayTab.random, 'Number', Icons.tag_rounded, isDark),
          _buildTabItem(EverydayTab.dice, 'Dice', Icons.grid_view_rounded, isDark),
          _buildTabItem(
            EverydayTab.coin,
            'Coin',
            Icons.monetization_on_rounded,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(
    EverydayTab tab,
    String label,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _activeTab == tab;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_activeTab != tab) {
            PreferencesService().triggerHaptic();
            setState(() => _activeTab = tab);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0F172A)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569)),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroDisplayCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Signature midnight navy card
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Title + Copy Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getCardHeaderTitle(),
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              GestureDetector(
                onTap: _handleCopy,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.2,
                    ),
                  ),
                  child: const Text(
                    'Copy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Center Dynamic Content
          if (_activeTab == EverydayTab.random) _buildRandomNumberHero(),
          if (_activeTab == EverydayTab.dice) _buildDiceRollerHero(),
          if (_activeTab == EverydayTab.coin) _buildCoinTossHero(),
        ],
      ),
    );
  }

  String _getCardHeaderTitle() {
    switch (_activeTab) {
      case EverydayTab.random:
        return 'GENERATED NUMBER';
      case EverydayTab.dice:
        return 'TOTAL';
      case EverydayTab.coin:
        return 'RESULT';
    }
  }

  void _handleCopy() {
    switch (_activeTab) {
      case EverydayTab.random:
        _copyToClipboard(_randomNumberResult, 'Generated number');
        break;
      case EverydayTab.dice:
        final sum = _diceResults.fold<int>(0, (a, b) => a + b);
        _copyToClipboard(sum.toString(), 'Dice total');
        break;
      case EverydayTab.coin:
        _copyToClipboard(_coinResult, 'Coin result');
        break;
    }
  }

  Widget _buildRandomNumberHero() {
    return Column(
      children: [
        ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(_animation),
          child: Text(
            _randomNumberResult,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 90,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1.5,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7.5),
          decoration: BoxDecoration(
            color: const Color(0xFFFBBF24), // Vibrant Amber 400
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Range ${_minController.text} to ${_maxController.text}',
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDiceRollerHero() {
    final sum = _diceResults.fold<int>(0, (a, b) => a + b);
    final formulaText = _diceResults.length > 1
        ? '${_diceResults.join(" + ")} = $sum'
        : '$sum';

    return Column(
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final angle = math.sin(_animation.value * math.pi) * 0.08;
            return Transform.rotate(
              angle: angle,
              child: child,
            );
          },
          child: Wrap(
            spacing: 16,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: _diceResults.map((die) {
              final dieSize = _diceResults.length > 2 ? 64.0 : 80.0;
              return DiceFaceView(
                value: die,
                sides: _selectedSides,
                size: dieSize,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7.5),
          decoration: BoxDecoration(
            color: const Color(0xFFFBBF24), // Vibrant Amber 400
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            formulaText,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCoinTossHero() {
    final isHeads = _coinResult == 'Heads';

    return Column(
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final rotationVal = _animation.value * math.pi * 2;
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateY(rotationVal),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: Container(
            width: 114,
            height: 114,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFBBF24), // Amber 400
              border: Border.all(
                color: const Color(0xFFF59E0B), // Amber 500 edge
                width: 6,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              isHeads ? 'H' : 'T',
              style: const TextStyle(
                fontSize: 54,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
                height: 1.0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 7.5),
          decoration: BoxDecoration(
            color: const Color(0xFFFBBF24),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _coinResult,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // --- Random Number Inputs ---
  Widget _buildRandomNumberControls(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MIN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              _buildInputContainer(
                isDark,
                TextField(
                  controller: _minController,
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MAX',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              _buildInputContainer(
                isDark,
                TextField(
                  controller: _maxController,
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Dice Roller Controls ---
  Widget _buildDiceRollerControls(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DICE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark
                ? AppColors.darkTextSecondary
                : const Color(0xFF64748B),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [1, 2, 3, 4].map((count) {
            final isSelected = _diceCount == count;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: GestureDetector(
                  onTap: () {
                    PreferencesService().triggerHaptic();
                    setState(() {
                      _diceCount = count;
                      _diceResults = List.generate(
                        _diceCount,
                        (_) => 1 + _random.nextInt(_selectedSides),
                      );
                    });
                  },
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0F172A)
                          : (isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        Text(
          'SIDES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark
                ? AppColors.darkTextSecondary
                : const Color(0xFF64748B),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [6, 8, 12, 20].map((sides) {
            final isSelected = _selectedSides == sides;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: GestureDetector(
                  onTap: () {
                    PreferencesService().triggerHaptic();
                    setState(() {
                      _selectedSides = sides;
                      _diceResults = List.generate(
                        _diceCount,
                        (_) => 1 + _random.nextInt(_selectedSides),
                      );
                    });
                  },
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0F172A)
                          : (isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : const Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                    ),
                    child: Text(
                      'D$sides',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? Colors.white
                                : const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- Coin Toss Metrics ---
  Widget _buildCoinTossControls(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HEADS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              _buildInputContainer(
                isDark,
                Text(
                  '$_headsCount',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TAILS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : const Color(0xFF64748B),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              _buildInputContainer(
                isDark,
                Text(
                  '$_tailsCount',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputContainer(bool isDark, Widget child) {
    return Container(
      height: 58,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: child,
    );
  }

  // --- Orange Action Button ---
  Widget _buildActionButton() {
    IconData icon;
    String label;
    VoidCallback onTap;

    switch (_activeTab) {
      case EverydayTab.random:
        icon = Icons.tag_rounded;
        label = 'Generate Number';
        onTap = _generateRandomNumber;
        break;
      case EverydayTab.dice:
        icon = Icons.grid_view_rounded;
        label = 'Roll Dice';
        onTap = _rollDice;
        break;
      case EverydayTab.coin:
        icon = Icons.monetization_on_rounded;
        label = 'Toss Coin';
        onTap = _tossCoin;
        break;
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF97316), // Vivid Orange #F97316
          foregroundColor: const Color(0xFF111827),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: const Color(0xFF111827)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Recent Results Section ---
  Widget _buildRecentSection(bool isDark) {
    List<String> items;
    switch (_activeTab) {
      case EverydayTab.random:
        items = _recentNumbers;
        break;
      case EverydayTab.dice:
        items = _recentDice;
        break;
      case EverydayTab.coin:
        items = _recentCoins;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark
                ? AppColors.darkTextSecondary
                : const Color(0xFF64748B),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: items.map((val) {
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE6EAF2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    val,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Custom Dice Renderer that draws crisp authentic dice faces
class DiceFaceView extends StatelessWidget {
  final int value;
  final int sides;
  final double size;

  const DiceFaceView({
    super.key,
    required this.value,
    this.sides = 6,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    if (sides != 6 || value < 1 || value > 6) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0F172A),
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'D$sides',
                style: TextStyle(
                  fontSize: size * 0.16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Standard D6 die with authentic pips (dots)
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _DicePipPainter(value),
      ),
    );
  }
}

class _DicePipPainter extends CustomPainter {
  final int value;
  _DicePipPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final dotRadius = size.width * 0.125;
    final left = dotRadius;
    final mid = size.width / 2;
    final right = size.width - dotRadius;
    final top = dotRadius;
    final bottom = size.height - dotRadius;

    void draw(double x, double y) {
      canvas.drawCircle(Offset(x, y), dotRadius, paint);
    }

    switch (value) {
      case 1:
        draw(mid, mid);
        break;
      case 2:
        draw(left, top);
        draw(right, bottom);
        break;
      case 3:
        draw(left, top);
        draw(mid, mid);
        draw(right, bottom);
        break;
      case 4:
        draw(left, top);
        draw(right, top);
        draw(left, bottom);
        draw(right, bottom);
        break;
      case 5:
        draw(left, top);
        draw(right, top);
        draw(mid, mid);
        draw(left, bottom);
        draw(right, bottom);
        break;
      case 6:
        draw(left, top);
        draw(left, mid);
        draw(left, bottom);
        draw(right, top);
        draw(right, mid);
        draw(right, bottom);
        break;
    }
  }

  @override
  bool shouldRepaint(_DicePipPainter oldDelegate) => oldDelegate.value != value;
}
