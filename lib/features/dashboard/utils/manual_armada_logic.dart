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
  if (isTruthyManualArmadaFlag(row['armada_is_manual'])) return true;
  if ('${row['armada_manual'] ?? ''}'.trim().isNotEmpty) return true;
  return isManualArmadaText(row['armada_label']) ||
      isManualArmadaText(row['armada']) ||
      isManualArmadaText(row['plat_nomor']) ||
      isManualArmadaText(row['no_polisi']);
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
