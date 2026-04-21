bool isTolakanCargo(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return normalized.contains('tolakan');
}

double? resolveTolakanAdjustedPositiveValue(
  dynamic value, {
  required String cargo,
}) {
  final number = _toDouble(value);
  if (!number.isFinite || number <= 0) return null;
  return isTolakanCargo(cargo) ? number / 2 : number;
}

double resolveTolakanBaseValue(
  dynamic value, {
  required String cargo,
}) {
  final number = _toDouble(value);
  if (!number.isFinite || number <= 0) return 0;
  return isTolakanCargo(cargo) ? number * 2 : number;
}

({String pickup, String destination}) resolveTolakanDisplayRoute({
  required String pickup,
  required String destination,
  required String cargo,
}) {
  final cleanedPickup = pickup.trim();
  final cleanedDestination = destination.trim();
  if (!isTolakanCargo(cargo)) {
    return (pickup: cleanedPickup, destination: cleanedDestination);
  }
  if (cleanedPickup.isEmpty ||
      cleanedDestination.isEmpty ||
      cleanedPickup == cleanedDestination) {
    return (pickup: cleanedPickup, destination: cleanedDestination);
  }
  return (
    pickup: cleanedDestination,
    destination: cleanedPickup,
  );
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}
