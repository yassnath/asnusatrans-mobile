part of 'dashboard_page.dart';

class _InvoiceTableRenderResult {
  const _InvoiceTableRenderResult({
    required this.image,
    required this.aspectRatio,
    required this.renderSource,
  });

  final pw.MemoryImage image;
  final double aspectRatio;
  final String renderSource;
}

String? _dashboardInvoiceEntityFromInvoiceNumber(String number) {
  final compact = number.toUpperCase().replaceAll(RegExp(r'\s+'), '');
  if (compact.isEmpty) return null;
  if (compact.contains('PT.ANT') || compact.contains('/PT.ANT/')) {
    return Formatters.invoiceEntityPtAnt;
  }
  if (compact.contains('CV.ANT') || compact.contains('/CV.ANT/')) {
    return Formatters.invoiceEntityCvAnt;
  }
  if (compact.contains('/BS/') ||
      compact.contains('/ANT/') ||
      compact.startsWith('BS')) {
    return Formatters.invoiceEntityPersonal;
  }
  return null;
}

String _resolveInvoiceEntityShared({
  dynamic invoiceEntity,
  dynamic invoiceNumber,
  dynamic customerName,
  bool fallback = true,
}) {
  final explicitEntity = '${invoiceEntity ?? ''}'.trim();
  final entityFromNumber =
      _dashboardInvoiceEntityFromInvoiceNumber('${invoiceNumber ?? ''}'.trim());
  return Formatters.normalizeInvoiceEntity(
    explicitEntity.isNotEmpty ? explicitEntity : entityFromNumber,
    invoiceNumber: invoiceNumber,
    customerName: customerName,
    isCompany: fallback,
  );
}

bool _resolveIsCompanyInvoiceShared({
  dynamic invoiceEntity,
  dynamic invoiceNumber,
  dynamic customerName,
  bool fallback = true,
}) {
  final entity = _resolveInvoiceEntityShared(
    invoiceEntity: invoiceEntity,
    invoiceNumber: invoiceNumber,
    customerName: customerName,
    fallback: fallback,
  );
  return Formatters.isCompanyInvoiceEntity(entity);
}

String _resolveInvoiceEntityLabelShared({
  dynamic invoiceEntity,
  dynamic invoiceNumber,
  dynamic customerName,
}) {
  final entity = _resolveInvoiceEntityShared(
    invoiceEntity: invoiceEntity,
    invoiceNumber: invoiceNumber,
    customerName: customerName,
  );
  return Formatters.invoiceEntityLabel(entity);
}

String _displayInvoiceNumberShared(String number) {
  return number.trim().isEmpty ? '-' : number.trim();
}

