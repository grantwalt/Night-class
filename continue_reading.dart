import 'package:flutter/material.dart';
import 'package:document_reader_pro/core/di/service_locator.dart';
import 'package:document_reader_pro/data/models/open_target.dart';
import 'package:document_reader_pro/domain/repositories/document_repository.dart';
import 'package:document_reader_pro/presentation/screens/reader_screen.dart';

class ContinueReadingSection extends StatelessWidget {
  const ContinueReadingSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: sl<DocumentRepository>().getRecentDocumentsWithProgress(limit: 10),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return const Center(child: Text('No recently opened documents.\nUse Browse to open a file.'));
        }
        final entries = snap.data!;
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (ctx, i) {
            final doc = entries[i].key;
            final progress = entries[i].value;
            return ListTile(
              leading: Icon(_getIcon(doc.type)),
              title: Text(doc.name),
              subtitle: progress != null
                  ? Text('${progress.percentage.toStringAsFixed(0)}% complete')
                  : const Text('Tap to open'),
              trailing: progress != null && progress.totalPages > 0
                  ? Text('${progress.currentPosition}/${progress.totalPages}')
                  : null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReaderScreen(
                    target: OpenTarget.fromDocument(doc),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'docx': return Icons.description;
      case 'pptx': return Icons.slideshow;
      case 'epub': return Icons.menu_book;
      default: return Icons.insert_drive_file;
    }
  }
}
