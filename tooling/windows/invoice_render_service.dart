import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _defaultHost = '0.0.0.0';
const _defaultPort = 8787;

Future<void> main(List<String> args) async {
  final config = _parseArgs(args);
  final scriptDir = File.fromUri(Platform.script).parent;
  final renderScriptPath =
      '${scriptDir.path}${Platform.pathSeparator}render_invoice_table.ps1';
  final templatePath =
      '${scriptDir.parent.parent.path}${Platform.pathSeparator}assets'
      '${Platform.pathSeparator}templates${Platform.pathSeparator}'
      'invoice_table_template.xlsx';

  final renderScript = File(renderScriptPath);
  final templateFile = File(templatePath);
  if (!await renderScript.exists()) {
    stderr.writeln('Render script not found: $renderScriptPath');
    exitCode = 64;
    return;
  }
  if (!await templateFile.exists()) {
    stderr.writeln('Template file not found: $templatePath');
    exitCode = 64;
    return;
  }

  final server = await HttpServer.bind(config.host, config.port);
  stdout.writeln(
    'Invoice render service listening on '
    'http://${config.host}:${config.port}',
  );
  stdout.writeln('POST /render-table -> Excel table PDF');
  stdout.writeln('GET  /health       -> service health');

  await for (final request in server) {
    unawaited(
      _handleRequest(
        request,
        renderScriptPath: renderScript.path,
        templatePath: templateFile.path,
      ),
    );
  }
}

Future<void> _handleRequest(
  HttpRequest request, {
  required String renderScriptPath,
  required String templatePath,
}) async {
  request.response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
  request.response.headers.set(
    HttpHeaders.accessControlAllowHeadersHeader,
    'Content-Type, Accept',
  );
  request.response.headers.set(
    HttpHeaders.accessControlAllowMethodsHeader,
    'GET, POST, OPTIONS',
  );

  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }

  try {
    if (request.method == 'GET' && request.uri.path == '/health') {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'ok': true,
          'service': 'invoice-render-service',
          'time': DateTime.now().toIso8601String(),
        }),
      );
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && request.uri.path == '/render-table') {
      final payloadText = await utf8.decoder.bind(request).join();
      final payload = jsonDecode(payloadText) as Map<String, dynamic>;
      final pdfBytes = await _renderTablePdf(
        payload,
        renderScriptPath: renderScriptPath,
        templatePath: templatePath,
      );
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType('application', 'pdf');
      request.response.add(pdfBytes);
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'error': 'not_found',
        'message': 'Unknown route ${request.method} ${request.uri.path}',
      }),
    );
    await request.response.close();
  } catch (error, stackTrace) {
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      }),
    );
    await request.response.close();
  }
}

Future<List<int>> _renderTablePdf(
  Map<String, dynamic> payload, {
  required String renderScriptPath,
  required String templatePath,
}) async {
  final tempDir = await Directory.systemTemp.createTemp(
    'cvant_invoice_render_service_',
  );
  try {
    final payloadPath =
        '${tempDir.path}${Platform.pathSeparator}invoice_table_payload.json';
    final outputPath =
        '${tempDir.path}${Platform.pathSeparator}invoice_table.pdf';
    await File(payloadPath).writeAsString(jsonEncode(payload), flush: true);

    final result = await Process.run(
      'powershell',
      <String>[
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        renderScriptPath,
        '-TemplatePath',
        templatePath,
        '-PayloadPath',
        payloadPath,
        '-OutputPath',
        outputPath,
        '-RenderMode',
        (payload['renderMode'] ?? 'table').toString(),
      ],
    );

    if (result.exitCode != 0) {
      throw ProcessException(
        'powershell',
        const [],
        'Excel render failed: ${result.stderr}\n${result.stdout}',
        result.exitCode,
      );
    }

    final outputFile = File(outputPath);
    if (!await outputFile.exists()) {
      throw StateError('Excel render finished without output PDF.');
    }
    return outputFile.readAsBytes();
  } finally {
    unawaited(tempDir.delete(recursive: true));
  }
}

_ServiceConfig _parseArgs(List<String> args) {
  var host = _defaultHost;
  var port = _defaultPort;

  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    if (arg == '--host' && index + 1 < args.length) {
      host = args[++index];
    } else if (arg == '--port' && index + 1 < args.length) {
      final parsedPort = int.tryParse(args[++index]);
      if (parsedPort != null) {
        port = parsedPort;
      }
    }
  }

  return _ServiceConfig(host: host, port: port);
}

class _ServiceConfig {
  const _ServiceConfig({
    required this.host,
    required this.port,
  });

  final String host;
  final int port;
}
