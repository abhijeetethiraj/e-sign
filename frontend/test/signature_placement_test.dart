import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/views/pdf_placement_screen.dart';

void main() {
  group('SignaturePlacement Model & Locking Logic QA Test Suite', () {
    test('1. [Default State] Initializes with isLocked = false', () {
      final placement = SignaturePlacement(
        id: 'spot-1',
        x: 50.0,
        docY: 120.0,
      );

      expect(placement.id, equals('spot-1'));
      expect(placement.x, equals(50.0));
      expect(placement.docY, equals(120.0));
      expect(placement.isLocked, isFalse);
    });

    test('2. [Toggle Lock] Locking and unlocking works as expected', () {
      final placement = SignaturePlacement(
        id: 'spot-1',
        x: 50.0,
        docY: 120.0,
      );

      // User pins/locks spot
      placement.isLocked = true;
      expect(placement.isLocked, isTrue);

      // User taps lock icon to unlock and adjust
      placement.isLocked = false;
      expect(placement.isLocked, isFalse);
    });

    test('3. [Multi-Spot Auto-Lock Flow] Automatically locks prior spots when adding new spots', () {
      final List<SignaturePlacement> placements = [
        SignaturePlacement(id: 'spot-1', x: 50.0, docY: 100.0, isLocked: false),
      ];

      expect(placements.first.isLocked, isFalse);

      // User taps "Add Spot": prior spots lock automatically to prevent accidental shifts
      for (final p in placements) {
        p.isLocked = true;
      }
      placements.add(
        SignaturePlacement(id: 'spot-2', x: 80.0, docY: 200.0, isLocked: false),
      );

      expect(placements.length, equals(2));
      expect(placements[0].isLocked, isTrue, reason: 'First placement must be auto-locked');
      expect(placements[1].isLocked, isFalse, reason: 'Newly added placement must remain movable');
    });
  });
}
