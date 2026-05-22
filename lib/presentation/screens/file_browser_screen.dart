import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:document_reader_pro/core/storage/saf_manager.dart';
import 'package:document_reader_pro/data/models/open_target.dart';
import 'package:document_reader_pro/presentation/screens/reader_screen.dart';

/// Lets the user browse SAF-granted folders or pick a file directly,
/// and opens it immediately without an import step.
class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({Key? key}) : super(key: key);

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  // Current folder URI being browsed (null = root / granted URIs list).
  String? _currentUri;
  String _currentTitle = 'Browse Files';

  List<_BrowserEntry> _entries = [];
  bool _loading = false;
  String? _error;

  // Breadcrumb stack: list of (uri, title) pairs.
  final List<_Crumb> _breadcrumbs = [];

  @override
  void initState() {
    super.initState();
    _loadRoot();
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _loadRoot() async {
    setState(() { _loading = true; _error = null; });
    final uris = await SafManager.getSavedUris();
    final entries = uris
        .map((uri) => _BrowserEntry.folder(uri: uri, name: _labelForUri(uri)))
        .toList();
    setState(() {
      _entries = entries;
      _currentUri = null;
      _currentTitle = 'Browse Files';
      _loading = false;
    });
  }

  Future<void> _openFolder(String uri, String name) async {
    setState(() { _loading = true; _error = null; });
    try {
      final files = await SafManager.listFilesInUri(uri, maxDepth: 0);
      final dirs = await SafManager.listDirectoriesInUri(uri);

      final entries = [
        ...dirs.map((d) => _BrowserEntry.folder(uri: d.uri, name: d.name)),
        ...files.map((f) => _BrowserEntry.file(
              uri: f.uri,
              name: f.name,
              type: f.extension,
              sizeBytes: f.sizeBytes,
            )),
      ]..sort((a, b) {
          // Folders first, then files alphabetically.
          if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

      setState(() {
        _breadcrumbs.add(_Crumb(uri: _currentUri, title: _currentTitle));
        _currentUri = uri;
        _currentTitle = name;
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _navigateBack() {
    if (_breadcrumbs.isEmpty) return;
    final crumb = _breadcrumbs.removeLast();
    if (crumb.uri == null) {
      _loadRoot();
    } else {
      setState(() {
        _currentUri = crumb.uri;
        _currentTitle = crumb.title;
      });
      _openFolder(crumb.uri!, crumb.title);
    }
  }

  // ── Opening files ────────────────────────────────────────────────────────

  void _openFile(_BrowserEntry entry) {
    final target = OpenTarget.fromUri(
      uri: entry.uri,
      name: entry.name,
      type: entry.type ?? '',
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderScreen(target: target)),
    );
  }

  /// Direct file pick via system picker — no folder browsing needed.
  Future<void> _pickFileDirect() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'pptx', 'epub'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final picked = result.files.single;
    final ext = (picked.extension ?? '').toLowerCase();
    final target = OpenTarget.fromUri(
      uri: picked.path!,
      name: picked.name,
      type: ext,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderScreen(target: target)),
    );
  }

  /// Add a new SAF folder grant.
  Future<void> _addFolder() async {
    final uri = await SafManager.pickFolder();
    if (uri != null) _loadRoot();
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_breadcrumbs.isNotEmpty) {
          _navigateBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentTitle),
          leading: _breadcrumbs.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _navigateBack,
                )
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.insert_drive_file),
              tooltip: 'Open file directly',
              onPressed: _pickFileDirect,
            ),
            IconButton(
              icon: const Icon(Icons.create_new_folder),
              tooltip: 'Add folder',
              onPressed: _addFolder,
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _currentUri == null
                  ? _loadRoot
                  : () => _openFolder(_currentUri!, _currentTitle),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_entries.isEmpty && _currentUri == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No folders added yet.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.create_new_folder),
              label: const Text('Add Folder'),
              onPressed: _addFolder,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.insert_drive_file),
              label: const Text('Open File Directly'),
              onPressed: _pickFileDirect,
            ),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return const Center(child: Text('No supported files in this folder.'));
    }

    return ListView.builder(
      itemCount: _entries.length,
      itemBuilder: (ctx, i) {
        final entry = _entries[i];
        return ListTile(
          leading: Icon(entry.isFolder ? Icons.folder : _iconForType(entry.type)),
          title: Text(entry.name),
          subtitle: entry.isFolder
              ? null
              : Text(_formatSize(entry.sizeBytes ?? 0)),
          trailing: entry.isFolder
              ? const Icon(Icons.chevron_right)
              : null,
          onTap: () {
            if (entry.isFolder) {
              _openFolder(entry.uri, entry.name);
            } else {
              _openFile(entry);
            }
          },
        );
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  IconData _iconForType(String? type) {
    switch (type) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'docx': return Icons.description;
      case 'pptx': return Icons.slideshow;
      case 'epub': return Icons.menu_book;
      default: return Icons.insert_drive_file;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _labelForUri(String uri) {
    // Extract a readable name from the URI if possible.
    final decoded = Uri.decodeComponent(uri);
    final parts = decoded.split(':');
    return parts.length > 1 ? parts.last.split('/').last : uri;
  }
}

// ── Internal models ───────────────────────────────────────────────────────

class _BrowserEntry {
  final String uri;
  final String name;
  final bool isFolder;
  final String? type;
  final int? sizeBytes;

  const _BrowserEntry._({
    required this.uri,
    required this.name,
    required this.isFolder,
    this.type,
    this.sizeBytes,
  });

  factory _BrowserEntry.folder({required String uri, required String name}) =>
      _BrowserEntry._(uri: uri, name: name, isFolder: true);

  factory _BrowserEntry.file({
    required String uri,
    required String name,
    required String type,
    int? sizeBytes,
  }) =>
      _BrowserEntry._(
          uri: uri, name: name, isFolder: false, type: type, sizeBytes: sizeBytes);
}

class _Crumb {
  final String? uri;
  final String title;
  const _Crumb({required this.uri, required this.title});
}
