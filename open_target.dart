import 'package:document_reader_pro/data/models/document.dart';

/// Represents a file that can be opened by [ReaderScreen].
///
/// Either a fully catalogued [Document] from the library ([fromDocument]),
/// or a raw file reference ([fromUri]) that has not been imported yet.
///
/// Using a sealed-style class keeps the renderer layer unaware of whether
/// the file came from the library or was opened ad-hoc.
class OpenTarget {
  /// A library document (has a DB record, progress is saved normally).
  final Document? document;

  /// Content URI (content://...) or POSIX path for an ad-hoc file.
  final String? rawUri;

  /// Display name derived from the URI when no [Document] is available.
  final String? rawName;

  /// File type / extension (e.g. 'pdf', 'docx').
  final String type;

  const OpenTarget._({
    this.document,
    this.rawUri,
    this.rawName,
    required this.type,
  });

  factory OpenTarget.fromDocument(Document doc) => OpenTarget._(
        document: doc,
        type: doc.type,
      );

  factory OpenTarget.fromUri({
    required String uri,
    required String name,
    required String type,
  }) =>
      OpenTarget._(
        rawUri: uri,
        rawName: name,
        type: type,
      );

  /// Stable identifier used as a progress key.
  /// For library docs this is the DB id; for ad-hoc files it's the URI.
  String get id => document?.id ?? rawUri ?? rawName ?? 'unknown';

  /// Human-readable title for the app bar.
  String get name => document?.name ?? rawName ?? 'Document';

  /// Resolved path/URI for reading bytes.
  String get path => document?.path ?? rawUri ?? '';

  bool get isLibraryDocument => document != null;
}
