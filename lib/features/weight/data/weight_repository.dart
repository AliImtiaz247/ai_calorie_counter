import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/goal_completion_service.dart';
import '../models/weight_log.dart';

class WeightRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _weightCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('weight_logs');
  }

  /// Get weight logs stream sorted by date ascending
  Stream<List<WeightLog>> getWeightLogsStream() {
    final uid = currentUserId;
    if (uid == null) return Stream.value([]);

    return _weightCollection(uid)
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WeightLog.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Add a new weight log
  Future<void> addWeightLog(double weight, {DateTime? date, String? note}) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    final docRef = _weightCollection(uid).doc();
    final log = WeightLog(
      id: docRef.id,
      userId: uid,
      weight: weight,
      date: date ?? DateTime.now(),
      note: note,
    );

    await docRef.set(log.toMap());

    // Update user profile currentWeight with latest entry
    await _firestore.collection('users').doc(uid).update({
      'currentWeight': weight,
    });

    // Check if weight goal is reached
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final targetWeight = (userDoc.data()?['targetWeight'] ?? 0.0) is num
            ? (userDoc.data()?['targetWeight'] as num).toDouble()
            : 0.0;
        if (targetWeight > 0) {
          await GoalCompletionService.instance.checkWeightGoal(
            currentWeight: weight,
            targetWeight: targetWeight,
            userId: uid,
          );
        }
      }
    } catch (_) {}
  }

  /// Delete a weight log
  Future<void> deleteWeightLog(String logId) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    await _weightCollection(uid).doc(logId).delete();
  }
}
