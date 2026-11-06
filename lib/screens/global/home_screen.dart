import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_app/database/hive_service.dart';
import 'package:study_app/widgets/custom_card.dart';
import 'package:study_app/screens/subject/subject_shell.dart';
import 'package:study_app/providers/subject_provider.dart';
import 'package:study_app/providers/chapter_provider.dart';
import 'package:study_app/providers/study_provider.dart';
import 'package:study_app/providers/note_provider.dart';
import 'package:study_app/models/subject.dart';
import 'package:study_app/screens/subject/dialogs/add_subject_dialog.dart';
import 'package:study_app/screens/global/search_screen.dart';
import 'package:study_app/widgets/notification_sheet.dart';
import 'package:study_app/services/classroom_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showOnlyWithDueDate = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('My Subjects'),
        actions: [
          InkWell(
            onTap: () {
              setState(() => _showOnlyWithDueDate = !_showOnlyWithDueDate);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showOnlyWithDueDate
                        ? Icons.filter_alt_rounded
                        : Icons.filter_alt_outlined,
                    size: 22,
                  ),
                  const Text('Due date', style: TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => _syncFromClassroom(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sync_rounded, size: 22),
                  const Text('Classroom', style: TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => _showNotifications(context),
          ),
        ],
      ),
      body: Consumer<SubjectProvider>(
  builder: (context, subjectProvider, child) {
    final chapterProvider = Provider.of<ChapterProvider>(context);
    final allSubjects = subjectProvider.subjects;
    final subjects = _showOnlyWithDueDate
        ? allSubjects.where((s) {
            final chapters = chapterProvider.getChaptersForSubject(s.id);
            return chapters.any((c) => c.dueDate != null && !c.isCompleted);
          }).toList()
        : allSubjects;

          if (allSubjects.isEmpty) {
            return const Center(child: Text("No subjects yet. Add one!"));
          }

          if (subjects.isEmpty) {
            return const Center(
              child: Text(
                "No tasks with a due date.\nTap 'Due date' to show all.",
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: subjects.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final subject = subjects[index];
              return _buildSubjectCard(context, subject);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddSubjectDialog(
              onSubjectAdded: (subject) {
                Provider.of<SubjectProvider>(
                  context,
                  listen: false,
                ).addSubjectModel(subject);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${subject.name} added successfully!'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, Subject subject) {
    final baseColor = Color(subject.colorValue);
    final hsl = HSLColor.fromColor(baseColor);
    final gradient = LinearGradient(
      colors: [
        hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor(),
        hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor(),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Consumer<ChapterProvider>(
  builder: (context, chapterProvider, child) {
    final subjectChapters = chapterProvider.getChaptersForSubject(subject.id);
    final chaptersCount = subjectChapters.length;
    final totalPdfCount = subjectChapters.fold<int>(
      0,
      (sum, c) => sum + (c.pdfAttachmentCount ?? 0),
    );

        return CustomCard(
          gradient: gradient,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SubjectShell(subject: subject)),
            );
          },
          onLongPress: () => _showDeleteSubjectDialog(context, subject),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      subject.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.displaySmall?.copyWith(color: Colors.white),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                        onPressed: () =>
                            _showDeleteSubjectDialog(context, subject),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
  _buildStatChip(
    context,
    Icons.menu_book_rounded,
    '$chaptersCount Chapters',
  ),
  if (totalPdfCount > 0)
    _buildStatChip(
      context,
      Icons.picture_as_pdf_outlined,
      totalPdfCount == 1 ? '1 PDF' : '$totalPdfCount PDFs',
    ),
  Consumer<StudyProvider>(
                    builder: (context, studyProvider, child) {
                      final mins = studyProvider.getTotalStudyTimeForSubject(
                        subject.id,
                      );
                      final hoursStr = mins >= 60
                          ? '${mins ~/ 60}h ${mins % 60}m'
                          : '${mins}m';
                      return _buildStatChip(
                        context,
                        Icons.timer_rounded,
                        hoursStr,
                      );
                    },
                  ),
                  if (subject.dueDate != null)
                    _buildStatChip(
                      context,
                      Icons.event_rounded,
                      'Due ${_formatDueDate(subject.dueDate!, subject.dueTime)}',
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatChip(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(51),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDueDate(DateTime date, TimeOfDay? time) {
    final months = [
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
    final dateStr = '${date.day} ${months[date.month - 1]}';
    if (time == null) return dateStr;
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$dateStr, $hour:$minute $period';
  }

  void _showDeleteSubjectDialog(BuildContext context, Subject subject) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Subject?'),
          content: Text(
            'Are you sure you want to delete "${subject.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                final subjectId = subject.id;

                final chapterIds = Provider.of<ChapterProvider>(
                  context,
                  listen: false,
                ).getChaptersForSubject(subjectId).map((c) => c.id).toList();

                for (final cId in chapterIds) {
                  Provider.of<NoteProvider>(
                    context,
                    listen: false,
                  ).deleteNotesForChapter(cId);
                  Provider.of<StudyProvider>(
                    context,
                    listen: false,
                  ).deleteSessionsForChapter(cId);
                }

                Provider.of<NoteProvider>(
                  context,
                  listen: false,
                ).deleteNotesForChapter(subjectId);

                Provider.of<StudyProvider>(
                  context,
                  listen: false,
                ).deleteSessionsForSubject(subjectId);

                Provider.of<ChapterProvider>(
                  context,
                  listen: false,
                ).deleteChaptersForSubject(subjectId);

                Provider.of<SubjectProvider>(
                  context,
                  listen: false,
                ).deleteSubject(subjectId);
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

  void _showNotifications(BuildContext context) {
    NotificationSheet.show(context);
  }

  Future<void> _syncFromClassroom(BuildContext context) async {
    // Results must only be written for the account that started the sync.
    final sessionAtStart = HiveService.sessionId;
    if (!ClassroomService.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in with Google to use Classroom sync'),
        ),
      );
      return;
    }

    final cutoff = await showDialog<DateTime?>(
      context: context,
      builder: (ctx) => SimpleDialog(
  title: const Text('Sync assignments dari?'),
  children: [
    SimpleDialogOption(
      onPressed: () {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        Navigator.pop(ctx, startOfMonth);
      },
      child: const Text('This month only'),
    ),
    SimpleDialogOption(
      onPressed: () => Navigator.pop(ctx, null),
      child: const Text('All (including old & overdue)'),
    ),
  ],
),
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final assignments = await ClassroomService.fetchAllAssignments(
        since: cutoff,
      );
      final subjectProvider = Provider.of<SubjectProvider>(
        context,
        listen: false,
      );
      final chapterProvider = Provider.of<ChapterProvider>(
        context,
        listen: false,
      );

      final Map<String, List<ClassroomAssignment>> byCourse = {};
      for (final a in assignments) {
        byCourse.putIfAbsent(a.courseId, () => []).add(a);
      }

      int subjectsAdded = 0;
      int chaptersAdded = 0;

      for (final entry in byCourse.entries) {
        if (!HiveService.isCurrentSession(sessionAtStart)) return;
        final courseId = entry.key;
        final courseAssignments = entry.value;
        final courseTitle = courseAssignments.first.courseTitle;

        final existingSubject = subjectProvider.subjects
            .where(
              (s) =>
                  s.id == courseId ||
                  s.name.trim().toLowerCase() ==
                      courseTitle.trim().toLowerCase(),
            )
            .firstOrNull;

        String subjectId = existingSubject?.id ?? courseId;

        if (existingSubject == null) {
          final subject = Subject(
            id: courseId,
            name: courseTitle,
            colorValue: 0xFF6C63FF,
            createdDate: DateTime.now(),
          );
          subjectProvider.addSubjectModel(subject);
          subjectsAdded++;
        }

        final existingChapters = chapterProvider.getChaptersForSubject(
          subjectId,
        );
        final existingChapterIds = existingChapters.map((c) => c.id).toSet();

        for (final a in courseAssignments) {
          final chapterId = '${a.courseId}_${a.courseWorkId}';

          DateTime? dueDateOnly;
          if (a.dueDate != null) {
            dueDateOnly = DateTime(
              a.dueDate!.year,
              a.dueDate!.month,
              a.dueDate!.day,
              a.dueDate!.hour,
              a.dueDate!.minute,
            );
          }

          final isNewChapter = !existingChapterIds.contains(chapterId);

bool? submitted;
if (a.type == ClassroomItemType.assignment) {
  submitted = await ClassroomService.isSubmitted(
    courseId: a.courseId,
    courseWorkId: a.courseWorkId,
  );
}

if (!HiveService.isCurrentSession(sessionAtStart)) return;
chapterProvider.upsertChapterFromSync(
  id: chapterId,
  subjectId: subjectId,
  title: a.title,
  description: a.description ?? '',
  dueDate: dueDateOnly,
  sourceType: a.type.name,
  classroomCourseId: a.courseId,
  classroomCourseWorkId: a.courseWorkId,
  pdfAttachmentCount: a.pdfAttachmentCount,
  isSubmitted: submitted,
);

          if (isNewChapter) chaptersAdded++;
        }
      }

      if (context.mounted) {
        Navigator.pop(context);
        setState(() => _showOnlyWithDueDate = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$subjectsAdded course baru, $chaptersAdded assignment disync!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    }
  }
}
