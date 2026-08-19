import 'package:flutter/material.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';

class AppSearchBar extends StatelessWidget {
  final String hint;
  final VoidCallback? onTap;
  final bool readOnly;
  final TextEditingController? controller;
  final void Function(String)? onChanged;
  final IconData leadingIcon;
  final Widget? trailing;

  const AppSearchBar({
    super.key,
    required this.hint,
    this.onTap,
    this.readOnly = true,
    this.controller,
    this.onChanged,
    this.leadingIcon = Icons.search_rounded,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TaxiColors.lightBorder.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(leadingIcon, color: scheme.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: readOnly
                    ? Text(hint, style: Theme.of(context).textTheme.bodyMedium)
                    : TextField(
                        controller: controller,
                        onChanged: onChanged,
                        decoration: InputDecoration(
                          hintText: hint,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
