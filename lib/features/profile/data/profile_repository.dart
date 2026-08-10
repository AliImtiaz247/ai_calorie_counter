import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/user_profile.dart';

class ProfileRepository {
  ProfileRepository._();
  static final ProfileRepository _instance = ProfileRepository._();
  factory ProfileRepository() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserProfile? _cachedProfile;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;
  bool get hasCache => _cachedProfile != null;
  UserProfile? get cachedProfile => _cachedProfile;

  void clearCache() => _cachedProfile = null;

  Future<void> saveProfile(UserProfile profile) async {
    final currentUid = uid;
    if (currentUid == null || currentUid != profile.uid) {
      throw StateError('Cannot save a profile for a different or signed-out user.');
    }

    final data = profile.toMap();
    // createdAt is immutable under production Firestore rules. Do not overwrite it.
    data.remove('createdAt');

    await _firestore.collection('users').doc(currentUid).set(data, SetOptions(merge: true));
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

  Stream<UserProfile?> profileStream() {
    final currentUid = uid;
    if (currentUid == null) return Stream.value(null);

    return _firestore.collection('users').doc(currentUid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        _cachedProfile = null;
        return null;
      }
      _cachedProfile = UserProfile.fromMap(snapshot.data()!);
      return _cachedProfile;
    });
  }

  Future<void> updateName(String name) async {
    await _update({'name': name.trim()});
    if (_cachedProfile != null) _cachedProfile = _cachedProfile!.copyWith(name: name.trim());
  }

  Future<void> updateEmail(String email) async {
    await _update({'email': email.trim()});
    if (_cachedProfile != null) _cachedProfile = _cachedProfile!.copyWith(email: email.trim());
  }

  Future<void> updateAvatar(String? avatarUrl) async {
    final data = <String, dynamic>{'avatarUrl': avatarUrl};
    await _update(data);
    if (_cachedProfile != null) {
      _cachedProfile = _cachedProfile!.copyWith(avatarUrl: avatarUrl, removeAvatar: avatarUrl == null);
    }
  }

  Future<void> updateGender(String gender) async {
    await _update({'gender': gender, 'avatarUrl': null});
    if (_cachedProfile != null) {
      _cachedProfile = _cachedProfile!.copyWith(gender: gender, removeAvatar: true);
    }
  }

  Future<void> updateTargetWeight(double targetWeight) async {
    await _update({'targetWeight': targetWeight});
    if (_cachedProfile != null) _cachedProfile = _cachedProfile!.copyWith(targetWeight: targetWeight);
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
    if (updates.containsKey('uid') || updates.containsKey('createdAt') || updates.containsKey('scanCount')) {
      throw ArgumentError('Attempted to update a server-controlled profile field.');
    }
    await _firestore.collection('users').doc(currentUid).update(updates);
  }
}
