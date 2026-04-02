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

extension _AdminInvoiceListViewPrinting on _AdminInvoiceListViewState {
  String _safePdfFileName(String value) {
    final safe = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'invoice' : safe;
  }

  bool get _canRenderInvoiceTableWithExcel => !kIsWeb && Platform.isWindows;
  bool get _canRenderInvoiceTableViaService =>
      !kIsWeb && AppConfig.hasInvoiceRenderService;

  Uri? _invoiceRenderServiceUri() {
    if (!_canRenderInvoiceTableViaService) return null;
    final base = AppConfig.invoiceRenderServiceUrl.trim();
    if (base.isEmpty) return null;
    final normalized =
        base.endsWith('/') ? '${base}render-table' : '$base/render-table';
    return Uri.tryParse(normalized);
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
          'rows': rows,
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
        debugPrint(
          'Excel table render failed: ${result.stderr}\n${result.stdout}',
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
      debugPrint('Excel table render error: $error\n$stackTrace');
      return null;
    }
  }

  Future<Uint8List?> _renderInvoiceTableImageViaService({
    required List<Map<String, String>> rows,
    required int rowCount,
    String renderMode = 'table',
    Map<String, String>? summaryValues,
  }) async {
    final uri = _invoiceRenderServiceUri();
    if (uri == null) return null;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/pdf');
      request.write(
        jsonEncode({
          'rowCount': rowCount,
          'rows': rows,
          'renderMode': renderMode,
          if (summaryValues != null) 'summaryValues': summaryValues,
        }),
      );

      final response = await request.close().timeout(
            const Duration(seconds: 25),
          );
      final bytesBuilder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        bytesBuilder.add(chunk);
      }
      final responseBytes = bytesBuilder.takeBytes();

      if (response.statusCode != HttpStatus.ok) {
        final errorText = utf8.decode(responseBytes, allowMalformed: true);
        debugPrint(
          'Remote invoice table render failed '
          '(${response.statusCode}): $errorText',
        );
        return null;
      }

      return _rasterizeInvoiceTablePdfBytes(
        responseBytes,
        renderMode: renderMode,
      );
    } catch (error, stackTrace) {
      debugPrint('Remote invoice table render error: $error\n$stackTrace');
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
    try {
      const tableWidth = 632.0;
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
        return _pdfCell(
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
                  final row = index < rows.length
                      ? rows[index]
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
      debugPrint('Portable table render error: $error\n$stackTrace');
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
                            child: Text(_t('Tutup', 'Close')),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: () => Navigator.pop(context, true),
                            style: CvantButtonStyles.filled(
                              context,
                              color: AppColors.success,
                            ),
                            icon: const Icon(Icons.print_outlined),
                            label: Text(_t('Cetak', 'Print')),
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
