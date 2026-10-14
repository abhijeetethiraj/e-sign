import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Service that processes an uploaded photo of a signature
/// and strips out the paper background to make it transparent.
///
/// Uses Otsu's method to automatically determine the best threshold
/// for each individual image — handles different paper colors,
/// lighting conditions, and ink colors.
class SignatureImageService {
  /// Takes raw image bytes (JPG or PNG) and returns transparent PNG bytes.
  ///
  /// **Algorithm:**
  /// 1. Decode the image and force-convert to uint8 RGBA.
  /// 2. Build a brightness histogram (count of pixels at each gray level).
  /// 3. Run Otsu's method on the histogram → optimal threshold.
  /// 4. Apply threshold: bright = transparent paper, dark = navy ink.
  /// 5. Encode as PNG.
  static Uint8List? removePaperBackground(Uint8List inputBytes) {
    // ──────────────────────────────────────────────────
    // STEP 1: Decode and force-convert to uint8 RGBA
    // ──────────────────────────────────────────────────
    final img.Image? decoded = img.decodeImage(inputBytes);
    if (decoded == null) {
      debugPrint('[SignatureService] Failed to decode image');
      return null;
    }

    final img.Image src = decoded.convert(
      format: img.Format.uint8,
      numChannels: 4,
    );

    final int w = src.width;
    final int h = src.height;
    final int totalPixels = w * h;

    debugPrint('[SignatureService] Image: ${w}x$h, '
        'format: ${src.format}, channels: ${src.numChannels}');

    // ──────────────────────────────────────────────────
    // STEP 2: Build brightness histogram
    // ──────────────────────────────────────────────────
    // A histogram is an array of 256 slots (one per gray level).
    // histogram[100] = how many pixels have brightness exactly 100.
    //
    // We also store each pixel's gray value so we don't compute it twice.
    final List<int> histogram = List.filled(256, 0);
    final List<int> grayValues = List.filled(totalPixels, 0);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final pixel = src.getPixel(x, y);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();

        // Weighted brightness (same luminance formula)
        final int gray = ((0.299 * r) + (0.587 * g) + (0.114 * b)).toInt();

        grayValues[y * w + x] = gray;
        histogram[gray]++;
      }
    }

    // Debug: show histogram peaks
    int minGray = 255, maxGray = 0;
    for (int i = 0; i < 256; i++) {
      if (histogram[i] > 0) {
        if (i < minGray) minGray = i;
        if (i > maxGray) maxGray = i;
      }
    }
    debugPrint('[SignatureService] Brightness range: $minGray – $maxGray');

    // ──────────────────────────────────────────────────
    // STEP 3: Otsu's method — find optimal threshold
    // ──────────────────────────────────────────────────
    final int autoThreshold = _otsuThreshold(histogram, totalPixels);
    debugPrint('[SignatureService] Otsu threshold: $autoThreshold');

    // ──────────────────────────────────────────────────
    // STEP 4: Apply threshold to create transparent image
    // ──────────────────────────────────────────────────
    final img.Image output = img.Image(
      width: w,
      height: h,
      numChannels: 4,
    );

    int paperCount = 0;
    int inkCount = 0;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int gray = grayValues[y * w + x];

        if (gray >= autoThreshold) {
          // PAPER → fully transparent
          output.setPixelRgba(x, y, 0, 0, 0, 0);
          paperCount++;
        } else {
          // INK → deep navy, fully opaque
          output.setPixelRgba(x, y, 20, 30, 55, 255);
          inkCount++;
        }
      }
    }

    debugPrint('[SignatureService] Paper: $paperCount, Ink: $inkCount, '
        'Paper ratio: ${(paperCount / totalPixels * 100).toStringAsFixed(1)}%');

    // ──────────────────────────────────────────────────
    // STEP 5: Encode to PNG
    // ──────────────────────────────────────────────────
    return Uint8List.fromList(img.encodePng(output));
  }

  /// ════════════════════════════════════════════════════
  /// OTSU'S METHOD
  /// ════════════════════════════════════════════════════
  ///
  /// Finds the threshold that maximally separates two groups
  /// (dark pixels = ink, bright pixels = paper) by maximizing
  /// the "between-class variance".
  ///
  /// **How it works:**
  /// 1. Try every possible threshold from 0 to 255.
  /// 2. For each threshold t, split all pixels into two groups:
  ///    - Background (gray < t): ink pixels
  ///    - Foreground (gray >= t): paper pixels
  /// 3. Calculate the mean brightness of each group.
  /// 4. The "between-class variance" measures how far apart
  ///    the two group means are, weighted by group sizes.
  /// 5. The threshold with the MAXIMUM variance = best separation.
  ///
  /// Think of it as finding the "biggest gap" between two clusters.
  static int _otsuThreshold(List<int> histogram, int totalPixels) {
    // Sum of ALL (brightness × count) across the entire image
    // This is like the total "brightness score"
    double sumTotal = 0;
    for (int i = 0; i < 256; i++) {
      sumTotal += i * histogram[i];
    }

    double sumBackground = 0;   // Running sum for the "dark" group
    int weightBackground = 0;   // Number of pixels in "dark" group

    double maxVariance = 0;     // Best separation score found so far
    int bestThreshold = 128;    // Default fallback if all pixels are same

    // Try every possible threshold from 0 to 255
    for (int t = 0; t < 256; t++) {
      // Add pixels at this gray level to the "dark" (background) group
      weightBackground += histogram[t];
      if (weightBackground == 0) continue; // No dark pixels yet, skip

      // Remaining pixels are the "bright" (foreground) group
      int weightForeground = totalPixels - weightBackground;
      if (weightForeground == 0) break; // All pixels are dark, done

      // Update running brightness sum for the dark group
      sumBackground += t * histogram[t];

      // Mean brightness of each group
      double meanBackground = sumBackground / weightBackground;
      double meanForeground = (sumTotal - sumBackground) / weightForeground;

      // Between-class variance:
      // How different are the two groups from each other?
      // Bigger = better separation = better threshold
      double variance = weightBackground.toDouble() *
          weightForeground.toDouble() *
          (meanBackground - meanForeground) *
          (meanBackground - meanForeground);

      if (variance > maxVariance) {
        maxVariance = variance;
        bestThreshold = t;
      }
    }

    return bestThreshold;
  }
}
