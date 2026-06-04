import 'package:cvant_mobile/features/dashboard/utils/fleet_status_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fleet status logic', () {
    test('normalizes supported fleet statuses consistently', () {
      expect(normalizeFleetStatus('ready'), fleetStatusReady);
      expect(normalizeFleetStatus('FULL'), fleetStatusFull);
      expect(normalizeFleetStatus('non-active'), fleetStatusInactive);
      expect(normalizeFleetStatus('Ready', active: false), fleetStatusInactive);
      expect(normalizeFleetStatus(null), fleetStatusReady);
    });

    test('detects selectable fleet only when ready and active', () {
      expect(isFleetSelectable('Ready'), isTrue);
      expect(isFleetSelectable('Full'), isFalse);
      expect(isFleetSelectable('Inactive'), isFalse);
      expect(isFleetSelectable('Ready', active: false), isFalse);
    });

    test('keeps active toggle transitions predictable', () {
      expect(
        nextFleetStatusForActiveToggle(active: false, currentStatus: 'Ready'),
        fleetStatusInactive,
      );
      expect(
        nextFleetStatusForActiveToggle(active: true, currentStatus: 'Inactive'),
        fleetStatusReady,
      );
      expect(
        nextFleetStatusForActiveToggle(active: true, currentStatus: 'Full'),
        fleetStatusFull,
      );
    });
  });
}
