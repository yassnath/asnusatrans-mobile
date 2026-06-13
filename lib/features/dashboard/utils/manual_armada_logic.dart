String normalizeManualArmadaText(dynamic value) {
  return '${value ?? ''}'
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool isTruthyManualArmadaFlag(dynamic value) {
  if (value is bool) return value;
  final normalized = normalizeManualArmadaText(value);
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

bool isManualArmadaText(dynamic value) {
  final normalized = normalizeManualArmadaText(value);
  if (normalized.isEmpty) return false;
  return normalized == 'gabungan' ||
      normalized.contains('gabungan') ||
      normalized == 'manual' ||
      normalized.contains('input manual');
}

bool rowUsesManualArmada(Map<String, dynamic> row) {
  // A selected fleet ID is authoritative even if legacy/manual labels remain.
  if ('${row['armada_id'] ?? ''}'.trim().isNotEmpty) return false;
  if (isTruthyManualArmadaFlag(row['armada_is_manual'])) return true;
  if ('${row['armada_manual'] ?? ''}'.trim().isNotEmpty) return true;
  return isManualArmadaText(row['armada_label']) ||
      isManualArmadaText(row['armada']) ||
      isManualArmadaText(row['plat_nomor']) ||
      isManualArmadaText(row['no_polisi']);
}

void applyListedArmadaSelection(
  Map<String, dynamic> row,
  String armadaId,
) {
  row['armada_id'] = armadaId.trim();
  row['armada_is_manual'] = false;
  row['armada_manual'] = '';

  for (final key in const [
    'armada_label',
    'armada',
    'plat_nomor',
    'no_polisi',
  ]) {
    if (isManualArmadaText(row[key])) {
      row[key] = '';
    }
  }
}

String manualArmadaLabelFromRow(Map<String, dynamic> row) {
  final manual = '${row['armada_manual'] ?? ''}'.trim();
  if (manual.isNotEmpty) return manual;

  for (final key in const [
    'armada_label',
    'armada',
    'plat_nomor',
    'no_polisi',
  ]) {
    final value = '${row[key] ?? ''}'.trim();
    if (isManualArmadaText(value)) return value;
  }

  return '';
}
