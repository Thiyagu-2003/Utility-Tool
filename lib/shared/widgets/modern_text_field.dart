import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ModernTextField extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final Widget? prefix;
  final IconData? prefixIcon;
  final String? prefixText;
  final Widget? suffix;
  final String? suffixText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final int maxLines;

  const ModernTextField({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.prefix,
    this.prefixIcon,
    this.prefixText,
    this.suffix,
    this.suffixText,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget? leadingWidget = prefix;
    if (leadingWidget == null && prefixIcon != null) {
      leadingWidget = Icon(
        prefixIcon,
        size: 20,
        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      );
    } else if (leadingWidget == null && prefixText != null) {
      leadingWidget = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          prefixText!,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightCardHover,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            maxLines: maxLines,
            onChanged: onChanged,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                fontSize: 15,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: leadingWidget,
              prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              suffix: suffix,
              suffixText: suffixText,
              suffixStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
