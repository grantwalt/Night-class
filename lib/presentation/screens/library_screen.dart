import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:document_reader_pro/data/models/open_target.dart';
import 'package:document_reader_pro/presentation/providers/library_provider.dart';
import 'package:document_reader_pro/presentation/screens/reader_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LibraryProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: _DocumentSearchDelegate(provider),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: provider.setFilterType,
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'all', child: Text('All')),
              PopupMenuItem(value: 'pdf', child: Text('PDF')),
              PopupMenuItem(value: 'docx', child: Text('DOCX')),
              PopupMenuItem(value: 'pptx', child: Text('PPTX')),
              PopupMenuItem(value: 'epub', child: Text('EPUB')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Import file into library',
            onPressed: provider.pickAndAddFile,
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.documents.isEmpty
              ? const Center(child: Text('No documents. Tap + to add, or use Browse.'))
              : ListView.builder(
                  itemCount: provider.documents.length,
                  itemBuilder: (ctx, i) {
                    final doc = provider.documents[i];
                    final progress = provider.progressFor(doc.id);
                    return ListTile(
                      leading: Icon(_getIcon(doc.type)),
                      title: Text(doc.name),
                      subtitle: Text(
                        progress != null
                            ? '${progress.percentage.toStringAsFixed(0)}%'
                            : 'Not opened',
                      ),
                      trailing: IconButton(
                        icon: Icon(
                            doc.isFavorite ? Icons.star : Icons.star_border),
                        onPressed: () => provider.toggleFavorite(doc.id),
                      ),
                      onTap: () async {
                        await provider.updateLastOpened(doc.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReaderScreen(
                              target: OpenTarget.fromDocument(doc),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
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

class _DocumentSearchDelegate extends SearchDelegate {
  final LibraryProvider provider;
  _DocumentSearchDelegate(this.provider);

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) {
    provider.setSearchQuery(query);
    return const LibraryScreen();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = provider.documents
        .where((d) => d.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (ctx, i) => ListTile(
        title: Text(results[i].name),
        onTap: () {
          close(context, null);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReaderScreen(
                target: OpenTarget.fromDocument(results[i]),
              ),
            ),
          );
        },
      ),
    );
  }
}
