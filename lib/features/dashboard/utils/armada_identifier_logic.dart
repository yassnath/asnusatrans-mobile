String normalizeArmadaPlateText(dynamic value) {
  return '${value ?? ''}'.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String normalizeArmadaNameKey(dynamic value) {
  return '${value ?? ''}'
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? extractArmadaPlateFromText(dynamic value) {
  final match = RegExp(
    r'\b[A-Z]{1,2}\s?[0-9]{1,4}\s?[A-Z]{1,3}\b',
  ).firstMatch('${value ?? ''}'.toUpperCase());
  if (match == null) return null;
  final plate = normalizeArmadaPlateText(match.group(0));
  return plate.isEmpty || plate == '-' ? null : plate;
}

Map<String, String> buildArmadaIdByPlate(
  Iterable<Map<String, dynamic>> armadas,
) {
  final map = <String, String>{};
  for (final armada in armadas) {
    final id = '${armada['id'] ?? ''}'.trim();
    final plate = normalizeArmadaPlateText(armada['plat_nomor']);
    if (id.isEmpty || plate.isEmpty || plate == '-') continue;
    map[plate] = id;
  }
  return map;
}

Map<String, String> buildArmadaPlateById(
  Iterable<Map<String, dynamic>> armadas,
) {
  final map = <String, String>{};
  for (final armada in armadas) {
    final id = '${armada['id'] ?? ''}'.trim();
    final plate = normalizeArmadaPlateText(armada['plat_nomor']);
    if (id.isEmpty || plate.isEmpty || plate == '-') continue;
    map[id] = plate;
  }
  return map;
}

Map<String, String> buildArmadaPlateByName(
  Iterable<Map<String, dynamic>> armadas,
) {
  final map = <String, String>{};
  for (final armada in armadas) {
    final nameKey = normalizeArmadaNameKey(armada['nama_truk']);
    final plate = normalizeArmadaPlateText(armada['plat_nomor']);
    if (nameKey.isEmpty || plate.isEmpty || plate == '-') continue;
    map[nameKey] = plate;
  }
  return map;
}