String _normalizeDashboardArmadaNameKey(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? _extractDashboardPlateFromText(String value) {
  final match = RegExp(
    r'[A-Z]{1,2}\s?[0-9]{1,4}\s?[A-Z]{1,3}',
  ).firstMatch(value.toUpperCase());
  if (match == null) return null;
  final plate =
      match.group(0)?.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim() ??
          '';
  return plate.isEmpty ? null : plate;
}

List<Map<String, dynamic>> _dashboardToDetailList(dynamic value) {
  if (value is List) {
    return value.whereType<Map>().map((item) {
      final row = Map<String, dynamic>.from(item);
      final directPlate =
          '${row['plat_nomor'] ?? row['no_polisi'] ?? ''}'.trim();
      if (directPlate.isNotEmpty && directPlate != '-') {
        return row;
      }
      for (final candidate in [
        '${row['armada_manual'] ?? ''}'.trim(),
        '${row['armada_label'] ?? ''}'.trim(),
        '${row['armada'] ?? ''}'.trim(),
      ]) {
        if (candidate.isEmpty) continue;
        final parsed = _extractDashboardPlateFromText(candidate);
        if (parsed != null && parsed.isNotEmpty && parsed != '-') {
          row['plat_nomor'] = parsed;
          row['no_polisi'] = parsed;
          break;
        }
      }
      return row;
    }).toList();
  }
  return const <Map<String, dynamic>>[];
}

Map<String, dynamic> _fallbackIncomeDetailRowForPdf(
  Map<String, dynamic> item,
) {
  return <String, dynamic>{
    'lokasi_muat': item['lokasi_muat'],
    'lokasi_bongkar': item['lokasi_bongkar'],
    'muatan': item['muatan'],
    'nama_supir': item['nama_supir'],
    'armada_id': item['armada_id'],
    'armada_manual': item['armada_manual'],
    'armada_label': item['armada_label'],
    'plat_nomor': item['plat_nomor'] ?? item['no_polisi'],
    'no_polisi': item['no_polisi'] ?? item['plat_nomor'],
    'armada_start_date': item['armada_start_date'] ?? item['tanggal'],
    'armada_end_date': item['armada_end_date'],
    'tanggal': item['tanggal'],
    'tonase': item['tonase'],
    'harga': item['harga'],
    'subtotal': item['subtotal'] ?? item['total_biaya'],
  };
}

List<Map<String, dynamic>> _expandInvoicePrintDetailsForPdf(
  Iterable<Map<String, dynamic>> items,
) {
  final details = <Map<String, dynamic>>[];
  for (final item in items) {
    final rows = _dashboardToDetailList(item['rincian']);
    if (rows.isNotEmpty) {
      details.addAll(rows.map((row) => Map<String, dynamic>.from(row)));
    } else {
      details.add(_fallbackIncomeDetailRowForPdf(item));
    }
  }
  details.sort((a, b) {
    final aDate = Formatters.parseDate(
          a['armada_start_date'] ?? a['tanggal'],
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final bDate = Formatters.parseDate(
          b['armada_start_date'] ?? b['tanggal'],
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final byDate = aDate.compareTo(bDate);
    if (byDate != 0) return byDate;
    final aPlate =
        '${a['plat_nomor'] ?? a['no_polisi'] ?? a['armada_manual'] ?? ''}'
            .toUpperCase();
    final bPlate =
        '${b['plat_nomor'] ?? b['no_polisi'] ?? b['armada_manual'] ?? ''}'
            .toUpperCase();
    return aPlate.compareTo(bPlate);
  });
  return details;
}

({
  Map<String, dynamic> item,
  List<Map<String, dynamic>> details,
}) _mergeInvoiceItemsForPdf(
  Iterable<Map<String, dynamic>> items, {
  String? invoiceNumberOverride,
  String? kopDateOverride,
  String? kopLocationOverride,
}) {
  final sourceItems =
      items.map((item) => Map<String, dynamic>.from(item)).toList();
  if (sourceItems.isEmpty) {
    return (item: <String, dynamic>{}, details: const <Map<String, dynamic>>[]);
  }

  final baseItem = Map<String, dynamic>.from(sourceItems.first);
  final mergedDetails = _expandInvoicePrintDetailsForPdf(sourceItems);
  final customerName = '${baseItem['nama_pelanggan'] ?? ''}';
  final resolvedInvoiceEntity = _resolveInvoiceEntityShared(
    invoiceEntity: baseItem['invoice_entity'],
    invoiceNumber: baseItem['no_invoice'],
    customerName: customerName,
  );
  final isCompanyInvoice = _resolveIsCompanyInvoiceShared(
    invoiceEntity: baseItem['invoice_entity'],
    invoiceNumber: baseItem['no_invoice'],
    customerName: customerName,
  );

  double detailSubtotal(Map<String, dynamic> row) {
    final explicit = _toNum(row['subtotal']);
    if (explicit > 0) return explicit;
    return _toNum(row['tonase']) * _toNum(row['harga']);
  }

  final subtotal = mergedDetails.fold<double>(
    0,
    (sum, row) => sum + detailSubtotal(row),
  );
  final pph = isCompanyInvoice
      ? sourceItems.fold<double>(0, (sum, item) => sum + _toNum(item['pph']))
      : 0.0;
  final total = isCompanyInvoice
      ? sourceItems.fold<double>(
          0,
          (sum, item) =>
              sum + _toNum(item['total_bayar'] ?? item['total_biaya']),
        )
      : subtotal;
  final firstDate = mergedDetails
      .map((row) =>
          Formatters.parseDate(row['armada_start_date'] ?? row['tanggal']))
      .whereType<DateTime>()
      .fold<DateTime?>(
        null,
        (prev, current) =>
            prev == null || current.isBefore(prev) ? current : prev,
      );

  baseItem['rincian'] = mergedDetails;
  baseItem['invoice_entity'] = resolvedInvoiceEntity;
  baseItem['total_biaya'] = subtotal;
  baseItem['pph'] = pph;
  baseItem['total_bayar'] = total;
  if (firstDate != null) {
    final mm = firstDate.month.toString().padLeft(2, '0');
    final dd = firstDate.day.toString().padLeft(2, '0');
    baseItem['tanggal'] = '${firstDate.year}-$mm-$dd';
  }
  if ((invoiceNumberOverride ?? '').trim().isNotEmpty) {
    baseItem['no_invoice'] = invoiceNumberOverride!.trim();
  }
  if ((kopDateOverride ?? '').trim().isNotEmpty) {
    baseItem['tanggal_kop'] = kopDateOverride!.trim();
  }
  if ((kopLocationOverride ?? '').trim().isNotEmpty) {
    baseItem['lokasi_kop'] = kopLocationOverride!.trim();
  }
  return (item: baseItem, details: mergedDetails);
}

typedef _InvoicePrintSnack = void Function(String msg, {bool error});
typedef _InvoiceMarkFixed = Future<void> Function(
  Iterable<String> ids, {
  _FixedInvoiceBatch? batch,
});

abstract class _DashboardInvoicePrintHost {
  BuildContext get context;
  bool get mounted;
  DashboardRepository get invoicePrintRepository;
  String translatePrintText(String id, String en);
  void showPrintSnack(String msg, {bool error});
  Future<void> markInvoicesFixed(
    Iterable<String> ids, {
    _FixedInvoiceBatch? batch,
  });
}

class _DashboardInvoicePrintDelegate implements _DashboardInvoicePrintHost {
  _DashboardInvoicePrintDelegate({
    required this.context,
    required DashboardRepository repository,
    required String Function(String id, String en) translate,
    required _InvoicePrintSnack snack,
    required bool Function() isMounted,
    _InvoiceMarkFixed? markInvoicesFixed,
  })  : _repository = repository,
        _translate = translate,
        _snack = snack,
        _isMounted = isMounted,
        _markInvoicesFixed = markInvoicesFixed;

  @override
  final BuildContext context;

  final DashboardRepository _repository;
  final String Function(String id, String en) _translate;
  final _InvoicePrintSnack _snack;
  final bool Function() _isMounted;
  final _InvoiceMarkFixed? _markInvoicesFixed;

  @override
  bool get mounted => _isMounted();

  @override
  DashboardRepository get invoicePrintRepository => _repository;

  @override
  String translatePrintText(String id, String en) => _translate(id, en);

  @override
  void showPrintSnack(String msg, {bool error = false}) {
    _snack(msg, error: error);
  }

  @override
  Future<void> markInvoicesFixed(
    Iterable<String> ids, {
    _FixedInvoiceBatch? batch,
  }) async {
    final callback = _markInvoicesFixed;
    if (callback == null) return;
    await callback(ids, batch: batch);
  }
}

Map<int, pw.TableColumnWidth> _buildDashboardIncomeTableColumnWidths(
  List<Map<String, dynamic>> detailList,
) {
  var maxMuat = 12;
  var maxBongkar = 12;
  var maxPlate = 8;
  var maxMuatan = 8;
  var maxHarga = 10;
  var maxTotal = 10;
  for (final row in detailList) {
    maxMuat = max(maxMuat, '${row['lokasi_muat'] ?? ''}'.trim().length);
    maxBongkar = max(
      maxBongkar,
      '${row['lokasi_bongkar'] ?? ''}'.trim().length,
    );
    maxMuatan = max(maxMuatan, '${row['muatan'] ?? ''}'.trim().length);
    final plate = '${row['plat_nomor'] ?? row['no_polisi'] ?? ''}'.trim();
    maxPlate = max(maxPlate, plate.length);
    final hargaText = Formatters.rupiah(_toNum(row['harga']));
    final totalText =
        Formatters.rupiah(_toNum(row['tonase']) * _toNum(row['harga']));
    maxHarga = max(maxHarga, hargaText.length);
    maxTotal = max(maxTotal, totalText.length);
  }

  final totalRouteChars = max(1, maxMuat + maxBongkar);
  final muatShare = maxMuat / totalRouteChars;
  final bongkarShare = maxBongkar / totalRouteChars;
  const routeBudgetFlex = 2.10;
  final muatFlex = (routeBudgetFlex * muatShare).clamp(1.0, 1.55).toDouble();
  final bongkarFlex =
      (routeBudgetFlex * bongkarShare).clamp(1.0, 1.55).toDouble();
  final plateFlex = (maxPlate / 9).clamp(1.0, 1.35).toDouble();
  final muatanFlex = (maxMuatan / 8.5).clamp(0.95, 1.45).toDouble();
  final hargaFlex = (maxHarga / 13).clamp(0.58, 0.82).toDouble();
  final totalFlex = (maxTotal / 8.6).clamp(1.30, 1.90).toDouble();

  return {
    0: const pw.FixedColumnWidth(30), // No
    1: const pw.FlexColumnWidth(1.05), // Tanggal
    2: pw.FlexColumnWidth(plateFlex), // Plat
    3: pw.FlexColumnWidth(muatanFlex), // Muatan
    4: pw.FlexColumnWidth(muatFlex), // Muat
    5: pw.FlexColumnWidth(bongkarFlex), // Bongkar
    6: const pw.FlexColumnWidth(0.72), // Tonase
    7: pw.FlexColumnWidth(hargaFlex), // Harga
    8: pw.FlexColumnWidth(totalFlex), // Total
  };
}

pw.Widget _dashboardPdfCell(
  String text, {
  bool bold = false,
  bool alignRight = false,
  bool alignCenter = false,
  PdfColor? textColor,
  double fontSize = 9.5,
  double minFontSize = 7.0,
  double hPadding = 6,
  double vPadding = 5,
  double? fixedHeight,
  bool singleLineAutoShrink = false,
  int softLimitChars = 24,
}) {
  final textAlign = alignRight
      ? pw.TextAlign.right
      : alignCenter
          ? pw.TextAlign.center
          : pw.TextAlign.left;
  var resolvedFontSize = fontSize;
  if (singleLineAutoShrink) {
    final safeLimit = max(1, softLimitChars);
    final textLength = text.trim().length;
    if (textLength > safeLimit) {
      final ratio = safeLimit / textLength;
      resolvedFontSize = max(minFontSize, fontSize * ratio);
    }
  }
  return pw.Container(
    height: fixedHeight,
    alignment: alignCenter
        ? pw.Alignment.center
        : alignRight
            ? pw.Alignment.centerRight
            : pw.Alignment.centerLeft,
    child: pw.Padding(
      padding:
          pw.EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
      child: pw.Text(
        text,
        maxLines: singleLineAutoShrink ? 1 : null,
        textAlign: textAlign,
        style: pw.TextStyle(
          fontSize: resolvedFontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor,
        ),
      ),
    ),
  );
}

Future<bool> _printDashboardInvoicePdf(
  _DashboardInvoicePrintHost host,
  Map<String, dynamic> item,
  List<Map<String, dynamic>> detailList, {
  bool markAsFixed = false,
  bool showSuccessPopup = false,
  String? invoiceNumberOverride,
  String? kopDateOverride,
  String? kopLocationOverride,
  Iterable<String>? fixedInvoiceIds,
  _FixedInvoiceBatch? fixedBatch,
}) async {
  try {
    final invoiceDetailList = detailList.isNotEmpty
        ? detailList
        : _dashboardToDetailList(item['rincian']);
    // <= 16 detail rows: print in half-sheet layout (50:50 on portrait paper).
    // > 16 detail rows: switch to full-sheet portrait layout.
    final usePortrait = invoiceDetailList.length > 16;
    final invoiceRawNumber = '${item['no_invoice'] ?? '-'}';
    final customerName = '${item['nama_pelanggan'] ?? ''}';
    final resolvedInvoiceEntity = _resolveInvoiceEntityShared(
      invoiceEntity: item['invoice_entity'],
      invoiceNumber: invoiceRawNumber,
      customerName: customerName,
    );
    final isCompanyInvoice = _resolveIsCompanyInvoiceShared(
      invoiceEntity: item['invoice_entity'],
      invoiceNumber: invoiceRawNumber,
      customerName: customerName,
    );
    final subtotal = _toNum(item['total_biaya']);
    final pph = isCompanyInvoice ? _toNum(item['pph']) : 0.0;
    final total = isCompanyInvoice
        ? _toNum(item['total_bayar'] ?? item['total_biaya'])
        : subtotal;
    final effectiveKopDateRaw = (kopDateOverride ?? '').trim().isNotEmpty
        ? kopDateOverride!.trim()
        : '${item['tanggal_kop'] ?? item['tanggal'] ?? ''}'.trim();
    final effectiveKopLocationRaw =
        (kopLocationOverride ?? '').trim().isNotEmpty
            ? kopLocationOverride!.trim()
            : '${item['lokasi_kop'] ?? ''}'.trim();
    final invoiceNumber = _displayInvoiceNumberShared(
      (invoiceNumberOverride ?? '').trim().isNotEmpty
          ? invoiceNumberOverride!.trim()
          : Formatters.invoiceNumber(
              invoiceRawNumber,
              effectiveKopDateRaw,
              customerName: customerName,
              isCompany: isCompanyInvoice,
              invoiceEntity: resolvedInvoiceEntity,
            ),
    );
    pw.MemoryImage? kopLogo;
    try {
      final logoBytes = await rootBundle.load('assets/images/iconapk.png');
      kopLogo = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {
      kopLogo = null;
    }
    pw.MemoryImage? companyKopImage;
    try {
      final kopAsset = resolvedInvoiceEntity == Formatters.invoiceEntityPtAnt
          ? 'assets/images/kopsuratpt.png'
          : 'assets/images/kopsurat.jpeg';
      final kopBytes = await rootBundle.load(kopAsset);
      companyKopImage = pw.MemoryImage(kopBytes.buffer.asUint8List());
    } catch (_) {
      companyKopImage = null;
    }
    final armadas = await host.invoicePrintRepository.fetchArmadas();
    final armadaPlateById = <String, String>{
      for (final armada in armadas)
        '${armada['id'] ?? ''}':
            '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
    };
    final armadaPlateByName = <String, String>{
      for (final armada in armadas)
        _normalizeDashboardArmadaNameKey('${armada['nama_truk'] ?? ''}'):
            '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
    };

    String resolveNoPolisi(Map<String, dynamic> row) {
      final rowArmadaId = '${row['armada_id'] ?? ''}'.trim();
      final byArmada =
          rowArmadaId.isEmpty ? null : armadaPlateById[rowArmadaId];
      if (byArmada != null && byArmada.isNotEmpty && byArmada != '-') {
        return byArmada;
      }
      final direct =
          '${row['plat_nomor'] ?? row['no_polisi'] ?? ''}'.trim().toUpperCase();
      if (direct.isNotEmpty && direct != '-') return direct;
      for (final candidate in [
        '${row['armada_manual'] ?? ''}'.trim(),
        '${row['armada_label'] ?? row['armada'] ?? ''}'.trim(),
      ]) {
        if (candidate.isEmpty) continue;
        final match = RegExp(
          r'\b[A-Z]{1,2}\s?\d{1,4}\s?[A-Z]{1,3}\b',
        ).firstMatch(candidate.toUpperCase());
        if (match != null) {
          return (match.group(0) ?? '-').trim();
        }
        final byName =
            armadaPlateByName[_normalizeDashboardArmadaNameKey(candidate)];
        if (byName != null && byName.isNotEmpty && byName != '-') {
          return byName;
        }
      }
      final fallbackArmadaId = '${item['armada_id'] ?? ''}'.trim();
      final fallbackByArmada =
          fallbackArmadaId.isEmpty ? null : armadaPlateById[fallbackArmadaId];
      if (fallbackByArmada != null &&
          fallbackByArmada.isNotEmpty &&
          fallbackByArmada != '-') {
        return fallbackByArmada;
      }
      return '-';
    }

    String formatTonase(dynamic value) {
      return formatInvoiceTonase(value);
    }

    String formatHargaPerTon(dynamic value) {
      return formatInvoiceHargaPerTon(value);
    }

    int extraBlankRowsForMultiSheet({
      required int dataRows,
      required int baseRowsPerSheet,
    }) {
      // Request: when invoice spans multiple sheets, add 7 blank rows
      // on each sheet while keeping row height consistent.
      if (dataRows <= baseRowsPerSheet) return 0;
      const extraPerSheet = 7;
      var sheetCount = (dataRows / baseRowsPerSheet).ceil();
      var totalRowsWithPadding = dataRows + (sheetCount * extraPerSheet);
      while ((totalRowsWithPadding / baseRowsPerSheet).ceil() != sheetCount) {
        sheetCount = (totalRowsWithPadding / baseRowsPerSheet).ceil();
        totalRowsWithPadding = dataRows + (sheetCount * extraPerSheet);
      }
      return totalRowsWithPadding - dataRows;
    }

    List<Map<String, dynamic>> buildPrintableRows({
      required bool compact,
    }) {
      final baseRowsPerSheet =
          compact ? (isCompanyInvoice ? 18 : 21) : (isCompanyInvoice ? 40 : 43);
      final extraRows = extraBlankRowsForMultiSheet(
        dataRows: invoiceDetailList.length,
        baseRowsPerSheet: baseRowsPerSheet,
      );
      final minRows =
          max(baseRowsPerSheet, invoiceDetailList.length + extraRows);
      return invoiceDetailList.length >= minRows
          ? invoiceDetailList
          : <Map<String, dynamic>>[
              ...invoiceDetailList,
              ...List<Map<String, dynamic>>.generate(
                minRows - invoiceDetailList.length,
                (_) => <String, dynamic>{},
              ),
            ];
    }

    Future<_InvoiceTableRenderResult?> buildExcelTableImage({
      required bool compact,
      String renderMode = 'table',
    }) async {
      final printableRows = buildPrintableRows(compact: compact);
      final summaryValues =
          renderMode == 'table_with_summary' || renderMode == 'table_with_total'
              ? <String, String>{
                  'subtotal': formatRupiahNoPrefix(subtotal),
                  'pph': formatRupiahNoPrefix(pph),
                  'total': formatRupiahNoPrefix(total),
                }
              : null;
      final payloadRows = <Map<String, String>>[];
      for (var index = 0; index < printableRows.length; index++) {
        final row = printableRows[index];
        final hasData = index < invoiceDetailList.length;
        final tonase = hasData ? _toNum(row['tonase']) : 0;
        final harga = hasData ? _toNum(row['harga']) : 0;
        final rowSubtotal = tonase * harga;
        final armadaStartSource = row['armada_start_date'] ??
            item['armada_start_date'] ??
            row['tanggal'] ??
            item['tanggal'];
        payloadRows.add({
          'no': hasData ? '${index + 1}' : '',
          'tanggal': hasData ? _formatInvoiceTableDate(armadaStartSource) : '',
          'plat': hasData ? resolveNoPolisi(row) : '',
          'muatan': hasData ? '${row['muatan'] ?? '-'}' : '',
          'muat': hasData
              ? _normalizeInvoicePrintLocationLabel(row['lokasi_muat'])
              : '',
          'bongkar': hasData
              ? _normalizeInvoicePrintLocationLabel(row['lokasi_bongkar'])
              : '',
          'tonase': hasData ? formatTonase(tonase) : '',
          'harga': hasData ? formatHargaPerTon(harga) : '',
          'total': hasData ? formatRupiahNoPrefix(rowSubtotal) : '',
        });
      }
      Uint8List? bytes;
      var renderSource = 'Excel template renderer';
      bytes = await host._renderInvoiceTableImageWithExcel(
        rows: payloadRows,
        rowCount: printableRows.length,
        renderMode: renderMode,
        summaryValues: summaryValues,
      );
      if (bytes != null) {
        renderSource = 'Excel local (Windows)';
      } else {
        final cloudBytes = await host._renderInvoiceTableImageViaCloudService(
          rows: payloadRows,
          rowCount: printableRows.length,
          renderMode: renderMode,
          summaryValues: summaryValues,
        );
        if (cloudBytes != null) {
          bytes = cloudBytes;
          renderSource = 'Excel cloud service';
        } else {
          bytes = await host._renderInvoiceTableImagePortable(
            rows: payloadRows,
            rowCount: printableRows.length,
            renderMode: renderMode,
            summaryValues: summaryValues,
          );
        }
      }
      if (bytes == null) return null;
      final decodedImage = img.decodeImage(bytes);
      final aspectRatio = decodedImage == null || decodedImage.height == 0
          ? 1.0
          : decodedImage.width / decodedImage.height;
      return _InvoiceTableRenderResult(
        image: pw.MemoryImage(bytes),
        aspectRatio: aspectRatio,
        renderSource: renderSource,
      );
    }

    late final pw.Font invoiceTitleFont;
    try {
      invoiceTitleFont = await PdfGoogleFonts.archivoBlack();
    } catch (_) {
      invoiceTitleFont = pw.Font.helveticaBold();
    }

    pw.Widget buildInvoiceContent({
      required bool compact,
      _InvoiceTableRenderResult? excelTableRender,
      _InvoiceTableRenderResult? excelSummaryRender,
      bool excelTableHasEmbeddedSummary = false,
    }) {
      const infoFont = 9.5;
      final summaryValueGap = compact ? 8.0 : 10.0;
      final summaryBoxGap = 2.0;
      final signatureLeftOffset = compact ? 72.0 : 86.0;
      final signatureNameOffset = compact ? 5.0 : 6.0;
      const signatureTextFontSize = 11.0;
      final printableRows = buildPrintableRows(compact: compact);
      String? printable(dynamic value) {
        final raw = value?.toString().trim() ?? '';
        if (raw.isEmpty || raw == '-' || raw.toLowerCase() == 'null') {
          return null;
        }
        return raw;
      }

      final customerName = printable(item['nama_pelanggan']) ?? '-';
      final tanggalKop = effectiveKopDateRaw.isEmpty
          ? item['tanggal_kop'] ?? item['tanggal']
          : effectiveKopDateRaw;
      final kopLocation = printable(effectiveKopLocationRaw);
      String toTitleCase(String value) {
        final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (normalized.isEmpty) return normalized;
        return normalized.split(' ').map((word) {
          if (word.isEmpty) return word;
          final lower = word.toLowerCase();
          return lower.substring(0, 1).toUpperCase() + lower.substring(1);
        }).join(' ');
      }

      final kopLocationTitle =
          kopLocation == null ? null : toTitleCase(kopLocation);
      final kopLocationUpper = kopLocation?.toUpperCase();
      String formatLongDateId(dynamic value) {
        final date = Formatters.parseDate(value);
        if (date == null) return '-';
        const monthNames = <String>[
          'Januari',
          'Februari',
          'Maret',
          'April',
          'Mei',
          'Juni',
          'Juli',
          'Agustus',
          'September',
          'Oktober',
          'November',
          'Desember',
        ];
        return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
      }

      final tanggalLong = formatLongDateId(tanggalKop);
      final tanggalRow = kopLocationTitle == null || kopLocationTitle.isEmpty
          ? tanggalLong
          : '$kopLocationTitle, $tanggalLong';
      final logoHeight = compact ? 39.0 : 52.0;
      final companyKopHeight = compact ? 50.0 : 65.0;
      final recipientBaseLineWidth = compact
          ? (isCompanyInvoice ? 168.0 : 122.0)
          : (isCompanyInvoice ? 242.0 : 158.0);
      final recipientMaxLineWidth = compact
          ? (isCompanyInvoice ? 258.0 : 206.0)
          : (isCompanyInvoice ? 358.0 : 270.0);
      final recipientShiftLeft = compact ? 1.0 : 5.0;
      double recipientLineWidthFor(String text) {
        final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
        final lengthBased =
            (normalized.length * (compact ? 6.9 : 6.4)) + (compact ? 20 : 24);
        return max(
          recipientBaseLineWidth,
          min(recipientMaxLineWidth, lengthBased),
        );
      }

      final recipientLineWidth = max(
        recipientLineWidthFor(customerName),
        recipientLineWidthFor(kopLocationUpper ?? '-'),
      );
      const tableRowVPadding = 2.4;
      const tableBodyRowHeight = 16.0;
      final tableHorizontalBleedLeft =
          isCompanyInvoice ? (compact ? 1.1 : 0.7) : (compact ? 11.2 : 7.2);
      final tableHorizontalBleedRight =
          isCompanyInvoice ? (compact ? 1.5 : 1.0) : (compact ? 12.0 : 7.8);
      final incomeColumnWidths =
          _buildDashboardIncomeTableColumnWidths(printableRows);
      final excelTableImage = excelTableRender?.image;
      final excelTableIncludesSummary =
          excelTableHasEmbeddedSummary && excelTableRender != null;
      final compactExcelRenderHeight = isCompanyInvoice
          ? (excelTableIncludesSummary ? 309.0 : 256.0)
          : (excelTableIncludesSummary ? 323.0 : 271.0);
      final kopWordStyle = pw.TextStyle(
        fontSize: compact ? 34.0 : 47.0,
        fontWeight: pw.FontWeight.bold,
        fontStyle: pw.FontStyle.italic,
        letterSpacing: 5.0,
        wordSpacing: 1.15,
        color: PdfColors.blue900,
      );
      pw.Widget buildUltraBoldKop(String text) {
        // Keep boldness very strong while avoiding vertical clipping.
        // We bias thickness to the right (X) and keep Y spread thinner.
        final maxX = compact ? 3.2 : 4.8;
        final maxY = compact ? 0.62 : 0.90;
        final stepX = compact ? 0.14 : 0.20;
        final stepY = compact ? 0.14 : 0.20;
        final layers = <pw.Widget>[
          // Non-positioned base text keeps Stack intrinsic size valid.
          pw.Text(text, style: kopWordStyle),
        ];
        for (double dx = 0; dx <= maxX + 0.0001; dx += stepX) {
          for (double dy = 0; dy <= maxY + 0.0001; dy += stepY) {
            if (dx.abs() < 0.0001 && dy.abs() < 0.0001) continue;
            final ellipseNorm =
                ((dx * dx) / (maxX * maxX)) + ((dy * dy) / (maxY * maxY));
            if (ellipseNorm > 1.0) continue;
            layers.add(
              pw.Positioned(
                left: dx,
                top: dy,
                child: pw.Text(text, style: kopWordStyle),
              ),
            );
          }
        }
        return pw.Padding(
          // Extra right/bottom room so ultra-bold layers never get clipped.
          padding: pw.EdgeInsets.only(right: maxX + 0.8, bottom: maxY + 0.4),
          child: pw.Stack(
            children: layers,
          ),
        );
      }

      double fixedColWidth(int index) {
        final width = incomeColumnWidths[index];
        return width is pw.FixedColumnWidth ? width.width : 0;
      }

      double flexColWeight(int index) {
        final width = incomeColumnWidths[index];
        return width is pw.FlexColumnWidth ? width.flex : 0;
      }

      double invoiceDividerWidthFor(double availableWidth) {
        final fallbackWidth = compact ? 146.0 : 186.0;
        if (availableWidth <= 0) {
          return fallbackWidth;
        }

        final fixedWidthTotal = List<double>.generate(
          incomeColumnWidths.length,
          (i) => fixedColWidth(i),
        ).fold(0.0, (sum, width) => sum + width);
        final flexWeightTotal = List<double>.generate(
          incomeColumnWidths.length,
          (i) => flexColWeight(i),
        ).fold(0.0, (sum, width) => sum + width);
        final usableFlexWidth = max(0.0, availableWidth - fixedWidthTotal);

        double colWidth(int index) {
          final fixed = fixedColWidth(index);
          if (fixed > 0) return fixed;
          final flex = flexColWeight(index);
          if (flexWeightTotal <= 0 || flex <= 0) return 0;
          return usableFlexWidth * (flex / flexWeightTotal);
        }

        final logicalTableWidth = fixedWidthTotal + usableFlexWidth <= 0
            ? availableWidth
            : fixedWidthTotal + usableFlexWidth;
        final renderedTableWidth = compact &&
                excelTableRender != null &&
                excelTableRender.aspectRatio > 0
            ? compactExcelRenderHeight * excelTableRender.aspectRatio
            : availableWidth +
                tableHorizontalBleedLeft +
                tableHorizontalBleedRight;
        final expandedWidth = availableWidth +
            tableHorizontalBleedLeft +
            tableHorizontalBleedRight;
        final renderedLeft = -tableHorizontalBleedLeft +
            ((expandedWidth - renderedTableWidth) / 2);
        final tableScale = logicalTableWidth <= 0
            ? 1.0
            : renderedTableWidth / logicalTableWidth;
        final muatanRightBoundary = renderedLeft +
            ((colWidth(0) + colWidth(1) + colWidth(2) + colWidth(3)) *
                tableScale);
        final safeRightBoundary =
            max(0.0, muatanRightBoundary - (compact ? 20.0 : 24.0));
        if (safeRightBoundary > 0) {
          return min(safeRightBoundary, availableWidth);
        }
        return min(fallbackWidth, availableWidth);
      }

      pw.Widget buildCompanySummaryRow(
        String label,
        String value, {
        required double leadPrefixWidth,
        required double leftMergeWidth,
        required double middleGapWidth,
        required double mergedLabelWidth,
        required double totalWidth,
        String? leftText,
        bool bold = true,
      }) {
        final textStyle = pw.TextStyle(
          fontSize: infoFont,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        );
        return pw.SizedBox(
          height: tableBodyRowHeight,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.SizedBox(width: leadPrefixWidth),
              pw.Container(
                width: leftMergeWidth,
                alignment: pw.Alignment.center,
                child: leftText == null
                    ? pw.SizedBox()
                    : pw.FittedBox(
                        fit: pw.BoxFit.scaleDown,
                        child: pw.Text(
                          leftText.replaceAll(' ', '\u00A0'),
                          maxLines: 1,
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(
                            fontSize: signatureTextFontSize,
                            decoration: pw.TextDecoration.none,
                          ),
                        ),
                      ),
              ),
              pw.SizedBox(width: middleGapWidth),
              pw.Expanded(
                child: pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.only(right: 2),
                  child: pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      label.replaceAll(' ', '\u00A0'),
                      textAlign: pw.TextAlign.right,
                      maxLines: 1,
                      style: textStyle,
                    ),
                  ),
                ),
              ),
              pw.Container(
                width: totalWidth,
                alignment: pw.Alignment.centerRight,
                margin: pw.EdgeInsets.zero,
                padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.black,
                    width: 0.55,
                  ),
                ),
                child: pw.Text(
                  value,
                  textAlign: pw.TextAlign.right,
                  maxLines: 1,
                  style: textStyle,
                ),
              ),
            ],
          ),
        );
      }

      pw.Widget buildCompanySummaryBlock({
        required double leadPrefixWidth,
        required double leftMergeWidth,
        required double middleGapWidth,
        required double mergedLabelWidth,
        required double totalWidth,
        required String subtotalValue,
        required String pphValue,
        required String totalValue,
        String? leftText,
      }) {
        final labelStyle = pw.TextStyle(
          fontSize: infoFont,
          fontWeight: pw.FontWeight.bold,
        );
        final summaryImage = excelSummaryRender?.image;
        final totalBlockHeight = tableBodyRowHeight * 3;

        if (summaryImage == null) {
          return pw.Column(
            children: [
              buildCompanySummaryRow(
                'SUBTOTAL Rp.',
                subtotalValue,
                leadPrefixWidth: leadPrefixWidth,
                leftMergeWidth: leftMergeWidth,
                middleGapWidth: middleGapWidth,
                mergedLabelWidth: mergedLabelWidth,
                totalWidth: totalWidth,
                leftText: leftText,
              ),
              buildCompanySummaryRow(
                'PPH 2% Rp.',
                pphValue,
                leadPrefixWidth: leadPrefixWidth,
                leftMergeWidth: leftMergeWidth,
                middleGapWidth: middleGapWidth,
                mergedLabelWidth: mergedLabelWidth,
                totalWidth: totalWidth,
              ),
              buildCompanySummaryRow(
                'TOTAL BAYAR Rp.',
                totalValue,
                leadPrefixWidth: leadPrefixWidth,
                leftMergeWidth: leftMergeWidth,
                middleGapWidth: middleGapWidth,
                mergedLabelWidth: mergedLabelWidth,
                totalWidth: totalWidth,
              ),
            ],
          );
        }

        pw.Widget buildLabel(String text) => pw.Container(
              height: tableBodyRowHeight,
              alignment: pw.Alignment.centerRight,
              child: pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  text.replaceAll(' ', '\u00A0'),
                  textAlign: pw.TextAlign.right,
                  maxLines: 1,
                  style: labelStyle,
                ),
              ),
            );

        pw.Widget buildLeftCell() => pw.Container(
              height: totalBlockHeight,
              width: leftMergeWidth,
              alignment: pw.Alignment.topCenter,
              child: leftText == null
                  ? pw.SizedBox()
                  : pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 1),
                      child: pw.FittedBox(
                        fit: pw.BoxFit.scaleDown,
                        child: pw.Text(
                          leftText.replaceAll(' ', '\u00A0'),
                          maxLines: 1,
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(
                            fontSize: signatureTextFontSize,
                            decoration: pw.TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
            );

        return pw.SizedBox(
          height: totalBlockHeight,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(width: leadPrefixWidth),
              buildLeftCell(),
              pw.SizedBox(width: middleGapWidth),
              pw.Container(
                width: mergedLabelWidth,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    buildLabel('SUBTOTAL Rp.'),
                    buildLabel('PPH 2% Rp.'),
                    buildLabel('TOTAL BAYAR Rp.'),
                  ],
                ),
              ),
              pw.Container(
                width: totalWidth,
                height: totalBlockHeight,
                child: pw.Image(
                  summaryImage,
                  fit: pw.BoxFit.fill,
                  alignment: pw.Alignment.topRight,
                ),
              ),
            ],
          ),
        );
      }

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (isCompanyInvoice) ...[
            if (companyKopImage != null)
              pw.Container(
                margin: const pw.EdgeInsets.only(
                  left: -5.8,
                  right: -6.8,
                  top: 0,
                ),
                width: double.infinity,
                height: companyKopHeight,
                child: pw.Image(
                  companyKopImage,
                  fit: pw.BoxFit.fitWidth,
                  alignment: pw.Alignment.center,
                ),
              )
            else ...[
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (kopLogo != null)
                      pw.Image(
                        kopLogo,
                        height: logoHeight,
                        width: logoHeight,
                        fit: pw.BoxFit.contain,
                      )
                    else
                      pw.SizedBox(
                        height: logoHeight,
                        width: logoHeight,
                      ),
                    pw.SizedBox(width: 4),
                    pw.Expanded(
                      child: pw.Container(
                        height: logoHeight,
                        alignment: pw.Alignment.topLeft,
                        child: buildUltraBoldKop('CV AS NUSA TRANS'),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 1.5),
              pw.Container(
                width: double.infinity,
                height: 1.2,
                color: PdfColors.black,
              ),
            ],
            pw.SizedBox(height: 0.5),
          ],
          pw.LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints?.maxWidth ?? 0;
              final invoiceDividerWidth =
                  invoiceDividerWidthFor(availableWidth);
              return pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: invoiceDividerWidth,
                        child: pw.Center(
                          child: pw.Text(
                            'I  N  V  O  I  C  E',
                            style: pw.TextStyle(
                              font: invoiceTitleFont,
                              fontSize: compact ? 24 : 29,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 1.0),
                      pw.Container(
                        width: invoiceDividerWidth,
                        height: 0.8,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 0.8),
                      pw.Container(
                        width: invoiceDividerWidth,
                        height: 0.8,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 2.5),
                      pw.SizedBox(
                        width: invoiceDividerWidth,
                        child: pw.Center(
                          child: pw.Text(
                            'NO : $invoiceNumber',
                            style: pw.TextStyle(
                              fontSize: compact ? 10 : 11,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        tanggalRow,
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: infoFont),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Padding(
                        padding: pw.EdgeInsets.only(right: recipientShiftLeft),
                        child: pw.Row(
                          mainAxisSize: pw.MainAxisSize.min,
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              'Kepada Yth: ',
                              textAlign: pw.TextAlign.right,
                              style: const pw.TextStyle(fontSize: infoFont),
                            ),
                            pw.Container(
                              width: recipientLineWidth,
                              alignment: pw.Alignment.center,
                              padding: const pw.EdgeInsets.only(bottom: 1),
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(
                                  bottom: pw.BorderSide(
                                    color: PdfColors.black,
                                    width: 0.9,
                                  ),
                                ),
                              ),
                              child: pw.FittedBox(
                                fit: pw.BoxFit.scaleDown,
                                child: pw.Text(
                                  customerName.replaceAll(' ', '\u00A0'),
                                  maxLines: 1,
                                  textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(
                                    fontSize: infoFont,
                                    fontWeight: pw.FontWeight.bold,
                                    fontStyle: pw.FontStyle.italic,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Padding(
                        padding: pw.EdgeInsets.only(right: recipientShiftLeft),
                        child: pw.Container(
                          width: recipientLineWidth,
                          alignment: pw.Alignment.center,
                          padding: const pw.EdgeInsets.only(bottom: 1),
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              bottom: pw.BorderSide(
                                color: PdfColors.black,
                                width: 0.9,
                              ),
                            ),
                          ),
                          child: pw.FittedBox(
                            fit: pw.BoxFit.scaleDown,
                            child: pw.Text(
                              (kopLocationUpper ?? '-')
                                  .replaceAll(' ', '\u00A0'),
                              maxLines: 1,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                fontSize: infoFont,
                                fontWeight: pw.FontWeight.bold,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          pw.SizedBox(height: 5),
          if (excelTableImage != null)
            compact
                ? pw.Container(
                    margin: pw.EdgeInsets.only(
                      left: -tableHorizontalBleedLeft,
                      right: -tableHorizontalBleedRight,
                    ),
                    width: double.infinity,
                    alignment: pw.Alignment.topCenter,
                    child: pw.Image(
                      excelTableImage,
                      height: compactExcelRenderHeight,
                      fit: pw.BoxFit.fitHeight,
                      alignment: pw.Alignment.topCenter,
                    ),
                  )
                : pw.Container(
                    margin: pw.EdgeInsets.only(
                      left: -tableHorizontalBleedLeft,
                      right: -tableHorizontalBleedRight,
                    ),
                    width: double.infinity,
                    child: pw.Image(
                      excelTableImage,
                      fit: pw.BoxFit.fitWidth,
                      alignment: pw.Alignment.topCenter,
                    ),
                  )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
              columnWidths: incomeColumnWidths,
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(),
                  children: [
                    _dashboardPdfCell(
                      'NO',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.black,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 3,
                      minFontSize: 7,
                    ),
                    _dashboardPdfCell(
                      'TANGGAL',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.black,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 8,
                    ),
                    _dashboardPdfCell(
                      'PLAT',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.black,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 6,
                      minFontSize: 6.8,
                    ),
                    _dashboardPdfCell(
                      'MUATAN',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.black,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 8,
                      minFontSize: 6.8,
                    ),
                    _dashboardPdfCell(
                      'MUAT',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.black,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 6,
                      minFontSize: 6.8,
                    ),
                    _dashboardPdfCell(
                      'BONGKAR',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.black,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 8,
                      minFontSize: 6.8,
                    ),
                    _dashboardPdfCell(
                      'TONASE',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.black,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 8,
                      minFontSize: 6.8,
                    ),
                    _dashboardPdfCell(
                      'HARGA',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.black,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 7,
                      minFontSize: 6.8,
                    ),
                    _dashboardPdfCell(
                      'TOTAL',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.black,
                      fontSize: 9,
                      hPadding: 4,
                      vPadding: tableRowVPadding,
                      singleLineAutoShrink: true,
                      softLimitChars: 7,
                      minFontSize: 6.8,
                    ),
                  ],
                ),
                ...List<pw.TableRow>.generate(printableRows.length, (index) {
                  final row = printableRows[index];
                  final hasData = index < invoiceDetailList.length;
                  const blankCell = '\u00A0';
                  final tonase = hasData ? _toNum(row['tonase']) : 0;
                  final harga = hasData ? _toNum(row['harga']) : 0;
                  final rowSubtotal = tonase * harga;
                  final armadaStartSource = row['armada_start_date'] ??
                      item['armada_start_date'] ??
                      row['tanggal'] ??
                      item['tanggal'];
                  final tanggal = hasData
                      ? _formatInvoiceTableDate(armadaStartSource)
                      : blankCell;
                  return pw.TableRow(
                    children: [
                      _dashboardPdfCell(
                        hasData ? '${index + 1}' : blankCell,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 2,
                        minFontSize: 7,
                      ),
                      _dashboardPdfCell(
                        tanggal,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 10,
                      ),
                      _dashboardPdfCell(
                        hasData ? resolveNoPolisi(row) : blankCell,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 12,
                      ),
                      _dashboardPdfCell(
                        hasData ? '${row['muatan'] ?? '-'}' : blankCell,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 14,
                        minFontSize: 6.5,
                      ),
                      _dashboardPdfCell(
                        hasData
                            ? _normalizeInvoicePrintLocationLabel(
                                row['lokasi_muat'],
                              )
                            : blankCell,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 32,
                        minFontSize: 6.5,
                      ),
                      _dashboardPdfCell(
                        hasData
                            ? _normalizeInvoicePrintLocationLabel(
                                row['lokasi_bongkar'],
                              )
                            : blankCell,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 32,
                        minFontSize: 6.5,
                      ),
                      _dashboardPdfCell(
                        hasData ? formatTonase(tonase) : blankCell,
                        alignCenter: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 8,
                      ),
                      _dashboardPdfCell(
                        hasData ? formatHargaPerTon(harga) : blankCell,
                        alignRight: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 10,
                        minFontSize: 6.2,
                      ),
                      _dashboardPdfCell(
                        hasData ? formatRupiahNoPrefix(rowSubtotal) : blankCell,
                        alignRight: true,
                        hPadding: 4,
                        vPadding: tableRowVPadding,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 12,
                        minFontSize: 6.8,
                      ),
                    ],
                  );
                }),
              ],
            ),
          if (isCompanyInvoice && !excelTableIncludesSummary) ...[
            pw.LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints?.maxWidth ?? 0;
                final fixedWidthTotal = List<double>.generate(
                  incomeColumnWidths.length,
                  (i) => fixedColWidth(i),
                ).fold(0.0, (sum, w) => sum + w);
                final flexWeightTotal = List<double>.generate(
                  incomeColumnWidths.length,
                  (i) => flexColWeight(i),
                ).fold(0.0, (sum, w) => sum + w);
                final usableFlexWidth = max(0.0, tableWidth - fixedWidthTotal);
                double colWidth(int index) {
                  final fixed = fixedColWidth(index);
                  if (fixed > 0) return fixed;
                  final flex = flexColWeight(index);
                  if (flexWeightTotal <= 0 || flex <= 0) return 0;
                  return usableFlexWidth * (flex / flexWeightTotal);
                }

                final leadPrefixWidth = colWidth(0);
                final leftMergeWidth = colWidth(1) + colWidth(2);
                final middleGapWidth = colWidth(3) + colWidth(4) + colWidth(5);
                final mergedLabelWidth = colWidth(6) + colWidth(7);
                final totalWidth = colWidth(8);
                final compactRenderedTableWidth = compact &&
                        excelTableRender != null &&
                        tableWidth > 0 &&
                        excelTableRender.aspectRatio > 0
                    ? compactExcelRenderHeight * excelTableRender.aspectRatio
                    : tableWidth;
                final totalWidthScale = compact &&
                        tableWidth > 0 &&
                        compactRenderedTableWidth > 0
                    ? (compactRenderedTableWidth / tableWidth).clamp(1.0, 1.4)
                    : 1.0;
                final effectiveTotalWidth = totalWidth * totalWidthScale;
                final summaryExtraWidth = compact ? 16.0 : 0.0;
                final finalTotalWidth = effectiveTotalWidth + summaryExtraWidth;
                final effectiveMergedLabelWidth = max(
                  0.0,
                  mergedLabelWidth - (finalTotalWidth - totalWidth),
                );

                return buildCompanySummaryBlock(
                  leadPrefixWidth: leadPrefixWidth,
                  leftMergeWidth: leftMergeWidth,
                  middleGapWidth: middleGapWidth,
                  mergedLabelWidth: effectiveMergedLabelWidth,
                  totalWidth: finalTotalWidth,
                  subtotalValue: formatRupiahNoPrefix(subtotal),
                  pphValue: formatRupiahNoPrefix(pph),
                  totalValue: formatRupiahNoPrefix(total),
                  leftText: 'Hormat kami,',
                );
              },
            ),
          ],
          pw.SizedBox(height: 0),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: isCompanyInvoice
                    ? pw.SizedBox()
                    : pw.Padding(
                        padding: pw.EdgeInsets.only(left: signatureLeftOffset),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.SizedBox(height: signatureTextFontSize + 1),
                            pw.SizedBox(height: compact ? 58 : 84),
                            pw.Padding(
                              padding: pw.EdgeInsets.only(
                                left:
                                    signatureNameOffset + (compact ? -11 : -16),
                              ),
                              child: pw.Text(
                                'A N T O K',
                                style: pw.TextStyle(
                                  fontSize: signatureTextFontSize,
                                  fontWeight: pw.FontWeight.bold,
                                  decoration: pw.TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              pw.SizedBox(width: 16),
              pw.SizedBox(
                width: compact ? 280 : 320,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    if (!isCompanyInvoice && !excelTableIncludesSummary)
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text(
                            'TOTAL BAYAR Rp.',
                            style: pw.TextStyle(
                              fontSize: infoFont,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(width: summaryValueGap),
                          pw.Text(
                            formatRupiahNoPrefix(total),
                            style: pw.TextStyle(
                              fontSize: infoFont,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    pw.SizedBox(height: summaryBoxGap),
                    (isCompanyInvoice
                        ? pw.Transform.translate(
                            offset: const PdfPoint(-0.5, -5),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                              children: [
                                pw.Container(
                                  alignment: pw.Alignment.center,
                                  padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: pw.BoxDecoration(
                                    border: pw.Border.all(
                                      color: const PdfColor(
                                        252 / 255,
                                        2 / 255,
                                        0,
                                      ),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: pw.Text(
                                    'Rekening BCA a/c 6155345601 a/n CV AS NUSA TRANS\nNPWP 096.775.534.9-617.000',
                                    textAlign: pw.TextAlign.center,
                                    style: pw.TextStyle(
                                      fontSize: infoFont,
                                      color: PdfColors.blue700,
                                      fontWeight: pw.FontWeight.bold,
                                      fontStyle: pw.FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : pw.Transform.translate(
                            offset: const PdfPoint(-1, -3),
                            child: pw.Container(
                              alignment: pw.Alignment.center,
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(
                                  color: PdfColors.blue700,
                                  width: 1.2,
                                ),
                              ),
                              child: pw.Text(
                                'Rekening BCA a/c 1730290001 a/n BUDI SUKAMTO',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  fontSize: infoFont,
                                  color: PdfColors.blue700,
                                  fontWeight: pw.FontWeight.bold,
                                  fontStyle: pw.FontStyle.italic,
                                ),
                              ),
                            ),
                          )),
                  ],
                ),
              ),
            ],
          ),
          if (isCompanyInvoice)
            pw.LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints?.maxWidth ?? 0;
                final fixedWidthTotal = List<double>.generate(
                  incomeColumnWidths.length,
                  (i) => fixedColWidth(i),
                ).fold(0.0, (sum, width) => sum + width);
                final flexWeightTotal = List<double>.generate(
                  incomeColumnWidths.length,
                  (i) => flexColWeight(i),
                ).fold(0.0, (sum, width) => sum + width);
                final usableFlexWidth =
                    max(0.0, availableWidth - fixedWidthTotal);

                double colWidth(int index) {
                  final fixed = fixedColWidth(index);
                  if (fixed > 0) return fixed;
                  final flex = flexColWeight(index);
                  if (flexWeightTotal <= 0 || flex <= 0) return 0;
                  return usableFlexWidth * (flex / flexWeightTotal);
                }

                final leadPrefixWidth = colWidth(0);
                final leftMergeWidth = colWidth(1) + colWidth(2);
                final renderedTableWidth = compact &&
                        excelTableRender != null &&
                        excelTableRender.aspectRatio > 0
                    ? compactExcelRenderHeight * excelTableRender.aspectRatio
                    : availableWidth +
                        tableHorizontalBleedLeft +
                        tableHorizontalBleedRight;
                final expandedWidth = availableWidth +
                    tableHorizontalBleedLeft +
                    tableHorizontalBleedRight;
                final renderedLeft = -tableHorizontalBleedLeft +
                    ((expandedWidth - renderedTableWidth) / 2);
                final logicalTableWidth = fixedWidthTotal + usableFlexWidth <= 0
                    ? availableWidth
                    : fixedWidthTotal + usableFlexWidth;
                final tableScale = logicalTableWidth <= 0
                    ? 1.0
                    : renderedTableWidth / logicalTableWidth;
                final hormatCenterX = renderedLeft +
                    ((leadPrefixWidth + (leftMergeWidth / 2)) * tableScale);
                final antokWidth = compact ? 100.0 : 112.0;
                final antokShiftLeft = compact ? 8.0 : 9.0;
                final antokTopOffset = compact ? 2.0 : 3.0;
                final antokLeft = max(
                  0.0,
                  min(
                    availableWidth - antokWidth,
                    hormatCenterX - (antokWidth / 2) - antokShiftLeft,
                  ),
                );

                return pw.Padding(
                  padding: pw.EdgeInsets.only(top: compact ? 3 : 5),
                  child: pw.SizedBox(
                    width: availableWidth,
                    height: signatureTextFontSize + 3,
                    child: pw.Stack(
                      children: [
                        pw.Positioned(
                          left: antokLeft,
                          top: antokTopOffset,
                          child: pw.SizedBox(
                            width: antokWidth,
                            child: pw.Text(
                              'A N T O K',
                              textAlign: pw.TextAlign.center,
                              maxLines: 1,
                              style: pw.TextStyle(
                                fontSize: signatureTextFontSize,
                                fontWeight: pw.FontWeight.bold,
                                decoration: pw.TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      );
    }

    final invoiceTableRenderMode =
        isCompanyInvoice ? 'table_with_summary' : 'table_with_total';
    final invoiceTableHasEmbeddedSummary = invoiceTableRenderMode != 'table';
    final compactExcelTableImage = !usePortrait
        ? await buildExcelTableImage(
            compact: true,
            renderMode: invoiceTableRenderMode,
          )
        : null;
    final fullExcelTableImage = usePortrait
        ? await buildExcelTableImage(
            compact: false,
            renderMode: invoiceTableRenderMode,
          )
        : null;
    final pdfName = 'invoice-${host._safePdfFileName(invoiceNumber)}';
    final pdfPageFormat = PdfPageFormat(
      8.5 * PdfPageFormat.inch,
      13.0 * PdfPageFormat.inch,
    );
    final pdfMarginHorizontal = usePortrait ? 24.0 : 18.0;
    final pdfMarginTop = usePortrait ? 12.0 : 6.5;
    final pdfMarginBottom = usePortrait ? 15.0 : 9.0;
    final tableRenderInfo = usePortrait
        ? fullExcelTableImage?.renderSource
        : compactExcelTableImage?.renderSource;
    final doc = pw.Document();

    if (usePortrait) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: pdfPageFormat,
          margin: pw.EdgeInsets.fromLTRB(
            pdfMarginHorizontal,
            pdfMarginTop,
            pdfMarginHorizontal,
            pdfMarginBottom,
          ),
          build: (_) => [
            buildInvoiceContent(
              compact: false,
              excelTableRender: fullExcelTableImage,
              excelTableHasEmbeddedSummary: invoiceTableHasEmbeddedSummary,
            ),
          ],
        ),
      );
    } else {
      final usableHeight =
          pdfPageFormat.height - pdfMarginTop - pdfMarginBottom;
      final halfHeight = usableHeight / 2;
      doc.addPage(
        pw.Page(
          pageFormat: pdfPageFormat,
          margin: pw.EdgeInsets.fromLTRB(
            pdfMarginHorizontal,
            pdfMarginTop,
            pdfMarginHorizontal,
            pdfMarginBottom,
          ),
          build: (_) {
            return pw.Column(
              children: [
                pw.Container(
                  height: halfHeight,
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: buildInvoiceContent(
                    compact: true,
                    excelTableRender: compactExcelTableImage,
                    excelTableHasEmbeddedSummary:
                        invoiceTableHasEmbeddedSummary,
                  ),
                ),
                pw.SizedBox(
                  height: halfHeight,
                ),
              ],
            );
          },
        ),
      );
    }
    final pdfBytes = await doc.save();
    final confirmed = await host._showPdfPreviewDialog(
      bytes: pdfBytes,
      title: pdfName,
      renderInfo: tableRenderInfo,
    );
    if (!confirmed) return false;
    await Printing.layoutPdf(
      name: pdfName,
      onLayout: (_) async => pdfBytes,
    );
    if (markAsFixed) {
      await host.markInvoicesFixed(
        fixedInvoiceIds ?? <String>['${item['id'] ?? ''}'],
        batch: fixedBatch,
      );
    }
    if (showSuccessPopup && host.mounted) {
      host.showPrintSnack(
        host.translatePrintText(
          'Invoice berhasil diproses untuk dicetak.',
          'Invoice has been prepared for printing.',
        ),
      );
    }
    return true;
  } catch (e) {
    if (!host.mounted) return false;
    host.showPrintSnack(
      'Gagal print invoice: ${e.toString().replaceFirst('Exception: ', '')}',
      error: true,
    );
    return false;
  }
}

extension _AdminInvoiceListViewPrinting on _DashboardInvoicePrintHost {
  String _safePdfFileName(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'invoice' : safe;
  }

  bool get _canRenderInvoiceTableWithExcel => !kIsWeb && Platform.isWindows;
  bool get _canRenderInvoiceTableViaCloudService =>
      !kIsWeb && AppConfig.hasInvoiceRenderService;

  Uri? _invoiceRenderServiceUri() {
    if (!_canRenderInvoiceTableViaCloudService) return null;
    return AppSecurity.buildSecureRemoteUri(
      AppConfig.invoiceRenderServiceUrl,
      appendPathSegment: 'render-table',
      allowLocalhost: kDebugMode,
    );
  }

  bool _isRowMeaningfullyFilled(Map<String, String> row) {
    const keys = <String>[
      'tanggal',
      'plat',
      'muatan',
      'muat',
      'bongkar',
      'tonase',
      'harga',
      'total',
    ];

    for (final key in keys) {
      if ((row[key] ?? '').trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Sort by bongkar ASC (A-Z), empty bongkar at bottom.
  /// After sorting, re-number `no` only for rows that actually contain data.
  /// Blank/filler rows keep `no` empty.
  List<Map<String, String>> _sortRowsByBongkarAsc(
    List<Map<String, String>> rows,
  ) {
    final copied = rows
        .map((row) => Map<String, String>.from(row))
        .toList(growable: false);

    final filledRows = copied.where(_isRowMeaningfullyFilled).toList();
    final emptyRows =
        copied.where((row) => !_isRowMeaningfullyFilled(row)).toList();

    filledRows.sort((a, b) {
      final bongkarA = (a['bongkar'] ?? '').trim().toLowerCase();
      final bongkarB = (b['bongkar'] ?? '').trim().toLowerCase();

      if (bongkarA.isEmpty && bongkarB.isEmpty) return 0;
      if (bongkarA.isEmpty) return 1;
      if (bongkarB.isEmpty) return -1;

      return bongkarA.compareTo(bongkarB);
    });

    final renumberedFilledRows = <Map<String, String>>[];
    for (var i = 0; i < filledRows.length; i++) {
      final row = Map<String, String>.from(filledRows[i]);
      row['no'] = '${i + 1}';
      renumberedFilledRows.add(row);
    }

    final normalizedEmptyRows = emptyRows.map((row) {
      final copy = Map<String, String>.from(row);
      copy['no'] = '';
      return copy;
    }).toList();

    return <Map<String, String>>[
      ...renumberedFilledRows,
      ...normalizedEmptyRows,
    ];
  }

  Future<Uint8List?> _rasterizeInvoiceTablePdfBytes(
    Uint8List pdfBytes, {
    required String renderMode,
  }) async {
    final rasterPage = await Printing.raster(
      pdfBytes,
      pages: const [0],
      dpi: 300,
    ).first;
    return _trimWhiteMarginsFromPng(
      await rasterPage.toPng(),
      horizontalPadding: renderMode == 'summary' ? 0 : 6,
      verticalPadding: renderMode == 'summary' ? 0 : 1,
    );
  }

  Future<Uint8List?> _renderInvoiceTableImageWithExcel({
    required List<Map<String, String>> rows,
    required int rowCount,
    String renderMode = 'table',
    Map<String, String>? summaryValues,
  }) async {
    if (!_canRenderInvoiceTableWithExcel) return null;

    final sortedRows = _sortRowsByBongkarAsc(rows);

    try {
      final tempDir = await Directory.systemTemp.createTemp(
        'cvant_invoice_excel_',
      );
      final templateBytes =
          await rootBundle.load('assets/templates/invoice_table_template.xlsx');
      final templatePath =
          '${tempDir.path}${Platform.pathSeparator}invoice_table_template.xlsx';
      final payloadPath =
          '${tempDir.path}${Platform.pathSeparator}invoice_table_payload.json';
      final outputPath =
          '${tempDir.path}${Platform.pathSeparator}invoice_table.pdf';
      final scriptPath =
          '${tempDir.path}${Platform.pathSeparator}render_invoice_table.ps1';

      await File(templatePath).writeAsBytes(
        templateBytes.buffer.asUint8List(),
        flush: true,
      );
      final scriptContent = await rootBundle
          .loadString('tooling/windows/render_invoice_table.ps1');
      await File(scriptPath).writeAsString(scriptContent, flush: true);
      await File(payloadPath).writeAsString(
        jsonEncode({
          'rowCount': rowCount,
          'rows': sortedRows,
          if (summaryValues != null) 'summaryValues': summaryValues,
        }),
        flush: true,
      );

      final result = await Process.run(
        'powershell',
        <String>[
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          scriptPath,
          '-TemplatePath',
          templatePath,
          '-PayloadPath',
          payloadPath,
          '-OutputPath',
          outputPath,
          '-RenderMode',
          renderMode,
        ],
      );
      if (result.exitCode != 0) {
        AppSecurity.debugLog(
          'Excel table render failed',
          error: '${result.stderr}\n${result.stdout}',
        );
        return null;
      }
      final file = File(outputPath);
      if (!await file.exists()) return null;
      final pdfBytes = await file.readAsBytes();
      final bytes = await _rasterizeInvoiceTablePdfBytes(
        pdfBytes,
        renderMode: renderMode,
      );
      unawaited(tempDir.delete(recursive: true));
      return bytes;
    } catch (error, stackTrace) {
      AppSecurity.debugLog(
        'Excel table render error',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<Uint8List?> _renderInvoiceTableImageViaCloudService({
    required List<Map<String, String>> rows,
    required int rowCount,
    String renderMode = 'table',
    Map<String, String>? summaryValues,
  }) async {
    final uri = _invoiceRenderServiceUri();
    if (uri == null) return null;

    final sortedRows = _sortRowsByBongkarAsc(rows);

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/pdf');
      request.write(
        jsonEncode({
          'rowCount': rowCount,
          'rows': sortedRows,
          'renderMode': renderMode,
          if (summaryValues != null) 'summaryValues': summaryValues,
        }),
      );

      final response = await request.close().timeout(
            const Duration(seconds: 30),
          );
      final bytesBuilder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        bytesBuilder.add(chunk);
      }
      final responseBytes = bytesBuilder.takeBytes();

      if (response.statusCode != HttpStatus.ok) {
        final errorText = utf8.decode(responseBytes, allowMalformed: true);
        AppSecurity.debugLog(
          'Cloud invoice table render failed (${response.statusCode})',
          error: errorText,
        );
        return null;
      }

      return _rasterizeInvoiceTablePdfBytes(
        responseBytes,
        renderMode: renderMode,
      );
    } catch (error, stackTrace) {
      AppSecurity.debugLog(
        'Cloud invoice table render error',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      client.close(force: true);
    }
  }

  List<double> _buildPortableInvoiceTableWidths(double totalWidth) {
    const excelUnits = <double>[
      4.44,
      11.00,
      12.89,
      11.00,
      11.11,
      12.66,
      11.55,
      10.66,
      20.66,
    ];
    final totalUnits = excelUnits.fold<double>(0, (sum, value) => sum + value);
    final scale = totalUnits <= 0 ? 1.0 : totalWidth / totalUnits;
    return excelUnits.map((value) => value * scale).toList(growable: false);
  }

  Future<Uint8List?> _renderInvoiceTableImagePortable({
    required List<Map<String, String>> rows,
    required int rowCount,
    String renderMode = 'table',
    Map<String, String>? summaryValues,
  }) async {
    final sortedRows = _sortRowsByBongkarAsc(rows);

    try {
      const tableWidth = 608.0;
      const headerHeight = 21.0;
      const bodyHeight = 16.0;
      const summaryHeight = 16.0;
      const borderWidth = 0.8;
      const pagePadding = 1.0;
      final colWidths = _buildPortableInvoiceTableWidths(tableWidth);
      final tableColumnWidths = <int, pw.TableColumnWidth>{
        for (var index = 0; index < colWidths.length; index++)
          index: pw.FixedColumnWidth(colWidths[index]),
      };
      final hasEmbeddedSummary = summaryValues != null &&
          (renderMode == 'table_with_summary' ||
              renderMode == 'table_with_total');
      final summaryRowCount = renderMode == 'table_with_summary'
          ? 3
          : renderMode == 'table_with_total'
              ? 1
              : 0;
      final tableHeight = headerHeight + (bodyHeight * rowCount);
      final summaryBlockHeight = summaryHeight * summaryRowCount;
      final pageWidth = tableWidth + (pagePadding * 2);
      final pageHeight =
          tableHeight + summaryBlockHeight + (pagePadding * 2) + 2.0;

      pw.Widget buildTableCell(
        String text, {
        required bool header,
        bool alignRight = false,
        bool alignCenter = false,
        int softLimitChars = 12,
        double minFontSize = 6.8,
      }) {
        return _dashboardPdfCell(
          text,
          bold: header,
          alignRight: alignRight,
          alignCenter: alignCenter,
          textColor: PdfColors.black,
          fontSize: header ? 9 : 8.7,
          minFontSize: minFontSize,
          hPadding: 4,
          vPadding: header ? 2.6 : 2.2,
          fixedHeight: header ? headerHeight : bodyHeight,
          singleLineAutoShrink: true,
          softLimitChars: softLimitChars,
        );
      }

      pw.Widget buildSummaryValueCell(String text) {
        return pw.Container(
          height: summaryHeight,
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: borderWidth),
          ),
          child: pw.Text(
            text,
            textAlign: pw.TextAlign.right,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: 8.7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        );
      }

      pw.Widget buildSummaryLabelCell(
        String text, {
        required double width,
      }) {
        return pw.SizedBox(
          width: width,
          height: summaryHeight,
          child: buildTableCell(
            text,
            header: false,
            alignRight: true,
            softLimitChars: 13,
            minFontSize: 6.1,
          ),
        );
      }

      final tableWidget = pw.SizedBox(
        width: tableWidth,
        height: tableHeight,
        child: pw.Stack(
          children: [
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.black,
                width: borderWidth,
              ),
              columnWidths: tableColumnWidths,
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(),
                  children: [
                    buildTableCell(
                      'NO',
                      header: true,
                      alignCenter: true,
                      softLimitChars: 3,
                      minFontSize: 7,
                    ),
                    buildTableCell(
                      'TANGGAL',
                      header: true,
                      alignCenter: true,
                      softLimitChars: 8,
                    ),
                    buildTableCell(
                      'PLAT',
                      header: true,
                      alignCenter: true,
                      softLimitChars: 6,
                    ),
                    buildTableCell(
                      'MUATAN',
                      header: true,
                      alignCenter: true,
                      softLimitChars: 8,
                    ),
                    buildTableCell(
                      'MUAT',
                      header: true,
                      alignCenter: true,
                      softLimitChars: 6,
                    ),
                    buildTableCell(
                      'BONGKAR',
                      header: true,
                      alignCenter: true,
                      softLimitChars: 8,
                    ),
                    buildTableCell(
                      'TONASE',
                      header: true,
                      alignCenter: true,
                      softLimitChars: 8,
                    ),
                    buildTableCell(
                      'HARGA',
                      header: true,
                      alignCenter: true,
                      softLimitChars: 7,
                    ),
                    buildTableCell(
                      'TOTAL',
                      header: true,
                      alignCenter: true,
                      softLimitChars: 7,
                    ),
                  ],
                ),
                ...List<pw.TableRow>.generate(rowCount, (index) {
                  final row = index < sortedRows.length
                      ? sortedRows[index]
                      : const <String, String>{};
                  const blankCell = '\u00A0';

                  String value(String key) {
                    final text = (row[key] ?? '').trim();
                    return text.isEmpty ? blankCell : text;
                  }

                  return pw.TableRow(
                    children: [
                      buildTableCell(
                        value('no'),
                        header: false,
                        alignCenter: true,
                        softLimitChars: 2,
                        minFontSize: 7,
                      ),
                      buildTableCell(
                        value('tanggal'),
                        header: false,
                        alignCenter: true,
                        softLimitChars: 10,
                      ),
                      buildTableCell(
                        value('plat'),
                        header: false,
                        alignCenter: true,
                        softLimitChars: 12,
                      ),
                      buildTableCell(
                        value('muatan'),
                        header: false,
                        alignCenter: true,
                        softLimitChars: 14,
                        minFontSize: 6.5,
                      ),
                      buildTableCell(
                        value('muat'),
                        header: false,
                        alignCenter: true,
                        softLimitChars: 32,
                        minFontSize: 6.4,
                      ),
                      buildTableCell(
                        value('bongkar'),
                        header: false,
                        alignCenter: true,
                        softLimitChars: 32,
                        minFontSize: 6.4,
                      ),
                      buildTableCell(
                        value('tonase'),
                        header: false,
                        alignCenter: true,
                        softLimitChars: 8,
                      ),
                      buildTableCell(
                        value('harga'),
                        header: false,
                        alignRight: true,
                        softLimitChars: 10,
                        minFontSize: 6.2,
                      ),
                      buildTableCell(
                        value('total'),
                        header: false,
                        alignRight: true,
                        softLimitChars: 12,
                        minFontSize: 6.8,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.Positioned(
              left: 0,
              right: 0,
              top: 1.5,
              child: pw.Container(height: 0.8, color: PdfColors.black),
            ),
            pw.Positioned(
              left: 0,
              right: 0,
              top: headerHeight - 1.5,
              child: pw.Container(height: 0.8, color: PdfColors.black),
            ),
          ],
        ),
      );

      pw.Widget? summaryWidget;
      if (hasEmbeddedSummary) {
        if (renderMode == 'table_with_summary') {
          final leadPrefixWidth = colWidths[0];
          final leftMergeWidth = colWidths[1] + colWidths[2];
          final middleGapWidth = colWidths[3] + colWidths[4] + colWidths[5];
          final mergedLabelWidth = colWidths[6] + colWidths[7];
          final totalWidth = colWidths[8];
          summaryWidget = pw.SizedBox(
            width: tableWidth,
            height: summaryBlockHeight,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: leadPrefixWidth),
                pw.SizedBox(
                  width: leftMergeWidth,
                  height: summaryBlockHeight,
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Align(
                      alignment: pw.Alignment.topCenter,
                      child: pw.Text(
                        'Hormat kami,',
                        maxLines: 1,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(
                          fontSize: 8.7,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: middleGapWidth),
                pw.SizedBox(
                  width: mergedLabelWidth,
                  height: summaryBlockHeight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      buildSummaryLabelCell(
                        'SUBTOTAL Rp.',
                        width: mergedLabelWidth,
                      ),
                      buildSummaryLabelCell(
                        'PPH 2% Rp.',
                        width: mergedLabelWidth,
                      ),
                      buildSummaryLabelCell(
                        'TOTAL BAYAR Rp.',
                        width: mergedLabelWidth,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(
                  width: totalWidth,
                  height: summaryBlockHeight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      buildSummaryValueCell(summaryValues['subtotal'] ?? ''),
                      buildSummaryValueCell(summaryValues['pph'] ?? ''),
                      buildSummaryValueCell(summaryValues['total'] ?? ''),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else if (renderMode == 'table_with_total') {
          final spacerWidth = colWidths.take(7).fold<double>(
                0,
                (sum, width) => sum + width,
              );
          final labelWidth = colWidths[7];
          final totalWidth = colWidths[8];
          summaryWidget = pw.SizedBox(
            width: tableWidth,
            height: summaryBlockHeight,
            child: pw.Row(
              children: [
                pw.SizedBox(width: spacerWidth),
                buildSummaryLabelCell(
                  'TOTAL BAYAR Rp.',
                  width: labelWidth,
                ),
                pw.SizedBox(
                  width: totalWidth,
                  child: buildSummaryValueCell(summaryValues['total'] ?? ''),
                ),
              ],
            ),
          );
        }
      }

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageWidth, pageHeight),
          margin: const pw.EdgeInsets.all(pagePadding),
          build: (_) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                tableWidget,
                if (summaryWidget != null) summaryWidget,
              ],
            );
          },
        ),
      );

      final pdfBytes = await doc.save();
      final bytes = await _rasterizeInvoiceTablePdfBytes(
        pdfBytes,
        renderMode: 'table',
      );
      return bytes;
    } catch (error, stackTrace) {
      AppSecurity.debugLog(
        'Portable table render error',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<bool> _showPdfPreviewDialog({
    required Uint8List bytes,
    required String title,
    String? renderInfo,
  }) async {
    if (!mounted) return false;
    final shouldPrint = await showDialog<bool>(
          context: context,
          barrierColor: AppColors.popupOverlay,
          builder: (context) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 980,
                height: 760,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                if (renderInfo != null &&
                                    renderInfo.trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.isLight(context)
                                          ? const Color(0xFFE0F2FE)
                                          : const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: AppColors.isLight(context)
                                            ? const Color(0xFF7DD3FC)
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                    child: Text(
                                      renderInfo,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.isLight(context)
                                            ? const Color(0xFF0C4A6E)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context, false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: PdfPreview(
                        build: (_) async => bytes,
                        allowPrinting: false,
                        allowSharing: false,
                        canChangePageFormat: false,
                        canChangeOrientation: false,
                        canDebug: false,
                        pdfFileName: title,
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: CvantButtonStyles.outlined(
                              context,
                              color: AppColors.isLight(context)
                                  ? AppColors.textSecondaryLight
                                  : const Color(0xFFE2E8F0),
                              borderColor: AppColors.neutralOutline,
                            ),
                            child: Text(
                              translatePrintText('Tutup', 'Close'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: () => Navigator.pop(context, true),
                            style: CvantButtonStyles.filled(
                              context,
                              color: AppColors.success,
                            ),
                            icon: const Icon(Icons.print_outlined),
                            label: Text(
                              translatePrintText('Cetak', 'Print'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;
    return shouldPrint;
  }
}
