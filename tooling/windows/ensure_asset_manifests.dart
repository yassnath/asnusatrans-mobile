import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const _valueNull = 0;
const _valueTrue = 1;
const _valueFalse = 2;
const _valueInt32 = 3;
const _valueInt64 = 4;
const _valueString = 7;
const _valueList = 12;
const _valueMap = 13;

const _excludedManifestFiles = <String>{
  'AssetManifest.bin',
  'AssetManifest.bin.json',
  'FontManifest.json',
  'NativeAssetsManifest.json',
  'NOTICES',
  'NOTICES.Z',
  'kernel_blob.bin',
  'vm_snapshot_data',
  'isolate_snapshot_data',
};

void main(List<String> args) {
  if (args.length < 3) {
    stderr.writeln(
      'Usage: dart ensure_asset_manifests.dart <flutter_assets_dir> <project_dir> <flutter_root>',
    );
    exitCode = 64;
    return;
  }

  final assetDir = Directory(args.first);
  final projectDir = Directory(args[1]);
  final flutterRoot = Directory(args[2]);
  if (!assetDir.existsSync()) {
    stderr.writeln('flutter_assets directory not found: ${assetDir.path}');
    exitCode = 1;
    return;
  }
  if (!projectDir.existsSync()) {
    stderr.writeln('project directory not found: ${projectDir.path}');
    exitCode = 1;
    return;
  }
  if (!flutterRoot.existsSync()) {
    stderr.writeln('flutter root not found: ${flutterRoot.path}');
    exitCode = 1;
    return;
  }

  _copyDeclaredAssets(
    assetDir: assetDir,
    projectDir: projectDir,
    flutterRoot: flutterRoot,
  );

  final assetKeys = _collectAssetKeys(assetDir);
  final assetManifest = <String, List<Map<String, Object?>>>{
    for (final key in assetKeys)
      key: <Map<String, Object?>>[
        <String, Object?>{
          'asset': key,
          'dpr': _extractDevicePixelRatio(key),
        }..removeWhere((entryKey, entryValue) => entryValue == null),
      ],
  };

  final assetManifestFile = File('${assetDir.path}${Platform.pathSeparator}AssetManifest.bin');
  assetManifestFile.writeAsBytesSync(
    _StandardMessageCodecEncoder().encode(assetManifest),
    flush: true,
  );

  final fontManifestFile = File('${assetDir.path}${Platform.pathSeparator}FontManifest.json');
  fontManifestFile.writeAsStringSync(
    jsonEncode(_buildFontManifest(assetKeys)),
    flush: true,
  );
}

void _copyDeclaredAssets({
  required Directory assetDir,
  required Directory projectDir,
  required Directory flutterRoot,
}) {
  final pubspecFile = File(p.join(projectDir.path, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) return;

  final pubspec = loadYaml(pubspecFile.readAsStringSync());
  if (pubspec is! YamlMap) return;

  final flutterSection = pubspec['flutter'];
  if (flutterSection is! YamlMap) return;

  final rawAssets = flutterSection['assets'];
  if (rawAssets is YamlList) {
    for (final rawAsset in rawAssets) {
      final relativePath = '${rawAsset ?? ''}'.trim();
      if (relativePath.isEmpty) continue;
      final sourcePath = p.join(projectDir.path, relativePath);
      final type = FileSystemEntity.typeSync(sourcePath);
      if (type == FileSystemEntityType.file) {
        _copyFile(sourcePath, p.join(assetDir.path, relativePath));
      } else if (type == FileSystemEntityType.directory) {
        _copyDirectory(sourcePath, p.join(assetDir.path, relativePath));
      }
    }
  }

  final usesMaterialDesign = flutterSection['uses-material-design'] == true;
  if (usesMaterialDesign) {
    final materialIconsPath = p.join(
      flutterRoot.path,
      'bin',
      'cache',
      'artifacts',
      'material_fonts',
      'materialicons-regular.otf',
    );
    if (File(materialIconsPath).existsSync()) {
      _copyFile(
        materialIconsPath,
        p.join(assetDir.path, 'fonts', 'MaterialIcons-Regular.otf'),
      );
    }
  }

  final packageConfigFile = File(p.join(projectDir.path, '.dart_tool', 'package_config.json'));
  if (!packageConfigFile.existsSync()) return;
  final packageConfig = jsonDecode(packageConfigFile.readAsStringSync());
  if (packageConfig is! Map<String, dynamic>) return;
  final packages = packageConfig['packages'];
  if (packages is! List) return;

  for (final rawPackage in packages) {
    if (rawPackage is! Map) continue;
    if ('${rawPackage['name']}' != 'cupertino_icons') continue;
    final rootUri = '${rawPackage['rootUri'] ?? ''}';
    if (rootUri.isEmpty) break;
    final packageRoot = _resolvePackageRoot(
      projectDir: projectDir,
      rootUri: rootUri,
    );
    if (packageRoot == null) break;
    final cupertinoFontSource = p.join(
      packageRoot.path,
      'assets',
      'CupertinoIcons.ttf',
    );
    if (File(cupertinoFontSource).existsSync()) {
      _copyFile(
        cupertinoFontSource,
        p.join(
          assetDir.path,
          'packages',
          'cupertino_icons',
          'assets',
          'CupertinoIcons.ttf',
        ),
      );
    }
    break;
  }
}

Directory? _resolvePackageRoot({
  required Directory projectDir,
  required String rootUri,
}) {
  if (rootUri.startsWith('file:///')) {
    return Directory(Uri.parse(rootUri).toFilePath());
  }
  final resolved = Uri.directory(projectDir.path).resolve(rootUri).toFilePath();
  return Directory(resolved);
}

void _copyFile(String sourcePath, String destinationPath) {
  final source = File(sourcePath);
  if (!source.existsSync()) return;
  final destination = File(destinationPath);
  destination.parent.createSync(recursive: true);
  source.copySync(destination.path);
}

void _copyDirectory(String sourcePath, String destinationPath) {
  final sourceDir = Directory(sourcePath);
  if (!sourceDir.existsSync()) return;
  for (final entity in sourceDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final relativePath = p.relative(entity.path, from: sourceDir.path);
    _copyFile(entity.path, p.join(destinationPath, relativePath));
  }
}

List<String> _collectAssetKeys(Directory assetDir) {
  final files = assetDir
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => _relativeAssetPath(assetDir, file))
      .where((path) => path.isNotEmpty)
      .where((path) => !_excludedManifestFiles.contains(path.split('/').last))
      .toList()
    ..sort();
  return files;
}

