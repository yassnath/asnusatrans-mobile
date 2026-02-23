import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CvantDropdownField<T> extends StatelessWidget {
  const CvantDropdownField({
    super.key,
    this.initialValue,
    this.value,
    required this.items,
    required this.onChanged,
    this.decoration,
    this.hint,
    this.style,
    this.dropdownColor,
    this.isExpanded = true,
    this.icon,
    this.menuMaxHeight,
    this.borderRadius,
  });

  final T? initialValue;
  final T? value;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration? decoration;
  final Widget? hint;
  final TextStyle? style;
  final Color? dropdownColor;
  final bool isExpanded;
  final Widget? icon;
  final double? menuMaxHeight;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);
    final borderColor = AppColors.controlBorder(context);

    final resolvedDecoration = (decoration ?? const InputDecoration()).copyWith(
      filled: decoration?.filled ?? true,
      fillColor: decoration?.fillColor ?? AppColors.surfaceSoft(context),
      contentPadding: decoration?.contentPadding ??
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: decoration?.enabledBorder ??
          OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: borderColor),
          ),
      focusedBorder: decoration?.focusedBorder ??
          OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppColors.blue, width: 1.2),
          ),
      border: decoration?.border ??
          OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: borderColor),
          ),
    );

    final resolvedStyle = style ??
        TextStyle(
          color: AppColors.textPrimaryFor(context),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );

    return DropdownButtonFormField<T>(
      initialValue: value ?? initialValue,
      isExpanded: isExpanded,
      borderRadius: radius,
      menuMaxHeight: menuMaxHeight ?? 320,
      dropdownColor: dropdownColor ?? AppColors.surfaceSoft(context),
      icon: icon ??
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMutedFor(context),
            size: 20,
          ),
      decoration: resolvedDecoration,
      hint: hint,
      style: resolvedStyle,
      items: items,
      onChanged: onChanged,
    );
  }
}
