import 'package:flutter_document_file/flutter_document_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SAF file access layer.
///
/// CRITICAL: Never convert a SAF DocumentFile to a dart:io [File] via
/// toFile().  On Android 10+ (scoped storage) the resulting path is not
/// accessible via the POSIX filesystem.  Instead, every consumer of SAF
/// files works with content URIs and raw [Uint8List] bytes.
class SafManager {
  static const String _prefKey = 'saf_uris';
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<List<String>> getSavedUris() async {
    return _prefs.getStringList(_prefKey) ?? [];
  }

  static Future<void> saveUri(String uri) async {
    final list = await getSavedUris();
    if (!list.contains(uri)) {
      list.add(uri);
      await _prefs.setStringList(_prefKey, list);
    }
  }

  static Future<void> removeUri(String uri) async {
    final list = await getSavedUris();
    list.remove(uri);
    await _prefs.setStringList(_prefKey, list);
  }

  /// Shows the system folder picker and persists the granted URI.
  /// Returns the URI string, or null if the user cancelled.
  static Future<String?> pickFolder() async {
    final result = await FlutterDocumentFile.pickDirectory();
    if (result != null) {
      await saveUri(result);
      return result;
    }
    return null;
  }

  /// Recursively lists supported document files under [uri].
  /// Set [maxDepth] = 0 for a shallow (single-level) listing.
  /// Returns [SafFileInfo] records — never dart:io [File] objects.
  static Future<List<SafFileInfo>> listFilesInUri(
    String uri, {
    int depth = 0,
    int maxDepth = 3,
  }) async {
    if (depth > maxDepth) return [];
    DocumentFile dir;
    try {
      dir = await FlutterDocumentFile.fromUri(uri);
    } catch (e) {
      return [];
    }

    final children = await dir.list();
    final files = <SafFileInfo>[];

    for (final child in children) {
      final isFile = await child.isFile();
      if (isFile) {
        final name = await child.getName();
        if (_isSupported(name)) {
          final size = await child.length();
          final lastModified = await child.lastModified();
          files.add(SafFileInfo(
            uri: child.uri.toString(),
            name: name,
            sizeBytes: size ?? 0,
            lastModified: lastModified != null
                ? DateTime.fromMillisecondsSinceEpoch(lastModified)
                : DateTime.now(),
          ));
        }
      } else if (await child.isDirectory()) {
        if (maxDepth > 0) {
          files.addAll(await listFilesInUri(
            child.uri.toString(),
            depth: depth + 1,
            maxDepth: maxDepth,
          ));
        }
      }
    }
    return files;
  }

  /// Lists immediate subdirectories of [uri] (one level only).
  /// Used by [FileBrowserScreen] for folder navigation.
  static Future<List<SafDirInfo>> listDirectoriesInUri(String uri) async {
    DocumentFile dir;
    try {
      dir = await FlutterDocumentFile.fromUri(uri);
    } catch (e) {
      return [];
    }

    final children = await dir.list();
    final dirs = <SafDirInfo>[];
    for (final child in children) {
      if (await child.isDirectory()) {
        final name = await child.getName();
        dirs.add(SafDirInfo(uri: child.uri.toString(), name: name));
      }
    }
    return dirs;
  }

  /// Reads the bytes of a SAF file identified by [uri].
  /// Returns null if the read fails (e.g. permission revoked).
  static Future<Uint8List?> readBytes(String uri) async {
    try {
      final file = await FlutterDocumentFile.fromUri(uri);
      return await file.readAsBytes();
    } catch (e) {
      return null;
    }
  }

  static bool _isSupported(String name) {
    final lower = name.toLowerCase();
    final ext = lower.contains('.') ? lower.split('.').last : '';
    return ['pdf', 'docx', 'pptx', 'epub'].contains(ext);
  }
}

/// Metadata about a SAF-sourced file.
class SafFileInfo {
  final String uri;
  final String name;
  final int sizeBytes;
  final DateTime lastModified;

  const SafFileInfo({
    required this.uri,
    required this.name,
    required this.sizeBytes,
    required this.lastModified,
  });

  String get extension {
    final lower = name.toLowerCase();
    return lower.contains('.') ? lower.split('.').last : '';
  }
}

/// Metadata about a SAF-sourced directory.
class SafDirInfo {
  final String uri;
  final String name;
  const SafDirInfo({required this.uri, required this.name});
}

export 'dart:typed_data' show Uint8List;
