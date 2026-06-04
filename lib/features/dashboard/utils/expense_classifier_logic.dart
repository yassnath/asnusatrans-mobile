import 'dart:convert';

List<Map<String, dynamic>> expenseDetailList(dynamic value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(growable: false);
      }
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }
  return const <Map<String, dynamic>>[];
}

String normalizeExpenseClassifierText(dynamic value) {
  return '${value ?? ''}'
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String expenseClassifierText(Map<String, dynamic> expense) {
  final detailText = expenseDetailList(expense['rincian']).map((detail) {
    return [
      detail['nama'],
      detail['name'],
      detail['kategori'],
      detail['keterangan'],
      detail['note'],
    ].map((value) => '${value ?? ''}').join(' ');
  }).join(' ');
  return normalizeExpenseClassifierText([
    expense['kategori'],
    expense['keterangan'],
    expense['note'],
    detailText,
  ].map((value) => '${value ?? ''}').join(' '));
}

bool isAutoSanguExpense(Map<String, dynamic> expense) {
  final note = '${expense['note'] ?? ''}'.trim().toUpperCase();
  if (note.startsWith('AUTO_SANGU:')) return true;
  final text = expenseClassifierText(expense);
  return text.startsWith('auto sangu sopir') ||
      text.contains('auto sangu sopir');
}

bool isAutoGabunganExpense(Map<String, dynamic> expense) {
  final note = '${expense['note'] ?? ''}'.trim().toUpperCase();
  if (note.startsWith('AUTO_GABUNGAN:')) return true;
  final text = expenseClassifierText(expense);
  return text.startsWith('auto gabungan') || text.contains('auto gabungan');
}

bool isGabunganExpense(Map<String, dynamic> expense) {
  if (isAutoGabunganExpense(expense)) return true;
  final text = expenseClassifierText(expense);
  return text.contains('gabungan') ||
      text.contains('armada manual') ||
      text.contains('manual armada') ||
      text.contains('other gabungan');
}

bool isSanguExpense(Map<String, dynamic> expense) {
  if (isAutoSanguExpense(expense)) return true;
  final text = expenseClassifierText(expense);
  return text.contains('sangu') ||
      text.contains('uang jalan') ||
      text.contains('sopir') ||
      text.contains('supir');
}

String expenseLinkToken(dynamic value) {
  return '${value ?? ''}'
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '')
      .trim();
}

String extractAutoExpenseMarker(Map<String, dynamic> expense) {
  final note = '${expense['note'] ?? ''}'.trim();
  if (note.toUpperCase().startsWith('AUTO_SANGU:')) {
    return note.substring('AUTO_SANGU:'.length).trim();
  }
  if (note.toUpperCase().startsWith('AUTO_GABUNGAN:')) {
    return note.substring('AUTO_GABUNGAN:'.length).trim();
  }

  final ket = '${expense['keterangan'] ?? ''}'.trim();
  final lowerKet = ket.toLowerCase();
  const autoSanguPrefix = 'auto sangu sopir -';
  if (lowerKet.startsWith(autoSanguPrefix)) {
    return ket.substring(autoSanguPrefix.length).trim();
  }
  const autoGabunganPrefix = 'auto gabungan -';
  if (lowerKet.startsWith(autoGabunganPrefix)) {
    return ket.substring(autoGabunganPrefix.length).trim();
  }
  return '';
}
