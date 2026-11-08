import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:study_app/database/user_session.dart';
import 'package:study_app/studypilot/core/branding.dart';
import 'package:study_app/studypilot/core/theme/sp_theme.dart';
import 'package:study_app/screens/global/splash_screen.dart';
import 'package:study_app/screens/global/user_session_gate.dart';
import 'package:provider/provider.dart';
import 'package:study_app/database/hive_service.dart';
import 'package:study_app/providers/subject_provider.dart';
import 'package:study_app/providers/chapter_provider.dart';
import 'package:study_app/providers/note_provider.dart';
import 'package:study_app/providers/theme_provider.dart';
import 'package:study_app/providers/study_provider.dart';
import 'package:study_app/providers/todo_provider.dart';
import 'package:study_app/providers/flashcard_provider.dart';
import 'package:study_app/providers/mind_map_provider.dart';
import 'package:study_app/providers/academic_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:study_app/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // User-scoped providers: their data is cleared and reloaded by
  // UserSession whenever the signed-in Firebase user changes.
  final subjectProvider = SubjectProvider();
  final chapterProvider = ChapterProvider();
  final noteProvider = NoteProvider();
  final studyProvider = StudyProvider();
  final todoProvider = TodoProvider();
  final flashcardProvider = FlashcardProvider();
  final mindMapProvider = MindMapProvider();
  final academicProvider = AcademicProvider();

  final session = UserSession(
    uidStream: FirebaseAuth.instance.authStateChanges().map((u) => u?.uid),
    participants: [
      subjectProvider,
      chapterProvider,
      noteProvider,
      studyProvider,
      todoProvider,
      flashcardProvider,
      mindMapProvider,
      academicProvider,
    ],
  )..start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: subjectProvider),
        ChangeNotifierProvider.value(value: chapterProvider),
        ChangeNotifierProvider.value(value: noteProvider),
        ChangeNotifierProvider.value(value: studyProvider),
        ChangeNotifierProvider.value(value: todoProvider),
        ChangeNotifierProvider.value(value: flashcardProvider),
        ChangeNotifierProvider.value(value: mindMapProvider),
        ChangeNotifierProvider.value(value: academicProvider),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const StudyApp(),
    ),
  );
}

class StudyApp extends StatelessWidget {
  const StudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: SpBrand.appName,
          debugShowCheckedModeBanner: false,
          theme: SpTheme.light,
          darkTheme: SpTheme.dark,
          themeMode: themeProvider.themeMode,
          // Covers the app while a user's storage is loading or failed.
          builder: (context, child) => UserSessionGate(child: child!),
          home: const SplashScreen(),
        );
      },
    );
  }
}
