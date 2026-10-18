import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';

/// Search Bar Widget
class AppSearchBar extends StatelessWidget {
  final FocusNode? focusNode;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final bool showClose;
  final String? hintText;

  const AppSearchBar(
      {super.key,
      required this.controller,
      required this.onChanged,
      required this.onClose,
      this.showClose = true,
      this.hintText,
      this.focusNode});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16162A) : const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onTapOutside: (_) {
          FocusScope.of(context).unfocus();
        },
        style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText ?? loc.get('search_invoice'),
          hintStyle: TextStyle(
              color:
                  isDark ? const Color(0xFF6666AA) : const Color(0xFF9999AA)),
          prefixIcon: Icon(Icons.search_rounded,
              color: isDark ? const Color(0xFF6666AA) : const Color(0xFF9999AA),
              size: 20),
          suffixIcon: showClose
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    controller.clear();
                    onClose();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
