import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveProfile(UserProfile profile) async {
    await _firestore.collection("users").doc(profile.uid).set(profile.toMap());
  }

  Future<UserProfile?> getProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    final doc = await _firestore.collection("users").doc(user.uid).get();

    if (!doc.exists) return null;

    return UserProfile.fromMap(doc.data()!);
  }
}
