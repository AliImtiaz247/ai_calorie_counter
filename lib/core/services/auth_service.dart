import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/meals/data/meal_repository.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/steps/data/step_repository.dart';
import '../../features/water/data/water_repository.dart';
import 'goal_completion_service.dart';
import 'notification_service.dart';
import 'sync_service.dart';

class AuthService {
  static const _lastActiveKey = 'lastActiveAt';
  static const _rememberMeKey = 'rememberMe';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await setRememberMe(rememberMe);
    await updateLastActive();
    return credential;
  }

  Future<UserCredential?> signInWithGoogle({bool rememberMe = false}) async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    await setRememberMe(rememberMe);
    await updateLastActive();
    return userCredential;
  }

  Future<void> setRememberMe(bool rememberMe) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, rememberMe);
  }

  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  Future<void> logout() async {
    try {
      await StepRepository.instance.disableStepTracking();
      StepRepository.instance.clearCache();
    } catch (_) {}

    try {
      MealRepository().clearCache();
    } catch (_) {}

    try {
      WaterRepository().clearCache();
    } catch (_) {}

    try {
      ProfileRepository().clearCache();
    } catch (_) {}

    try {
      await NotificationService.instance.clearAll();
    } catch (_) {}

    try {
      SyncService.instance.onLogout();
    } catch (_) {}

    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    await _auth.signOut();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastActiveKey);
    await prefs.remove(_rememberMeKey);
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    try {
      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection('users').doc(uid);
      final subcollections = [
        'meals',
        'water',
        'steps',
        'notifications',
        'weight_logs',
        'ai_scan_usage',
      ];
      for (final col in subcollections) {
        final docs = await userRef.collection(col).get();
        for (final doc in docs.docs) {
          await doc.reference.delete();
        }
      }
      await userRef.delete();
    } catch (e) {
      debugPrint("Error deleting user Firestore data: $e");
    }

    await logout();
    await user.delete();
  }

  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
  }

  Future<void> updateEmail(String email) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }
    await user.verifyBeforeUpdateEmail(email);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateLastActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastActiveKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> validateSession() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_rememberMeKey) ?? false;

    if (!rememberMe) {
      await logout();
      return false;
    }

    final lastActiveMillis = prefs.getInt(_lastActiveKey);
    if (lastActiveMillis == null) {
      await updateLastActive();
      return true;
    }

    final lastActive = DateTime.fromMillisecondsSinceEpoch(lastActiveMillis);
    final now = DateTime.now();
    const maxDuration = Duration(days: 15);

    if (now.difference(lastActive) > maxDuration) {
      await logout();
      return false;
    }

    await updateLastActive();
    return true;
  }

  User? get currentUser => _auth.currentUser;

  /// Returns the current Firebase ID token. Set [forceRefresh] to true after
  /// an authentication failure so a stale token can be replaced before retry.
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }
}
