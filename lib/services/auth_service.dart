// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // Satu instance shared — combine scope login + Classroom + Drive
  static final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/classroom.courses.readonly',
      'https://www.googleapis.com/auth/classroom.coursework.me.readonly',
      // Perlu untuk fetch material (slide, reference doc) yang lecturer post
      'https://www.googleapis.com/auth/classroom.courseworkmaterials.readonly',
      // Perlu untuk fetch announcement/stream post
      'https://www.googleapis.com/auth/classroom.announcements.readonly',
      // Perlu untuk download PDF attachment (Quick Notes import)
      'https://www.googleapis.com/auth/drive.readonly',
    ],
  );

  static GoogleSignInAccount? googleUser;

  static Future<User?> signInWithGoogle() async {
    googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null; // user cancel

    final googleAuth = await googleUser!.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
    return userCred.user;
  }

  static Future<void> signOutGoogle() async {
    await googleSignIn.signOut();
    googleUser = null;
  }
}