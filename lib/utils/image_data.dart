import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Creates compact JPEG images suitable for storing as Base64 in Firestore.
class ImageData {
  static const int maxEncodedImageBytes = 256 * 1024;

  static Uint8List compressForFirestore(Uint8List source) {
    final decoded = img.decodeImage(source);
    if (decoded == null) {
      throw const FormatException('Format gambar tidak dapat dibaca.');
    }

    var longestSide =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longestSide > 512) longestSide = 512;

    while (true) {
      final maxOriginalSide =
          decoded.width > decoded.height ? decoded.width : decoded.height;
      final effectiveScale = longestSide / maxOriginalSide;
      final width = (decoded.width * effectiveScale).round().clamp(1, 512);
      final height = (decoded.height * effectiveScale).round().clamp(1, 512);
      final resized = img.copyResize(decoded, width: width, height: height);

      for (final quality in [72, 58, 44, 32]) {
        final jpg = Uint8List.fromList(
          img.encodeJpg(resized, quality: quality),
        );
        if (jpg.length <= maxEncodedImageBytes) return jpg;
      }

      if (longestSide <= 160) {
        throw StateError(
          'Ukuran gambar masih terlalu besar setelah diperkecil. Pilih gambar lain.',
        );
      }
      longestSide = (longestSide * 0.75).round();
    }
  }
}
