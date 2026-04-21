part of 'dashboard_page.dart';

extension _AdminInvoiceListViewStatePreviewSupport
    on _AdminInvoiceListViewState {
  Future<void> _openInvoicePreview(Map<String, dynamic> item) async {
    final previewItem = await _resolveLatestInvoiceItem(item);
    final armadas = await widget.repository.fetchArmadas();
    final armadaPlateById = <String, String>{
      for (final armada in armadas)
        '${armada['id'] ?? ''}'.trim():
            '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
    };
    final armadaPlateByName = <String, String>{
      for (final armada in armadas)
        _normalizeArmadaNameKey('${armada['nama_truk'] ?? ''}'):
            '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
    };
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        final detailList = _toDetailList(previewItem['rincian']);
        final customerName = '${previewItem['nama_pelanggan'] ?? ''}'.trim();
        final invoiceEntityLabel = _resolveInvoiceEntityLabel(
          invoiceEntity: previewItem['invoice_entity'],
          invoiceNumber: previewItem['no_invoice'],
          customerName: customerName,
        );
        final isCompanyInvoice = _resolveIsCompanyInvoice(
          invoiceEntity: previewItem['invoice_entity'],
          invoiceNumber: previewItem['no_invoice'],
          customerName: customerName,
        );
        final subtotal = _toNum(previewItem['total_biaya']);
        final pph = isCompanyInvoice ? _toNum(previewItem['pph']) : 0.0;
        final total = isCompanyInvoice ? max(0.0, subtotal - pph) : subtotal;
        return AlertDialog(
          title: Text(_t('Preview Invoice', 'Invoice Preview')),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${_t('Customer', 'Customer')}: ${previewItem['nama_pelanggan'] ?? '-'}'),
                  Text(
                      '${_t('Email', 'Email')}: ${previewItem['email'] ?? '-'}'),
                  Text(
                      '${_t('Tanggal', 'Date')}: ${Formatters.dmy(previewItem['tanggal'] ?? previewItem['armada_start_date'])}'),
                  Text('${_t('Tipe', 'Type')}: $invoiceEntityLabel'),
                  Text(
                      '${_t('Status', 'Status')}: ${previewItem['status'] ?? '-'}'),
                  const SizedBox(height: 8),
                  Text(
                    '${_t('Total', 'Total')}: ${Formatters.rupiah(total)}',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (detailList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _t('Rincian Invoice', 'Invoice Details'),
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ...detailList.asMap().entries.map((entry) {
                      final index = entry.key;
                      final row = entry.value;
                      final tonase = _toNum(row['tonase']);
                      final harga = _toNum(row['harga']);
                      final subtotalDetail =
                          _resolveInvoiceDetailSubtotalShared(row);
                      final driver = '${row['nama_supir'] ?? ''}'.trim();
                      final muatan = '${row['muatan'] ?? ''}'.trim();
                      final plate = _resolveDetailPlateText(
                        row,
                        armadaPlateById: armadaPlateById,
                        armadaPlateByName: armadaPlateByName,
                        fallbackArmadaId: '${previewItem['armada_id'] ?? ''}',
                      );
                      final departureDate = Formatters.dmy(
                        row['armada_start_date'] ??
                            previewItem['armada_start_date'],
                      );
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: AppColors.cardBorder(context)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_t('Rincian', 'Detail')} ${index + 1}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_t('Keberangkatan', 'Departure')}: $departureDate',
                            ),
                            Text(
                              '${_t('Rute', 'Route')}: ${row['lokasi_muat'] ?? '-'} - ${row['lokasi_bongkar'] ?? '-'}',
                            ),
                            if (plate.isNotEmpty)
                              Text('${_t('Plat', 'Plate')}: $plate'),
                            if (muatan.isNotEmpty)
                              Text('${_t('Muatan', 'Cargo')}: $muatan'),
                            if (driver.isNotEmpty)
                              Text('${_t('Nama Supir', 'Driver')}: $driver'),
                            Text(
                              '${_t('Tonase', 'Tonnage')}: ${tonase > 0 ? formatInvoiceTonase(tonase) : '-'}',
                            ),
                            Text(
                              '${_t('Harga / Ton', 'Price / Ton')}: ${harga > 0 ? formatInvoiceHargaPerTon(harga) : '-'}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_t('Subtotal', 'Subtotal')}: ${Formatters.rupiah(subtotalDetail)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (!_isPengurus)
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _printSingleInvoiceFromPreview(previewItem);
                },
                style: CvantButtonStyles.outlined(
                  context,
                  color: AppColors.blue,
                  borderColor: AppColors.blue,
                  minimumSize: const Size(96, 40),
                ),
                icon: const Icon(Icons.print_outlined, size: 16),
                label: Text(_t('Print', 'Print')),
              ),
            FilledButton(
              style: CvantButtonStyles.filled(
                context,
                color: AppColors.blue,
                minimumSize: const Size(96, 40),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(_t('Tutup', 'Close')),
            ),
          ],
        );
      },
    );
  }

  String _resolveInvoiceEntity({
    dynamic invoiceEntity,
    dynamic invoiceNumber,
    dynamic customerName,
    bool fallback = true,
  }) {
    return _resolveInvoiceEntityShared(
      invoiceEntity: invoiceEntity,
      invoiceNumber: invoiceNumber,
      customerName: customerName,
      fallback: fallback,
    );
  }

  bool _resolveIsCompanyInvoice({
    dynamic invoiceEntity,
    dynamic invoiceNumber,
    dynamic customerName,
    bool fallback = true,
  }) {
    return _resolveIsCompanyInvoiceShared(
      invoiceEntity: invoiceEntity,
      invoiceNumber: invoiceNumber,
      customerName: customerName,
      fallback: fallback,
    );
  }

  String _resolveInvoiceEntityLabel({
    dynamic invoiceEntity,
    dynamic invoiceNumber,
    dynamic customerName,
  }) {
    return _resolveInvoiceEntityLabelShared(
      invoiceEntity: invoiceEntity,
      invoiceNumber: invoiceNumber,
      customerName: customerName,
    );
  }

  Color _invoiceEntityAccentColor({
    dynamic invoiceEntity,
    dynamic invoiceNumber,
    dynamic customerName,
  }) {
    return _resolveInvoiceEntityAccentColorShared(
      invoiceEntity: invoiceEntity,
      invoiceNumber: invoiceNumber,
      customerName: customerName,
    );
  }

  String _displayInvoiceNumber(String number) =>
      _displayInvoiceNumberShared(number);

  int _printInvoiceRomanToMonth(String roman) {
    const monthByRoman = <String, int>{
      'I': 1,
      'II': 2,
      'III': 3,
      'IV': 4,
      'V': 5,
      'VI': 6,
      'VII': 7,
      'VIII': 8,
      'IX': 9,
      'X': 10,
      'XI': 11,
      'XII': 12,
    };
    return monthByRoman[roman.trim().toUpperCase()] ?? 0;
  }

  String _buildPrintInvoiceNumber({
    required int sequence,
    required DateTime issuedDate,
    required String invoiceEntity,
  }) {
    final seq = sequence.toString().padLeft(2, '0');
    final mm = issuedDate.toLocal().month.toString().padLeft(2, '0');
    final yy = (issuedDate.toLocal().year % 100).toString().padLeft(2, '0');
    final code = Formatters.invoiceEntityCode(invoiceEntity);
    return '$code$yy$mm$seq';
  }

  int _extractPrintInvoiceSequence({
    required String invoiceNumber,
    required int month,
    required int yearTwoDigits,
    required String invoiceEntity,
    DateTime? referenceDate,
  }) {
    final cleaned = invoiceNumber
        .replaceFirst(RegExp(r'^\s*NO\s*:\s*', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) return 0;

    final normalizedEntity = Formatters.normalizeInvoiceEntity(invoiceEntity);
    final compactPattern = RegExp(
      r'^(CV\.ANT|PT\.ANT|BS)(\d{2})(\d{2})(\d{2,})$',
      caseSensitive: false,
    );
    final compactMatch = compactPattern.firstMatch(cleaned);
    if (compactMatch != null) {
      final prefix = (compactMatch.group(1) ?? '').toUpperCase().trim();
      final rowYear = int.tryParse(compactMatch.group(2) ?? '') ?? -1;
      final rowMonth = int.tryParse(compactMatch.group(3) ?? '') ?? 0;
      final seq = int.tryParse(compactMatch.group(4) ?? '') ?? 0;
      final sameType = prefix == Formatters.invoiceEntityCode(normalizedEntity);
      if (sameType && rowMonth == month && rowYear == yearTwoDigits) {
        return seq;
      }
      return 0;
    }

    final newPattern = RegExp(
      r'^(\d{1,4})\s*\/\s*(CV\.ANT|PT\.ANT|BS|ANT)\s*\/\s*([IVX]+)\s*\/\s*(\d{2})\s*$',
      caseSensitive: false,
    );
    final newMatch = newPattern.firstMatch(cleaned);
    if (newMatch != null) {
      final seq = int.tryParse(newMatch.group(1) ?? '') ?? 0;
      final prefix = (newMatch.group(2) ?? '').toUpperCase().trim();
      final rowMonth = _printInvoiceRomanToMonth(newMatch.group(3) ?? '');
      final rowYear = int.tryParse(newMatch.group(4) ?? '') ?? -1;
      final sameType = normalizedEntity == Formatters.invoiceEntityPersonal
          ? (prefix == 'BS' || prefix == 'ANT')
          : prefix == Formatters.invoiceEntityCode(normalizedEntity);
      if (sameType && rowMonth == month && rowYear == yearTwoDigits) {
        return seq;
      }
      return 0;
    }

    final legacyPattern = RegExp(
      r'^(480\s*\/\s*CV\.ANT|268\s*\/\s*ANT)\s*\/\s*([IVX]+)\s*\/\s*(\d+)\s*$',
      caseSensitive: false,
    );
    final legacyMatch = legacyPattern.firstMatch(cleaned);
    if (legacyMatch != null) {
      final prefix =
          (legacyMatch.group(1) ?? '').toUpperCase().replaceAll(' ', '');
      final sameType = normalizedEntity == Formatters.invoiceEntityCvAnt
          ? prefix.startsWith('480/CV.ANT')
          : normalizedEntity == Formatters.invoiceEntityPersonal
              ? prefix.startsWith('268/ANT')
              : false;
      if (!sameType) return 0;

      final rowMonth = _printInvoiceRomanToMonth(legacyMatch.group(2) ?? '');
      if (rowMonth != month) return 0;
      final rowYear =
          referenceDate == null ? yearTwoDigits : (referenceDate.year % 100);
      if (rowYear != yearTwoDigits) return 0;
      return int.tryParse(legacyMatch.group(3) ?? '') ?? 0;
    }

    final oldInc =
        RegExp(r'^INC-(\d{2})-(\d{4})-(\d{1,})$', caseSensitive: false)
            .firstMatch(cleaned.toUpperCase());
    if (oldInc != null) {
      final rowMonth = int.tryParse(oldInc.group(1) ?? '') ?? 0;
      final rowYear = (int.tryParse(oldInc.group(2) ?? '') ?? 0) % 100;
      if (rowMonth != month || rowYear != yearTwoDigits) return 0;
      return int.tryParse(oldInc.group(3) ?? '') ?? 0;
    }

    return 0;
  }

  Future<bool> _printInvoicePdf(
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
      final invoiceDetailList =
          detailList.isNotEmpty ? detailList : _toDetailList(item['rincian']);
      // <= 16 detail rows: print in half-sheet layout (50:50 on portrait paper).
      // > 16 detail rows: switch to full-sheet portrait layout.
      final usePortrait = invoiceDetailList.length > 16;
      final invoiceRawNumber = '${item['no_invoice'] ?? '-'}';
      final customerName = '${item['nama_pelanggan'] ?? ''}';
      final resolvedInvoiceEntity = _resolveInvoiceEntity(
        invoiceEntity: item['invoice_entity'],
        invoiceNumber: invoiceRawNumber,
        customerName: customerName,
      );
      final isCompanyInvoice = _resolveIsCompanyInvoice(
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
      final invoiceNumber = _displayInvoiceNumber(
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
        final logoBytes =
            await _loadBinaryAssetWithFileFallback('assets/images/iconapk.png');
        kopLogo = pw.MemoryImage(logoBytes);
      } catch (_) {
        kopLogo = null;
      }
      pw.MemoryImage? companyKopImage;
      try {
        final kopAsset = resolvedInvoiceEntity == Formatters.invoiceEntityPtAnt
            ? 'assets/images/kopsuratpt.png'
            : 'assets/images/kopsurat.jpeg';
        final kopBytes = await _loadBinaryAssetWithFileFallback(kopAsset);
        companyKopImage = pw.MemoryImage(kopBytes);
      } catch (_) {
        companyKopImage = null;
      }
      final armadas = await widget.repository.fetchArmadas();
      final armadaPlateById = <String, String>{
        for (final armada in armadas)
          '${armada['id'] ?? ''}':
              '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
      };
      final armadaPlateByName = <String, String>{
        for (final armada in armadas)
          _normalizeArmadaNameKey('${armada['nama_truk'] ?? ''}'):
              '${armada['plat_nomor'] ?? ''}'.trim().toUpperCase(),
      };

      String resolveNoPolisi(Map<String, dynamic> row) {
        return _resolveDetailPlateText(
          row,
          armadaPlateById: armadaPlateById,
          armadaPlateByName: armadaPlateByName,
          fallbackArmadaId: '${item['armada_id'] ?? ''}',
        );
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
        final baseRowsPerSheet = compact
            ? (isCompanyInvoice ? 18 : 21)
            : (isCompanyInvoice ? 40 : 43);
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
        final summaryValues = renderMode == 'table_with_summary' ||
                renderMode == 'table_with_total'
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
          final rowSubtotal =
              hasData ? _resolveInvoiceDetailSubtotalShared(row) : 0;
          final armadaStartSource = row['armada_start_date'] ??
              item['armada_start_date'] ??
              row['tanggal'] ??
              item['tanggal'];
          payloadRows.add({
            'no': hasData ? '${index + 1}' : '',
            'tanggal':
                hasData ? _formatInvoiceTableDate(armadaStartSource) : '',
            'plat': hasData ? resolveNoPolisi(row) : '',
            'muatan': hasData ? '${row['muatan'] ?? '-'}' : '',
            'muat': hasData
                ? _normalizeInvoicePrintLocationLabel(row['lokasi_muat'])
                : '',
            'bongkar': hasData
                ? _normalizeInvoicePrintLocationLabel(row['lokasi_bongkar'])
                : '',
            'tonase': hasData && tonase > 0 ? formatTonase(tonase) : '',
            'harga': hasData && harga > 0 ? formatHargaPerTon(harga) : '',
            'total': hasData ? formatRupiahNoPrefix(rowSubtotal) : '',
          });
        }
        Uint8List? bytes;
        var renderSource = 'Excel template renderer';
        bytes = await _renderInvoiceTableImageWithExcel(
          rows: payloadRows,
          rowCount: printableRows.length,
          renderMode: renderMode,
          summaryValues: summaryValues,
        );
        if (bytes != null) {
          renderSource = 'Excel local (Windows)';
        } else {
          final cloudBytes = await _renderInvoiceTableImageViaCloudService(
            rows: payloadRows,
            rowCount: printableRows.length,
            renderMode: renderMode,
            summaryValues: summaryValues,
          );
          if (cloudBytes != null) {
            bytes = cloudBytes;
            renderSource = 'Excel cloud service';
          } else {
            bytes = await _renderInvoiceTableImagePortable(
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

      final pdfFonts = await _loadDashboardPdfFontBundle();
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
        final incomeColumnWidths = _buildIncomeTableColumnWidths(printableRows);
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
                            leftText,
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
                        label,
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
                    text,
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
                            leftText,
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
                                font: pw.Font.helveticaBold(),
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
                          padding:
                              pw.EdgeInsets.only(right: recipientShiftLeft),
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
                                    customerName,
                                    maxLines: 1,
                                    textAlign: pw.TextAlign.center,
                                    style: pw.TextStyle(
                                      font: pw.Font.helveticaBoldOblique(),
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
                          padding:
                              pw.EdgeInsets.only(right: recipientShiftLeft),
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
                                (kopLocationUpper ?? '-'),
                                maxLines: 1,
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(
                                  font: pw.Font.helveticaBoldOblique(),
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
                      _pdfCell(
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
                      _pdfCell(
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
                      _pdfCell(
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
                      _pdfCell(
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
                      _pdfCell(
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
                      _pdfCell(
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
                      _pdfCell(
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
                      _pdfCell(
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
                      _pdfCell(
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
                    const blankCell = '';
                    final tonase = hasData ? _toNum(row['tonase']) : 0;
                    final harga = hasData ? _toNum(row['harga']) : 0;
                    final rowSubtotal =
                        hasData ? _resolveInvoiceDetailSubtotalShared(row) : 0;
                    final armadaStartSource = row['armada_start_date'] ??
                        item['armada_start_date'] ??
                        row['tanggal'] ??
                        item['tanggal'];
                    final tanggal = hasData
                        ? _formatInvoiceTableDate(armadaStartSource)
                        : blankCell;
                    return pw.TableRow(
                      children: [
                        _pdfCell(
                          hasData ? '${index + 1}' : blankCell,
                          alignCenter: true,
                          hPadding: 4,
                          vPadding: tableRowVPadding,
                          fixedHeight: tableBodyRowHeight,
                          singleLineAutoShrink: true,
                          softLimitChars: 2,
                          minFontSize: 7,
                        ),
                        _pdfCell(
                          tanggal,
                          alignCenter: true,
                          hPadding: 4,
                          vPadding: tableRowVPadding,
                          fixedHeight: tableBodyRowHeight,
                          singleLineAutoShrink: true,
                          softLimitChars: 10,
                        ),
                        _pdfCell(
                          hasData ? resolveNoPolisi(row) : blankCell,
                          alignCenter: true,
                          hPadding: 4,
                          vPadding: tableRowVPadding,
                          fixedHeight: tableBodyRowHeight,
                          singleLineAutoShrink: true,
                          softLimitChars: 12,
                        ),
                        _pdfCell(
                          hasData ? '${row['muatan'] ?? '-'}' : blankCell,
                          alignCenter: true,
                          hPadding: 4,
                          vPadding: tableRowVPadding,
                          fixedHeight: tableBodyRowHeight,
                          singleLineAutoShrink: true,
                          softLimitChars: 14,
                          minFontSize: 6.5,
                        ),
                        _pdfCell(
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
                        _pdfCell(
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
                        _pdfCell(
                          hasData && tonase > 0
                              ? formatTonase(tonase)
                              : blankCell,
                          alignCenter: true,
                          hPadding: 4,
                          vPadding: tableRowVPadding,
                          fixedHeight: tableBodyRowHeight,
                          singleLineAutoShrink: true,
                          softLimitChars: 8,
                        ),
                        _pdfCell(
                          hasData && harga > 0
                              ? formatHargaPerTon(harga)
                              : blankCell,
                          alignRight: true,
                          hPadding: 4,
                          vPadding: tableRowVPadding,
                          fixedHeight: tableBodyRowHeight,
                          singleLineAutoShrink: true,
                          softLimitChars: 10,
                          minFontSize: 6.2,
                        ),
                        _pdfCell(
                          hasData
                              ? formatRupiahNoPrefix(rowSubtotal)
                              : blankCell,
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
                  final usableFlexWidth =
                      max(0.0, tableWidth - fixedWidthTotal);
                  double colWidth(int index) {
                    final fixed = fixedColWidth(index);
                    if (fixed > 0) return fixed;
                    final flex = flexColWeight(index);
                    if (flexWeightTotal <= 0 || flex <= 0) return 0;
                    return usableFlexWidth * (flex / flexWeightTotal);
                  }

                  final leadPrefixWidth = colWidth(0);
                  final leftMergeWidth = colWidth(1) + colWidth(2);
                  final middleGapWidth =
                      colWidth(3) + colWidth(4) + colWidth(5);
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
                  final finalTotalWidth =
                      effectiveTotalWidth + summaryExtraWidth;
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
                          padding:
                              pw.EdgeInsets.only(left: signatureLeftOffset),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.SizedBox(height: signatureTextFontSize + 1),
                              pw.SizedBox(height: compact ? 58 : 84),
                              pw.Padding(
                                padding: pw.EdgeInsets.only(
                                  left: signatureNameOffset +
                                      (compact ? -11 : -16),
                                ),
                                child: pw.Text(
                                  'A N T O K',
                                  style: pw.TextStyle(
                                    font: pw.Font.helveticaBold(),
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
                              offset: const PdfPoint(-1.8, -5),
                              child: pw.Column(
                                crossAxisAlignment:
                                    pw.CrossAxisAlignment.stretch,
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
                                        font: pw.Font.helveticaBoldOblique(),
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
                              offset: const PdfPoint(-2.3, -3),
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
                                    font: pw.Font.helveticaBoldOblique(),
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
                  final logicalTableWidth =
                      fixedWidthTotal + usableFlexWidth <= 0
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
                                  font: pw.Font.helveticaBold(),
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
      final pdfName = 'invoice-${_safePdfFileName(invoiceNumber)}';
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
      final doc = pw.Document(theme: _dashboardPdfTheme(pdfFonts));

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
      final confirmed = await _showPdfPreviewDialog(
        bytes: pdfBytes,
        title: pdfName,
        renderInfo: tableRenderInfo,
      );
      if (!confirmed) return false;
      await _dispatchPdfBytesToPrinter(
        bytes: pdfBytes,
        name: pdfName,
      );
      if (markAsFixed) {
        await _markInvoicesAsFixed(
          fixedInvoiceIds ?? <String>['${item['id'] ?? ''}'],
          batch: fixedBatch,
        );
      }
      if (showSuccessPopup && mounted) {
        _snack(
          _t(
            'Invoice berhasil diproses untuk dicetak.',
            'Invoice has been prepared for printing.',
          ),
        );
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      _snack(
        'Gagal print invoice: ${e.toString().replaceFirst('Exception: ', '')}',
        error: true,
      );
      return false;
    }
  }

  Map<int, pw.TableColumnWidth> _buildIncomeTableColumnWidths(
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
          Formatters.rupiah(_resolveInvoiceDetailSubtotalShared(row));
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

  Map<int, pw.TableColumnWidth> _buildExpenseTableColumnWidths(
    List<Map<String, dynamic>> detailList,
  ) {
    var maxDesc = 14;
    for (final row in detailList) {
      maxDesc =
          max(maxDesc, '${row['nama'] ?? row['name'] ?? ''}'.trim().length);
    }
    final descFlex = (maxDesc / 8).clamp(2.4, 3.5).toDouble();
    return {
      0: const pw.FixedColumnWidth(24), // No
      1: const pw.FlexColumnWidth(0.95), // Tanggal
      2: pw.FlexColumnWidth(descFlex), // Keterangan
      3: const pw.FlexColumnWidth(1.2), // Total
    };
  }

  Future<void> _printExpensePdf(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> detailList,
  ) async {
    try {
      final rows = detailList.isNotEmpty
          ? detailList
          : <Map<String, dynamic>>[
              {
                'nama': '${item['kategori'] ?? item['keterangan'] ?? '-'}',
                'jumlah': _toNum(item['total_pengeluaran']),
              },
            ];

      final usePortrait = rows.length > 14;
      final totalExpense = _toNum(item['total_pengeluaran']);
      final expenseNumber = '${item['no_expense'] ?? '-'}';

      pw.Widget buildExpenseContent({required bool compact}) {
        const infoFont = 9.5;
        const tableBodyRowHeight = 16.0;
        final minRows = compact ? 14 : 36;
        final printableRows = rows.length >= minRows
            ? rows
            : <Map<String, dynamic>>[
                ...rows,
                ...List<Map<String, dynamic>>.generate(
                  minRows - rows.length,
                  (_) => <String, dynamic>{},
                ),
              ];
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Padding(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CV ANT',
                          style: pw.TextStyle(
                            fontSize: compact ? 15 : 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'AS Nusa Trans',
                          style: pw.TextStyle(
                            fontSize: compact ? 10 : 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'EXPENSE',
                        style: pw.TextStyle(
                          fontSize: compact ? 15 : 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        expenseNumber,
                        style: pw.TextStyle(
                          fontSize: compact ? 10 : 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Tanggal: ${Formatters.dmy(item['tanggal'])}',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: infoFont),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Data Expense',
                          style: pw.TextStyle(
                            fontSize: infoFont,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Kategori: ${item['kategori'] ?? '-'}',
                          style: const pw.TextStyle(fontSize: infoFont),
                        ),
                        pw.Text(
                          'Keterangan: ${item['keterangan'] ?? item['note'] ?? '-'}',
                          style: const pw.TextStyle(fontSize: infoFont),
                        ),
                        pw.Text(
                          'Dicatat oleh: ${item['dicatat_oleh'] ?? '-'}',
                          style: const pw.TextStyle(fontSize: infoFont),
                        ),
                        pw.Text(
                          'Status: ${item['status'] ?? '-'}',
                          style: const pw.TextStyle(fontSize: infoFont),
                        ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.SizedBox(width: compact ? 130 : 160),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: _buildExpenseTableColumnWidths(printableRows),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColor(0.12, 0.13, 0.15),
                  ),
                  children: [
                    _pdfCell('NO', bold: true, textColor: PdfColors.white),
                    _pdfCell(
                      'TANGGAL',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.white,
                    ),
                    _pdfCell(
                      'KETERANGAN',
                      bold: true,
                      alignCenter: true,
                      textColor: PdfColors.white,
                    ),
                    _pdfCell(
                      'TOTAL',
                      bold: true,
                      alignRight: true,
                      textColor: PdfColors.white,
                    ),
                  ],
                ),
                ...List<pw.TableRow>.generate(printableRows.length, (index) {
                  final row = printableRows[index];
                  final hasData = index < rows.length;
                  final amount =
                      hasData ? _toNum(row['jumlah'] ?? row['amount']) : 0;
                  final tanggal = hasData
                      ? Formatters.dmy(
                          row['tanggal'] ?? item['tanggal'],
                        )
                      : '';
                  final name =
                      hasData ? '${row['nama'] ?? row['name'] ?? '-'}' : '';
                  return pw.TableRow(
                    children: [
                      _pdfCell(
                        hasData ? '${index + 1}' : '',
                        alignCenter: true,
                        hPadding: 3,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 2,
                        minFontSize: 7,
                      ),
                      _pdfCell(
                        tanggal,
                        alignCenter: true,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 10,
                      ),
                      _pdfCell(
                        name,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 34,
                        minFontSize: 6.5,
                      ),
                      _pdfCell(
                        hasData ? Formatters.rupiah(amount) : '',
                        alignRight: true,
                        fixedHeight: tableBodyRowHeight,
                        singleLineAutoShrink: true,
                        softLimitChars: 14,
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: compact ? 200 : 220,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Pengeluaran',
                      style: pw.TextStyle(
                        fontSize: infoFont,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      Formatters.rupiah(totalExpense),
                      style: pw.TextStyle(
                        fontSize: infoFont,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Hormat kami,'),
                  pw.SizedBox(height: compact ? 72 : 102),
                  pw.Text(
                    'A N T O K',
                    style: pw.TextStyle(
                      font: pw.Font.helveticaBold(),
                      fontSize: 12.0,
                      fontWeight: pw.FontWeight.bold,
                      decoration: pw.TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      await Printing.layoutPdf(
        name: 'expense-$expenseNumber',
        onLayout: (format) async {
          final doc = pw.Document();
          final portraitFormat =
              format.width <= format.height ? format : format.landscape;
          final margin = usePortrait ? 24.0 : 18.0;

          if (usePortrait) {
            doc.addPage(
              pw.MultiPage(
                pageFormat: portraitFormat,
                margin: pw.EdgeInsets.all(margin),
                build: (_) => [
                  buildExpenseContent(compact: false),
                ],
              ),
            );
          } else {
            final usableHeight = portraitFormat.height - (margin * 2);
            final halfHeight = usableHeight / 2;
            doc.addPage(
              pw.Page(
                pageFormat: portraitFormat,
                margin: pw.EdgeInsets.all(margin),
                build: (_) {
                  return pw.Column(
                    children: [
                      pw.Container(
                        height: halfHeight,
                        padding: const pw.EdgeInsets.only(bottom: 8),
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(
                              color: PdfColors.grey400,
                              width: 0.7,
                            ),
                          ),
                        ),
                        child: buildExpenseContent(compact: true),
                      ),
                      pw.SizedBox(height: halfHeight),
                    ],
                  );
                },
              ),
            );
          }
          return doc.save();
        },
      );
    } catch (e) {
      if (!mounted) return;
      _snack(
        'Gagal print expense: ${e.toString().replaceFirst('Exception: ', '')}',
        error: true,
      );
    }
  }

  pw.Widget _pdfCell(
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

  Future<void> _openExpensePreview(Map<String, dynamic> item) async {
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.popupOverlay,
      builder: (context) {
        final detailList = _toDetailList(item['rincian']);
        return AlertDialog(
          title:
              Text('${_t('Preview', 'Preview')} ${item['no_expense'] ?? '-'}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${_t('Kategori', 'Category')}: ${item['kategori'] ?? '-'}'),
                  Text(
                      '${_t('Keterangan', 'Description')}: ${item['keterangan'] ?? item['note'] ?? '-'}'),
                  Text(
                      '${_t('Tanggal', 'Date')}: ${Formatters.dmy(item['tanggal'])}'),
                  Text('${_t('Status', 'Status')}: ${item['status'] ?? '-'}'),
                  Text(
                      '${_t('Dicatat oleh', 'Recorded by')}: ${item['dicatat_oleh'] ?? '-'}'),
                  const SizedBox(height: 8),
                  Text(
                    '${_t('Total', 'Total')}: ${Formatters.rupiah(_toNum(item['total_pengeluaran']))}',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (detailList.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _t('Rincian', 'Details'),
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    ...detailList.map((row) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '- ${row['nama'] ?? row['name'] ?? '-'}: ${Formatters.rupiah(_toNum(row['jumlah'] ?? row['amount']))}',
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () => _printExpensePdf(item, detailList),
              style: CvantButtonStyles.outlined(
                context,
                color: AppColors.blue,
                borderColor: AppColors.blue,
                minimumSize: const Size(96, 40),
              ),
              icon: const Icon(Icons.print_outlined, size: 16),
              label: Text(_t('Print', 'Print')),
            ),
            FilledButton(
              style: CvantButtonStyles.filled(
                context,
                color: AppColors.blue,
                minimumSize: const Size(96, 40),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(_t('Tutup', 'Close')),
            ),
          ],
        );
      },
    );
  }
}
