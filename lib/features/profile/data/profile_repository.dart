import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/user_profile.dart';

/// Profile repository with an in-memory cache and one stable Firestore stream.
class ProfileRepository {
  ProfileRepository._();

  static final ProfileRepository _instance = ProfileRepository._();

  factory ProfileRepository() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserProfile? _cachedProfile;
  Stream<UserProfile?>? _cachedProfileStream;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;
  bool get hasCache => _cachedProfile != null;
  UserProfile? get cachedProfile => _cachedProfile;

  void clearCache() {
    _cachedProfile = null;
    _cachedProfileStream = null;
  }

  Future<void> saveProfile(UserProfile profile) async {
    final currentUid = uid;
    if (currentUid == null || currentUid != profile.uid) {
      throw StateError('Cannot save a profile for a different or signed-out user.');
    }

    final data = profile.toMap();
    data.remove('createdAt');

    await _firestore
        .collection('users')
        .doc(currentUid)
        .set(data, SetOptions(merge: true));

    _cachedProfile = profile;
  }

  Future<UserProfile?> getProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedProfile != null) return _cachedProfile;

    final currentUid = uid;
    if (currentUid == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(currentUid).get();
      if (!doc.exists || doc.data() == null) return null;

      _cachedProfile = UserProfile.fromMap(doc.data()!);
      return _cachedProfile;
    } catch (_) {
      return _cachedProfile;
    }
  }

  /// Returns the same broadcast stream for the lifetime of the signed-in user.
  /// This prevents dashboard rebuilds from creating repeated Firestore listeners.
  Stream<UserProfile?> profileStream() {
    final currentUid = uid;
    if (currentUid == null) return Stream<UserProfile?>.value(null);

    final existing = _cachedProfileStream;
    if (existing != null) return existing;

    final stream = _firestore
        .collection('users')
        .doc(currentUid)
        .snapshots()
        .map<UserProfile?>((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        _cachedProfile = null;
        return null;
      }

      final profile = UserProfile.fromMap(snapshot.data()!);
      _cachedProfile = profile;
      return profile;
    }).asBroadcastStream();

    _cachedProfileStream = stream;
    return stream;
  }

  Future<void> updateName(String name) async {
    final value = name.trim();
    await _update({'name': value});
    if (_cachedProfile != null) {
      _cachedProfile = _cachedProfile!.copyWith(name: value);
    }
  }

  Future<void> updateEmail(String email) async {
    final value = email.trim();
    await _update({'email': value});
    if (_cachedProfile != null) {
      _cachedProfile = _cachedProfile!.copyWith(email: value);
    }
  }

  Future<void> updateAvatar(String? avatarUrl) async {
    await _update({'avatarUrl': avatarUrl});
    if (_cachedProfile != null) {
      _cachedProfile = _cachedProfile!.copyWith(
        avatarUrl: avatarUrl,
        removeAvatar: avatarUrl == null,
      );
    }
  }

  Future<void> updateGender(String gender) async {
    await _update({'gender': gender, 'avatarUrl': null});
    if (_cachedProfile != null) {
      _cachedProfile = _cachedProfile!.copyWith(
        gender: gender,
        removeAvatar: true,
      );
    }
  }

  Future<void> updateTargetWeight(double targetWeight) async {
    await _update({'targetWeight': targetWeight});
    if (_cachedProfile != null) {
      _cachedProfile = _cachedProfile!.copyWith(targetWeight: targetWeight);
    }
  }

  Future<void> updateHealthMetrics({
    required double height,
    required double currentWeight,
    required int age,
    required String gender,
    required String activityLevel,
    required String goal,
  }) async {
    await _update({
      'height': height,
      'currentWeight': currentWeight,
      'age': age,
      'gender': gender,
      'activityLevel': activityLevel,
      'goal': goal,
    });

    if (_cachedProfile != null) {
      _cachedProfile = _cachedProfile!.copyWith(
        height: height,
        currentWeight: currentWeight,
        age: age,
        gender: gender,
        activityLevel: activityLevel,
        goal: goal,
      );
    }
  }

  Future<void> _update(Map<String, dynamic> updates) async {
    final currentUid = uid;
    if (currentUid == null) throw StateError('User is signed out.');

    if (updates.containsKey('uid') ||
        updates.containsKey('createdAt') ||
        updates.containsKey('scanCount')) {
      throw ArgumentError('Attempted to update a server-controlled profile field.');
    }

    await _firestore
        .collection('users')
        .doc(currentUid)
        .update(updates);
  }
}
