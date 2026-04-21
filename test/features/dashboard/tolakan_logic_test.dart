import 'package:flutter_test/flutter_test.dart';
import 'package:cvant_mobile/features/dashboard/utils/tolakan_logic.dart';

void main() {
  group('Tolakan logic', () {
    test('detects tolakan regardless of casing or separators', () {
      expect(isTolakanCargo('tolakan'), isTrue);
      expect(isTolakanCargo('TOLAKAN'), isTrue);
      expect(isTolakanCargo('ToLaKaN Retur'), isTrue);
      expect(isTolakanCargo('tolakan-retur'), isTrue);
      expect(isTolakanCargo('normal'), isFalse);
    });

    test('halves positive values only when cargo is tolakan', () {
      expect(
        resolveTolakanAdjustedPositiveValue(3400000, cargo: 'Tolakan'),
        1700000,
      );
      expect(
        resolveTolakanAdjustedPositiveValue(235, cargo: 'TOLAKAN'),
        117.5,
      );
      expect(
        resolveTolakanAdjustedPositiveValue(3400000, cargo: 'Normal'),
        3400000,
      );
      expect(
        resolveTolakanAdjustedPositiveValue(0, cargo: 'Tolakan'),
        isNull,
      );
    });

    test('restores base value from stored tolakan nominal', () {
      expect(resolveTolakanBaseValue(1700000, cargo: 'tolakan'), 3400000);
      expect(resolveTolakanBaseValue(235, cargo: 'normal'), 235);
    });

    test('reverses display route when cargo is tolakan', () {
      final route = resolveTolakanDisplayRoute(
        pickup: 'T. Langon',
        destination: 'Batang',
        cargo: 'ToLaKaN',
      );

      expect(route.pickup, 'Batang');
      expect(route.destination, 'T. Langon');
      expect(
        resolveTolakanAdjustedPositiveValue(3400000, cargo: 'ToLaKaN'),
        1700000,
      );
    });

    test('keeps display route when cargo is not tolakan', () {
      final route = resolveTolakanDisplayRoute(
        pickup: 'T. Langon',
        destination: 'Batang',
        cargo: 'Batu Bara',
      );

      expect(route.pickup, 'T. Langon');
      expect(route.destination, 'Batang');
    });
  });
}
