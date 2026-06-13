String normalizeArmadaPlateText(dynamic value) {
  return '${value ?? ''}'.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String normalizeArmadaPlateKey(dynamic value) {
  return '${value ?? ''}'
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '')
      .trim();
}

String normalizeArmadaNameKey(dynamic value) {
  return '${value ?? ''}'
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? extractArmadaPlateFromText(dynamic value) {
  final searchable = '${value ?? ''}'
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
      .trim();
  final match = RegExp(
    r'\b[A-Z]{1,2}\s?[0-9]{1,4}\s?[A-Z]{1,3}\b',
  ).firstMatch(searchable);
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
    map[normalizeArmadaPlateKey(plate)] = id;
  }
  return map;
}

String resolveArmadaIdFromPlateInput({
  required String armadaId,
  required String armadaInput,
  required Map<String, String> armadaIdByPlate,
}) {
  final direct = armadaId.trim();
  if (direct.isNotEmpty) return direct;

  final input = armadaInput.trim();
  if (input.isEmpty) return '';
  final extracted = extractArmadaPlateFromText(input);
  final candidates = <String>{
    if (extracted != null) normalizeArmadaPlateText(extracted),
    if (extracted != null) normalizeArmadaPlateKey(extracted),
    normalizeArmadaPlateText(input),
    normalizeArmadaPlateKey(input),
  };
  for (final candidate in candidates) {
    final resolved = armadaIdByPlate[candidate];
    if (resolved != null && resolved.trim().isNotEmpty) {
      return resolved.trim();
    }
  }
  return '';
}

String resolveListedArmadaIdFromRow(
  Map<String, dynamic> row, {
  required Map<String, String> armadaIdByPlate,
}) {
  final direct = '${row['armada_id'] ?? ''}'.trim();
  if (direct.isNotEmpty) return direct;

  for (final field in const [
    'armada_manual',
    'armada_label',
    'armada',
    'plat_nomor',
    'no_polisi',
  ]) {
    final resolved = resolveArmadaIdFromPlateInput(
      armadaId: '',
      armadaInput: '${row[field] ?? ''}',
      armadaIdByPlate: armadaIdByPlate,
    );
    if (resolved.isNotEmpty) return resolved;
  }
  return '';
}

Set<String> buildArmadaPlateKeys(
  Iterable<Map<String, dynamic>> armadas,
) {
  return armadas
      .map((armada) => normalizeArmadaPlateKey(armada['plat_nomor']))
      .where((key) => key.isNotEmpty)
      .toSet();
}

bool rowMatchesListedArmadaPlate(
  Map<String, dynamic> row, {
  required Iterable<String> listedPlates,
}) {
  final listedKeys = listedPlates
      .map(normalizeArmadaPlateKey)
      .where((key) => key.isNotEmpty)
      .toSet();
  if (listedKeys.isEmpty) return false;

  for (final field in const [
    'armada_manual',
    'armada_label',
    'armada',
    'plat_nomor',
    'no_polisi',
  ]) {
    final plate = extractArmadaPlateFromText(row[field]);
    if (plate == null) continue;
    if (listedKeys.contains(normalizeArmadaPlateKey(plate))) return true;
  }
  return false;
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
