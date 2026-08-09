import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/user_profile.dart';

class ProfileRepository {
  ProfileRepository._();

  static final ProfileRepository _instance = ProfileRepository._();

  factory ProfileRepository() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserProfile? _cachedProfile;

  // =====================================================
  // Current User
  // =====================================================

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  bool get hasCache => _cachedProfile != null;

  UserProfile? get cachedProfile => _cachedProfile;

  void clearCache() {
    _cachedProfile = null;
  }

  // =====================================================
  // Save Profile
  // =====================================================

  Future<void> saveProfile(UserProfile profile) async {
    await _firestore
        .collection('users')
        .doc(profile.uid)
        .set(profile.toMap(), SetOptions(merge: true));

    _cachedProfile = profile;
  }

  // =====================================================
  // Get Profile
  // =====================================================

  Future<UserProfile?> getProfile({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedProfile != null) {
      return _cachedProfile;
    }

    final currentUid = uid;

    if (currentUid == null) {
      return null;
    }

    try {
      final doc =
          await _firestore
              .collection('users')
              .doc(currentUid)
              .get();

      if (!doc.exists) {
        return null;
      }

      final data = doc.data();

      if (data == null) {
        return null;
      }

      _cachedProfile = UserProfile.fromMap(data);

      return _cachedProfile;
    } catch (e) {
      return _cachedProfile;
    }
  }

  // =====================================================
  // Stream Profile
  // =====================================================

  Stream<UserProfile?> profileStream() {
    final currentUid = uid;

    if (currentUid == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('users')
        .doc(currentUid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        _cachedProfile = null;
        return null;
      }

      final data = snapshot.data();

      if (data == null) {
        _cachedProfile = null;
        return null;
      }

      _cachedProfile = UserProfile.fromMap(data);

      return _cachedProfile;
    });
  }

  // =====================================================
  // Update Helpers
  // =====================================================

  Future<void> updateName(String name) async {
    final currentUid = uid;

    if (currentUid == null) return;

    await _firestore
        .collection('users')
        .doc(currentUid)
        .update({
      "name": name,
    });

    if (_cachedProfile != null) {
      _cachedProfile = _cachedProfile!.copyWith(name: name);
    }
  }

  Future<void> updateEmail(String email) async {
    final currentUid = uid;

    if (currentUid == null) return;

    await _firestore
        .collection('users')
        .doc(currentUid)
        .update({
      "email": email,
    });

    if (_cachedProfile != null) {
      _cachedProfile = _cachedProfile!.copyWith(email: email);
    }
  }

  Future<void> updateAvatar(String? avatarUrl) async {
    final currentUid = uid;

    if (currentUid == null) return;

    await _firestore
        .collection('users')
        .doc(currentUid)
        .update({
      "avatarUrl": avatarUrl,
    });

    if (_cachedProfile != null) {
      _cachedProfile =
          _cachedProfile!.copyWith(
        avatarUrl: avatarUrl,
      );
    }
  }

  Future<void> updateGender(String gender) async {
    final currentUid = uid;

    if (currentUid == null) return;

    await _firestore
        .collection('users')
        .doc(currentUid)
        .update({
      "gender": gender,
      "avatarUrl": null,
    });

    if (_cachedProfile != null) {
      _cachedProfile =
          _cachedProfile!.copyWith(
        gender: gender,
        removeAvatar: true,
      );
    }
  }

  Future<void> updateTargetWeight(double targetWeight) async {
    final currentUid = uid;

    if (currentUid == null) return;

    await _firestore.collection('users').doc(currentUid).update({
      "targetWeight": targetWeight,
    });

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
    final currentUid = uid;
    if (currentUid == null) return;

    final updates = <String, dynamic>{
      "height": height,
      "currentWeight": currentWeight,
      "age": age,
      "gender": gender,
      "activityLevel": activityLevel,
      "goal": goal,
    };

    await _firestore
        .collection('users')
        .doc(currentUid)
        .set(updates, SetOptions(merge: true));

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
}