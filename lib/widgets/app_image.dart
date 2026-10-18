import 'dart:convert';

import 'package:flutter/material.dart';

class AppImage extends StatelessWidget {
  final String path;
  final String base64Data;
  final BoxFit fit;

  const AppImage({
    super.key,
    required this.path,
    this.base64Data = '',
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (base64Data.isNotEmpty) {
      try {
        final value = base64Data.startsWith('data:')
            ? base64Data.substring(base64Data.indexOf(',') + 1)
            : base64Data;
        return Image.memory(
          base64Decode(value),
          fit: fit,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
        );
      } catch (_) {
        return const Icon(Icons.broken_image_outlined);
      }
    }
    if (path.isEmpty) return const Icon(Icons.broken_image_outlined);
    return Image.network(
      path,
      fit: fit,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
    );
  }
}
