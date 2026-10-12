import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

/// Builds a password of [length] from [sets] using a CSPRNG, guaranteeing at
/// least one character from every non-empty set. Returns '' when no set is given.
String generateSecurePassword(int length, List<String> sets, {math.Random? random}) {
  final active = sets.where((s) => s.isNotEmpty).toList();
  if (active.isEmpty || length <= 0) return '';
  final rng = random ?? math.Random.secure();
  final pool = active.join();
  final chars = List.generate(length, (_) => pool[rng.nextInt(pool.length)]);
  for (var i = 0; i < active.length && i < length; i++) {
    chars[i] = active[i][rng.nextInt(active[i].length)];
  }
  chars.shuffle(rng);
  return chars.join();
}

/// Entropy in bits of a uniformly random password: length * log2(poolSize).
double passwordEntropyBits(int length, int poolSize) =>
    poolSize <= 1 || length <= 0 ? 0 : length * math.log(poolSize) / math.ln2;

String passwordStrengthLabel(double bits) {
  if (bits < 40) return 'Weak';
  if (bits < 60) return 'Moderate';
  if (bits < 80) return 'Strong';
  return 'Very Strong';
}

class PasswordGeneratorScreen extends StatefulWidget {
  const PasswordGeneratorScreen({super.key});

  @override
  State<PasswordGeneratorScreen> createState() => _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> {
  int _length = 16;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSymbols = true;
  String _generatedPassword = '';
  int _poolSize = 0;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    PreferencesService().triggerHaptic();

    const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lower = 'abcdefghijklmnopqrstuvwxyz';
    const nums = '0123456789';
    const syms = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

    final sets = [
      if (_includeUppercase) upper,
      if (_includeLowercase) lower,
      if (_includeNumbers) nums,
      if (_includeSymbols) syms,
    ];
    _poolSize = sets.join().length;

    if (sets.isEmpty) {
      setState(() => _generatedPassword = 'Select at least one set');
      return;
    }

    setState(() {
      _generatedPassword = generateSecurePassword(_length, sets);
    });
  }

  double get _entropy => passwordEntropyBits(_length, _poolSize);

  String _getStrengthLabel() => passwordStrengthLabel(_entropy);

  Color _getStrengthColor() {
    final bits = _entropy;
    if (bits < 40) return const Color(0xFFEF4444);
    if (bits < 60) return const Color(0xFFF59E0B);
    if (bits < 80) return const Color(0xFF10B981);
    return const Color(0xFF14B8A6);
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Password Generator & Security',
      category: ToolCategory.security,
      toolId: 'password_generator',
      onReset: () {
        _length = 16;
        _includeUppercase = true;
        _includeLowercase = true;
        _includeNumbers = true;
        _includeSymbols = true;
        _generate();
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: 'Generated Password',
            primaryResult: _generatedPassword,
            subtitle: 'Security Strength: ${_getStrengthLabel()} (~${_entropy.round()} bits entropy)',
            accentColor: _getStrengthColor(),
            breakdowns: [
              BreakdownItem(label: 'Password Length', value: '$_length Chars'),
              BreakdownItem(label: 'Strength Rating', value: _getStrengthLabel()),
              BreakdownItem(label: 'Special Symbols', value: _includeSymbols ? 'Active' : 'Off'),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy Password'),
              onPressed: _poolSize == 0
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: _generatedPassword));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password copied!')));
                    },
            ),
          ),
          const SizedBox(height: 12),

          // Length slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(child: Text('Password Length', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$_length characters', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14B8A6))),
              ),
            ],
          ),
          Slider(
            value: _length.toDouble(),
            min: 4,
            max: 64,
            divisions: 60,
            activeColor: const Color(0xFF14B8A6),
            onChanged: (val) {
              _length = val.round();
              _generate();
            },
          ),
          const SizedBox(height: 16),

          // Character types checkboxes
          SwitchListTile(
            title: const Text('Uppercase Letters (A-Z)'),
            value: _includeUppercase,
            activeThumbColor: const Color(0xFF14B8A6),
            onChanged: (v) {
              _includeUppercase = v;
              _generate();
            },
          ),
          SwitchListTile(
            title: const Text('Lowercase Letters (a-z)'),
            value: _includeLowercase,
            activeThumbColor: const Color(0xFF14B8A6),
            onChanged: (v) {
              _includeLowercase = v;
              _generate();
            },
          ),
          SwitchListTile(
            title: const Text('Numbers (0-9)'),
            value: _includeNumbers,
            activeThumbColor: const Color(0xFF14B8A6),
            onChanged: (v) {
              _includeNumbers = v;
              _generate();
            },
          ),
          SwitchListTile(
            title: const Text('Special Symbols (!@#\$)'),
            value: _includeSymbols,
            activeThumbColor: const Color(0xFF14B8A6),
            onChanged: (v) {
              _includeSymbols = v;
              _generate();
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Generate New Password'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14B8A6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _generate,
            ),
          ),
        ],
      ),
    );
  }
}
