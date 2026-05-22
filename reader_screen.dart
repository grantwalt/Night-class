import 'package:flutter/material.dart';
import 'package:document_reader_pro/core/di/service_locator.dart';
import 'package:document_reader_pro/data/models/document.dart';
import 'package:document_reader_pro/data/models/open_target.dart';
import 'package:document_reader_pro/domain/engines/renderer_registry.dart';
import 'package:document_reader_pro/domain/models/render_controller.dart';
import 'package:document_reader_pro/domain/repositories/document_repository.dart';
import 'package:document_reader_pro/domain/services/progress_manager.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Opens any supported document — whether it's a library [Document] or a
/// raw file URI that has never been imported.
///
/// For ad-hoc files a lightweight DB record is created lazily in the
/// background so that reading progress is saved and the document appears
/// in Recents.  The user never sees an "import" step.
class ReaderScreen extends StatefulWidget {
  final OpenTarget target;

  const ReaderScreen({Key? key, required this.target}) : super(key: key);

  /// Convenience constructor for library documents (backwards compatible).
  factory ReaderScreen.fromDocument(Document document) =>
      ReaderScreen(target: OpenTarget.fromDocument(document));

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final RenderController _renderController;
  late OpenTarget _target;

  @override
  void initState() {
    super.initState();
    _target = widget.target;

    _renderController = RenderController(
      onProgressUpdate: (p) async {
        // Ensure the document has a DB record before saving progress.
        final resolvedTarget = await _ensureLibraryRecord(_target);
        if (resolvedTarget != _target) {
          // Update our local reference so future saves use the real ID.
          if (mounted) setState(() => _target = resolvedTarget);
        }
        await sl<ProgressManager>().saveProgress(p.copyWith(
          id: resolvedTarget.id,
          documentId: resolvedTarget.id,
        ));
      },
      onSearch: (_) {},
    );

    // Lazily register ad-hoc files in the background so they show in
    // Recents and have progress saved, without blocking the UI.
    if (!_target.isLibraryDocument) {
      _ensureLibraryRecord(_target);
    }
  }

  /// If [target] is already a library document, returns it unchanged.
  /// Otherwise inserts a minimal DB record and returns an updated target
  /// backed by that record.  Safe to call multiple times (INSERT OR IGNORE).
  Future<OpenTarget> _ensureLibraryRecord(OpenTarget target) async {
    if (target.isLibraryDocument) return target;

    final repo = sl<DocumentRepository>();

    // Check if it was already registered by a previous open.
    final existing = await repo.getDocumentByPath(target.path);
    if (existing != null) {
      return OpenTarget.fromDocument(existing);
    }

    final ext = target.type.toLowerCase();
    final doc = Document(
      id: _uuid.v4(),
      name: target.name,
      path: target.path,
      extension: ext,
      type: ext,
      sizeBytes: 0, // unknown at this point
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      lastOpenedAt: DateTime.now(),
      mimeType: _mimeForExtension(ext),
    );

    await repo.addDocument(doc);
    return OpenTarget.fromDocument(doc);
  }

  @override
  Widget build(BuildContext context) {
    final renderer = sl<RendererRegistry>().getRenderer(_target.type);

    if (renderer == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_target.name)),
        body: Center(
          child: Text('Unsupported format: ${_target.type}'),
        ),
      );
    }

    // Build a transient Document for the renderer if we have a raw target.
    // The renderer only needs path, name, type, and id for progress.
    final doc = _target.document ??
        Document(
          id: _target.id,
          name: _target.name,
          path: _target.path,
          extension: _target.type,
          type: _target.type,
          sizeBytes: 0,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          mimeType: _mimeForExtension(_target.type),
        );

    return renderer.build(context, doc, _renderController);
  }

  static String _mimeForExtension(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'epub':
        return 'application/epub+zip';
      default:
        return 'application/octet-stream';
    }
  }
}