String _relativeAssetPath(Directory assetDir, File file) {
  final root = assetDir.absolute.path.replaceAll('\\', '/');
  final full = file.absolute.path.replaceAll('\\', '/');
  if (!full.toLowerCase().startsWith(root.toLowerCase())) return '';
  final relative = full.substring(root.length);
  return relative.startsWith('/') ? relative.substring(1) : relative;
}

List<Map<String, Object>> _buildFontManifest(List<String> assetKeys) {
  final manifests = <Map<String, Object>>[];
  final seenFamilies = <String>{};

  void addFamily(String family, String asset) {
    if (!assetKeys.contains(asset) || !seenFamilies.add(family)) return;
    manifests.add({
      'family': family,
      'fonts': [
        {'asset': asset},
      ],
    });
  }

  addFamily('MaterialIcons', 'fonts/MaterialIcons-Regular.otf');
  addFamily('CupertinoIcons', 'packages/cupertino_icons/assets/CupertinoIcons.ttf');

  final fontFiles = assetKeys
      .where((path) => path.endsWith('.ttf') || path.endsWith('.otf'))
      .toList();
  for (final asset in fontFiles) {
    if (asset == 'fonts/MaterialIcons-Regular.otf' ||
        asset == 'packages/cupertino_icons/assets/CupertinoIcons.ttf') {
      continue;
    }
    final family = _deriveFontFamily(asset);
    if (!seenFamilies.add(family)) continue;
    manifests.add({
      'family': family,
      'fonts': [
        {'asset': asset},
      ],
    });
  }

  return manifests;
}

String _deriveFontFamily(String assetPath) {
  final fileName = assetPath.split('/').last;
  final dotIndex = fileName.lastIndexOf('.');
  final baseName = dotIndex == -1 ? fileName : fileName.substring(0, dotIndex);
  return baseName
      .replaceAll('-Regular', '')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .trim();
}

double? _extractDevicePixelRatio(String assetPath) {
  final segments = assetPath.split('/');
  if (segments.length < 2) return null;
  final parent = segments[segments.length - 2];
  final match = RegExp(r'^(\d+(?:\.\d+)?)x$').firstMatch(parent);
  if (match == null) return null;
  return double.tryParse(match.group(1) ?? '');
}

class _StandardMessageCodecEncoder {
  Uint8List encode(Object? value) {
    final builder = BytesBuilder(copy: false);
    _writeValue(builder, value);
    return builder.toBytes();
  }

  void _writeValue(BytesBuilder builder, Object? value) {
    if (value == null) {
      builder.addByte(_valueNull);
      return;
    }
    if (value is bool) {
      builder.addByte(value ? _valueTrue : _valueFalse);
      return;
    }
    if (value is int) {
      if (value >= -0x80000000 && value <= 0x7fffffff) {
        builder.addByte(_valueInt32);
        builder.add(_int32(value));
      } else {
        builder.addByte(_valueInt64);
        builder.add(_int64(value));
      }
      return;
    }
    if (value is String) {
      final bytes = utf8.encode(value);
      builder.addByte(_valueString);
      _writeSize(builder, bytes.length);
      builder.add(bytes);
      return;
    }
    if (value is List) {
      builder.addByte(_valueList);
      _writeSize(builder, value.length);
      for (final item in value) {
        _writeValue(builder, item);
      }
      return;
    }
    if (value is Map) {
      builder.addByte(_valueMap);
      _writeSize(builder, value.length);
      for (final entry in value.entries) {
        _writeValue(builder, entry.key);
        _writeValue(builder, entry.value);
      }
      return;
    }
    throw UnsupportedError('Unsupported StandardMessageCodec value: $value');
  }

  void _writeSize(BytesBuilder builder, int value) {
    if (value < 254) {
      builder.addByte(value);
      return;
    }
    if (value <= 0xffff) {
      builder.addByte(254);
      builder.add(_uint16(value));
      return;
    }
    builder.addByte(255);
    builder.add(_uint32(value));
  }

  Uint8List _uint16(int value) {
    final data = ByteData(2)..setUint16(0, value, Endian.host);
    return data.buffer.asUint8List();
  }

  Uint8List _uint32(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.host);
    return data.buffer.asUint8List();
  }

  Uint8List _int32(int value) {
    final data = ByteData(4)..setInt32(0, value, Endian.host);
    return data.buffer.asUint8List();
  }

  Uint8List _int64(int value) {
    final data = ByteData(8)..setInt64(0, value, Endian.host);
    return data.buffer.asUint8List();
  }
}
