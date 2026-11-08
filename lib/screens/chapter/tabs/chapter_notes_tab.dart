import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_app/database/hive_service.dart';
import 'package:study_app/providers/note_provider.dart';
import 'package:study_app/providers/chapter_provider.dart';
import 'package:study_app/widgets/custom_card.dart';
import 'package:study_app/screens/chapter/note_editor_screen.dart';
import 'package:study_app/services/pdf_import_service.dart';
import 'package:study_app/models/block.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class ChapterNotesTab extends StatelessWidget {
  final String chapterId;

  const ChapterNotesTab({super.key, required this.chapterId});

  @override
  Widget build(BuildContext context) {
    final chapter = context
        .watch<ChapterProvider>()
        .chapters
        .where((c) => c.id == chapterId)
        .firstOrNull;

    final canImportFromClassroom = chapter?.classroomCourseId != null &&
        chapter?.classroomCourseWorkId != null &&
        chapter?.sourceType != 'announcement';

    return Scaffold(
      body: Consumer<NoteProvider>(
        builder: (context, noteProvider, child) {
          final notes = noteProvider.getNotesForChapter(chapterId);

          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("No notes yet. Create one!"),
                  if (canImportFromClassroom) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _importFromClassroom(context, chapter!),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Import from Classroom PDF'),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CustomCard(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(noteId: note.id),
                      ),
                    );
                  },
                  onLongPress: () => _showDeleteNoteDialog(context, note),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Edited ${DateFormat('MMM d, h:mm a').format(note.lastEdited)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (canImportFromClassroom) ...[
            FloatingActionButton.small(
              heroTag: 'import-pdf-fab',
              onPressed: () => _importFromClassroom(context, chapter!),
              tooltip: 'Import from Classroom PDF',
              child: const Icon(Icons.picture_as_pdf_outlined),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.extended(
            heroTag: 'new-note-fab',
            onPressed: () => _showAddNoteDialog(context),
            icon: const Icon(Icons.note_add),
            label: const Text('New Note'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromClassroom(BuildContext context, dynamic chapter) async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    // The note must only be saved for the account that started the import.
    final sessionAtStart = HiveService.sessionId;

    _showLoadingDialog(context, 'Checking Classroom attachments...');

    List<ClassroomResource> resources = [];
    try {
      resources = await PdfImportService.listResources(
        courseId: chapter.classroomCourseId,
        courseWorkId: chapter.classroomCourseWorkId,
        sourceType: chapter.sourceType,
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // close loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check attachments: $e')),
        );
      }
      return;
    }

    if (context.mounted) Navigator.pop(context); // close loading

    if (resources.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No attachments found for this item.')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    _showLoadingDialog(context, 'Importing ${resources.length} attachment(s)...');

    try {
      final blocks = <Block>[];
      int order = 0;
      const uuid = Uuid();

      for (final res in resources) {
        if (res.type == ClassroomResourceType.pdf && res.driveFileId != null) {
          // PDF: download & simpan local copy sebagai attachment block
          final bytes = await PdfImportService.downloadPdfBytes(res.driveFileId!);
          final localPath = await PdfImportService.saveLocalCopy(bytes, res.title);
          blocks.add(
            Block(
              id: uuid.v4(),
              type: BlockType.attachment,
              content: res.title,
              order: order++,
              filePath: localPath,
            ),
          );
        } else if (res.type == ClassroomResourceType.link && res.url != null) {
          // Link/folder/doc/form/youtube: heading (nama) + link block (URL)
          blocks.add(
            Block(
              id: uuid.v4(),
              type: BlockType.heading,
              content: '🔗 ${res.title}',
              order: order++,
            ),
          );
          blocks.add(
            Block(
              id: uuid.v4(),
              type: BlockType.link,
              content: res.url!,
              order: order++,
            ),
          );
        }
      }

      if (!HiveService.isCurrentSession(sessionAtStart)) {
        if (context.mounted) Navigator.pop(context); // close loading
        return;
      }
      final newNoteId = noteProvider.addNoteFromImport(chapterId, chapter.title, blocks);

      if (context.mounted) Navigator.pop(context); // close loading

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NoteEditorScreen(noteId: newNoteId),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // close loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Note'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Note Title'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  Provider.of<NoteProvider>(context, listen: false).addNote(
                    chapterId,
                    titleController.text,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteNoteDialog(BuildContext context, dynamic note) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Note?'),
          content: Text('Are you sure you want to delete "${note.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Provider.of<NoteProvider>(context, listen: false).deleteNote(note.id);
                Navigator.pop(context);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}