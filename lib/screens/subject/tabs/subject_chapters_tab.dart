import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_app/models/chapter.dart';
import 'package:study_app/models/subject.dart';
import 'package:study_app/theme/app_theme.dart';
import 'package:study_app/widgets/custom_card.dart';
import 'package:study_app/screens/chapter/chapter_shell.dart';
import 'package:study_app/providers/chapter_provider.dart';
import 'package:study_app/providers/study_provider.dart';
import 'package:study_app/providers/note_provider.dart';
import 'package:study_app/providers/subject_provider.dart';

class SubjectChaptersTab extends StatelessWidget {
  final String subjectId;

  const SubjectChaptersTab({super.key, required this.subjectId});

  // ─── Priority color logic ───────────────────────────────────────────────────
  // Green  = completed (manual mark / overdue auto)
  // Red    = overdue + belum complete (warning!)
  // Yellow = due dalam 7 hari
  // Blue   = due lebih 7 hari / tiada due date
  Color _getPriorityColor(Chapter chapter) {
    if (chapter.isCompleted || chapter.isSubmitted == true) {
      return const Color(0xFF22C07A); // Green
    }

    final due = chapter.dueDate;
    if (due == null) return const Color(0xFF6366F1); // Blue default

    final now = DateTime.now();
    final diff = due.difference(now).inDays;

    if (due.isBefore(now)) return const Color(0xFFE84F4F); // Red - overdue!
    if (diff <= 7) return const Color(0xFFF59E0B); // Yellow - upcoming
    return const Color(0xFF6366F1); // Blue - chill
  }

  String _getPriorityLabel(Chapter chapter) {
    if (chapter.isSubmitted == true) return '✅ Submitted';
    if (chapter.isCompleted) return '✅ Completed';

    final due = chapter.dueDate;
    if (due == null) return '🔵 No due date';

    final now = DateTime.now();
    final diff = due.difference(now).inDays;

    if (due.isBefore(now)) return '🔴 Overdue!';
    if (diff <= 7) return '🟡 Due in $diff days';
    return '🔵 Due in $diff days';
  }

  // ─── Source type badge ──────────────────────────────────────────────────────
  // Tunjuk asal chapter — assignment / material / announcement dari Classroom,
  // atau tiada badge kalau manual added by student.
  Widget? _buildSourceBadge(Chapter chapter) {
    final source = chapter.sourceType;
    if (source == null) return null;

    late final String label;
    late final Color color;
    late final IconData icon;

    switch (source) {
      case 'assignment':
        label = 'Assignment';
        color = const Color(0xFF6366F1);
        icon = Icons.assignment_outlined;
        break;
      case 'material':
        label = 'Material';
        color = const Color(0xFF0EA5E9);
        icon = Icons.attach_file_rounded;
        break;
      case 'announcement':
        label = 'Announcement';
        color = const Color(0xFFF59E0B);
        icon = Icons.campaign_outlined;
        break;
      default:
        return null;
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── PDF availability badge ─────────────────────────────────────────────────
  Widget? _buildPdfBadge(Chapter chapter) {
    final count = chapter.pdfAttachmentCount ?? 0;
    if (count == 0) return null;

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF22C07A).withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf_outlined, size: 11, color: Color(0xFF22C07A)),
          const SizedBox(width: 4),
          Text(
            count == 1 ? '1 PDF available' : '$count PDFs available',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF22C07A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ambik subject untuk pass dueDate ke chapter baru
    final subject = Provider.of<SubjectProvider>(context, listen: false)
        .subjects
        .firstWhere(
          (s) => s.id == subjectId,
          orElse: () => Subject(
            id: '',
            name: '',
            colorValue: 0,
            createdDate: DateTime.now(),
          ),
        );

    return Scaffold(
      body: Consumer<ChapterProvider>(
        builder: (context, chapterProvider, child) {
          final chapters = chapterProvider.getChaptersForSubject(subjectId);

          if (chapters.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No chapters yet. Add one!',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chapters.length,
            itemBuilder: (context, index) {
              final chapter = chapters[index];
              final priorityColor = _getPriorityColor(chapter);
              final sourceBadge = _buildSourceBadge(chapter);
              final pdfBadge = _buildPdfBadge(chapter);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: CustomCard(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChapterShell(chapter: chapter),
                      ),
                    );
                  },
                  onLongPress: () => _showDeleteChapterDialog(context, chapter),
                  child: Row(
                    children: [
                      // ── Color indicator ──
                      Container(
                        width: 4,
                        height: 60,
                        decoration: BoxDecoration(
                          color: priorityColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // ── Chapter number circle ──
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: priorityColor.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: priorityColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // ── Title + status ──
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chapter.title,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    decoration: chapter.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: chapter.isCompleted
                                        ? Colors.grey
                                        : null,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            // Priority label
                            Text(
                              _getPriorityLabel(chapter),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: priorityColor,
                              ),
                            ),
                            if (sourceBadge != null || pdfBadge != null)
                              Wrap(
                                spacing: 6,
                                children: [
                                  if (sourceBadge != null) sourceBadge,
                                  if (pdfBadge != null) pdfBadge,
                                ],
                              ),
                            const SizedBox(height: 4),
                            Consumer<NoteProvider>(
                              builder: (context, noteProvider, child) {
                                final notesCount = noteProvider
                                    .getNotesForChapter(chapter.id)
                                    .length;
                                return Text(
                                  '$notesCount note${notesCount == 1 ? '' : 's'}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey.shade600),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // ── Actions ──
                      Column(
                        children: [
                          // Mark as done toggle
                          IconButton(
                            tooltip: chapter.isCompleted
                                ? 'Mark as incomplete'
                                : 'Mark as done',
                            icon: Icon(
                              chapter.isCompleted
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline,
                              color: chapter.isCompleted
                                  ? const Color(0xFF22C07A)
                                  : Colors.grey[400],
                            ),
                            onPressed: () {
                              Provider.of<ChapterProvider>(
                                context,
                                listen: false,
                              ).markAsComplete(
                                chapter.id,
                                completed: !chapter.isCompleted,
                              );
                            },
                          ),
                          // Delete
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () =>
                                _showDeleteChapterDialog(context, chapter),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      // FAB — Add chapter, auto inherit dueDate dari subject
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => _showAddChapterDialog(context, subject.dueDate),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddChapterDialog(BuildContext context, DateTime? subjectDueDate) {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Chapter'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Chapter Title'),
                autofocus: true,
              ),
              if (subjectDueDate != null) ...[
                const SizedBox(height: 8),
                // Info — chapter akan inherit due date dari subject
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEDFB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Due date akan ikut subject: ${_formatDate(subjectDueDate)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isNotEmpty) {
                  Provider.of<ChapterProvider>(
                    context,
                    listen: false,
                  ).addChapter(
                    subjectId,
                    titleController.text,
                    '',
                    dueDate: subjectDueDate, // inherit dari subject
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteChapterDialog(BuildContext context, Chapter chapter) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Chapter?'),
          content: Text('Are you sure you want to delete "${chapter.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Provider.of<ChapterProvider>(
                  context,
                  listen: false,
                ).deleteChapter(chapter.id);
                Provider.of<StudyProvider>(
                  context,
                  listen: false,
                ).deleteSessionsForChapter(chapter.id);
                Navigator.pop(context);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}