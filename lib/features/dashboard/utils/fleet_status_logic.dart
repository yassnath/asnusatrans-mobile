const fleetStatusReady = 'Ready';
const fleetStatusFull = 'Full';
const fleetStatusInactive = 'Inactive';

const fleetStatusOptions = <String>[
  fleetStatusReady,
  fleetStatusFull,
  fleetStatusInactive,
];

String normalizeFleetStatusText(dynamic value) {
  return '${value ?? ''}'
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool isInactiveFleetStatus(dynamic value, {bool active = true}) {
  if (!active) return true;
  final normalized = normalizeFleetStatusText(value);
  return normalized == 'inactive' ||
      normalized == 'non active' ||
      normalized == 'nonactive' ||
      normalized.contains('inactive') ||
      normalized.contains('non active');
}

bool isFullFleetStatus(dynamic value) {
  final normalized = normalizeFleetStatusText(value);
  return normalized == 'full' || normalized.contains('full');
}

bool isReadyFleetStatus(dynamic value, {bool active = true}) {
  return normalizeFleetStatus(value, active: active) == fleetStatusReady;
}

String normalizeFleetStatus(dynamic value, {bool active = true}) {
  if (isInactiveFleetStatus(value, active: active)) return fleetStatusInactive;
  if (isFullFleetStatus(value)) return fleetStatusFull;
  return fleetStatusReady;
}

bool isFleetSelectable(dynamic value, {bool active = true}) {
  return normalizeFleetStatus(value, active: active) == fleetStatusReady;
}

String nextFleetStatusForActiveToggle({
  required bool active,
  required String currentStatus,
}) {
  if (!active) return fleetStatusInactive;
  return normalizeFleetStatus(currentStatus) == fleetStatusInactive
      ? fleetStatusReady
      : normalizeFleetStatus(currentStatus);
}
