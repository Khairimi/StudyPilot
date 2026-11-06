// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    // Web: google_sign_in_web needs a separate OAuth client ID, so use the
    // Firebase Auth popup flow instead. Android keeps the native flow below.
    if (kIsWeb) {
      try {
        // select_account: always show the account chooser instead of
        // silently reusing the last Google account used in this browser.
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        final userCred =
            await FirebaseAuth.instance.signInWithPopup(provider);
        return userCred.user;
      } on FirebaseAuthException catch (e) {
        // User closed the popup or a second popup replaced it: treat as cancel.
        if (e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          return null;
        }
        rethrow;
      }
    }

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
    if (!kIsWeb) await googleSignIn.signOut();
    googleUser = null;
  }

  /// Full app logout: clears the cached Google SDK account (Android) so the
  /// next Google sign-in shows the account picker, then signs out of Firebase.
  /// Does not sign the user out of Google itself or revoke app access.
  static Future<void> signOut() async {
    try {
      await signOutGoogle();
    } catch (_) {
      // Email/password users have no Google session; ignore and continue.
    }
    await FirebaseAuth.instance.signOut();
  }
}