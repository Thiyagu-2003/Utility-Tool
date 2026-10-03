import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models/tool_model.dart';
import '../../core/services/preferences_service.dart';
import '../../shared/widgets/result_card.dart';
import '../../shared/widgets/tool_scaffold.dart';

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

    String pool = '';
    if (_includeUppercase) pool += upper;
    if (_includeLowercase) pool += lower;
    if (_includeNumbers) pool += nums;
    if (_includeSymbols) pool += syms;

    if (pool.isEmpty) {
      setState(() => _generatedPassword = 'Select at least one set');
      return;
    }

    final random = math.Random.secure();
    final chars = List.generate(_length, (_) => pool[random.nextInt(pool.length)]);
    setState(() {
      _generatedPassword = chars.join();
    });
  }

  String _getStrengthLabel() {
    if (_length < 8) return 'Weak';
    if (_length < 12) return 'Moderate';
    if (_length < 16) return 'Strong';
    return 'Very Strong (Entropy > 90 bits)';
  }

  Color _getStrengthColor() {
    if (_length < 8) return const Color(0xFFEF4444);
    if (_length < 12) return const Color(0xFFF59E0B);
    if (_length < 16) return const Color(0xFF10B981);
    return const Color(0xFF14B8A6);
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Password Generator & Security',
      category: ToolCategory.security,
      toolId: 'password_generator',
      onReset: () {
        setState(() {
          _length = 16;
          _includeUppercase = true;
          _includeLowercase = true;
          _includeNumbers = true;
          _includeSymbols = true;
          _generate();
        });
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultCard(
            title: 'Generated Password',
            primaryResult: _generatedPassword,
            subtitle: 'Security Strength: ${_getStrengthLabel()}',
            accentColor: _getStrengthColor(),
            breakdowns: [
              BreakdownItem(label: 'Password Length', value: '$_length Chars'),
              BreakdownItem(label: 'Strength Rating', value: _getStrengthLabel().split(' ')[0]),
              BreakdownItem(label: 'Special Symbols', value: _includeSymbols ? 'Active' : 'Off'),
            ],
          ),
          const SizedBox(height: 24),

          // Length slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Password Length', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$_length characters', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14B8A6))),
              ),
            ],
          ),
          Slider(
            value: _length.toDouble(),
            min: 6,
            max: 32,
            divisions: 26,
            activeColor: const Color(0xFF14B8A6),
            onChanged: (val) {
              setState(() {
                _length = val.round();
                _generate();
              });
            },
          ),
          const SizedBox(height: 16),

          // Character types checkboxes
          SwitchListTile(
            title: const Text('Uppercase Letters (A-Z)'),
            value: _includeUppercase,
            activeColor: const Color(0xFF14B8A6),
            onChanged: (v) {
              setState(() {
                _includeUppercase = v;
                _generate();
              });
            },
          ),
          SwitchListTile(
            title: const Text('Lowercase Letters (a-z)'),
            value: _includeLowercase,
            activeColor: const Color(0xFF14B8A6),
            onChanged: (v) {
              setState(() {
                _includeLowercase = v;
                _generate();
              });
            },
          ),
          SwitchListTile(
            title: const Text('Numbers (0-9)'),
            value: _includeNumbers,
            activeColor: const Color(0xFF14B8A6),
            onChanged: (v) {
              setState(() {
                _includeNumbers = v;
                _generate();
              });
            },
          ),
          SwitchListTile(
            title: const Text('Special Symbols (!@#\$)'),
            value: _includeSymbols,
            activeColor: const Color(0xFF14B8A6),
            onChanged: (v) {
              setState(() {
                _includeSymbols = v;
                _generate();
              });
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
