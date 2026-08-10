import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/goal_completion_service.dart';
import '../models/water.dart';

class WaterRepository extends ChangeNotifier {
  WaterRepository._();

  static final WaterRepository _instance = WaterRepository._();

  factory WaterRepository() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Water? _cachedWater;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  String formatDateKey(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  String get today => formatDateKey(DateTime.now());

  DocumentReference<Map<String, dynamic>> _waterDocForDate(DateTime dt) {
    return _firestore
        .collection("users")
        .doc(uid)
        .collection("water")
        .doc(formatDateKey(dt));
  }

  void clearCache() {
    _cachedWater = null;
  }

  Future<Water> getTodayWater({
    bool forceRefresh = false,
  }) async {
    return getWaterForDate(DateTime.now(), forceRefresh: forceRefresh);
  }

  Future<Water> getWaterForDate(
    DateTime dt, {
    bool forceRefresh = false,
  }) async {
    final dateKey = formatDateKey(dt);
    if (!forceRefresh &&
        dateKey == today &&
        _cachedWater != null) {
      return _cachedWater!;
    }

    if (uid == null) {
      return Water(date: dateKey, goal: 3000, consumed: 0);
    }

    try {
      final doc = await _waterDocForDate(dt).get();

      if (!doc.exists) {
        final water = Water(
          date: dateKey,
          goal: 3000,
          consumed: 0,
        );

        if (dateKey == today) {
          await _waterDocForDate(dt).set(water.toMap());
          _cachedWater = water;
        }

        return water;
      }

      final water = Water.fromMap(
        dateKey,
        doc.data()!,
      );

      if (dateKey == today) {
        _cachedWater = water;
      }

      return water;
    } catch (e) {
      debugPrint("Error reading water doc for date $dateKey: $e");
      return Water(date: dateKey, goal: 3000, consumed: 0);
    }
  }

  Future<Map<String, int>> getWaterForLastDays(int days) async {
    if (uid == null) return {};
    final map = <String, int>{};
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1 - i));
      map[formatDateKey(day)] = 0;
    }

    try {
      final snapshot = await _firestore
          .collection("users")
          .doc(uid)
          .collection("water")
          .get();

      for (final doc in snapshot.docs) {
        if (map.containsKey(doc.id)) {
          final data = doc.data();
          map[doc.id] = (data["consumed"] as num?)?.toInt() ?? 0;
        }
      }
    } catch (e) {
      debugPrint("Error loading historical water data: $e");
    }

    return map;
  }

  Future<void> addWater(int amount, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateKey = formatDateKey(targetDate);
    if (uid == null) return;

    final docRef = _waterDocForDate(targetDate);
    final existingDoc = await docRef.get();
    int currentGoal = 3000;
    int currentConsumed = 0;

    if (existingDoc.exists) {
      final data = existingDoc.data();
      currentGoal = (data?["goal"] as num?)?.toInt() ?? 3000;
      currentConsumed = (data?["consumed"] as num?)?.toInt() ?? 0;
    }

    final newConsumed = currentConsumed + amount;

    await docRef.set(
      {
        "date": dateKey,
        "goal": currentGoal,
        "consumed": newConsumed,
        "updatedAt": Timestamp.now(),
      },
      SetOptions(merge: true),
    );

    final updatedWater = Water(
      date: dateKey,
      goal: currentGoal,
      consumed: newConsumed,
    );

    if (dateKey == today) {
      _cachedWater = updatedWater;
      await GoalCompletionService.instance.checkWaterGoal(
        consumedWater: newConsumed,
        waterGoal: currentGoal,
        date: targetDate,
      );
    }
    notifyListeners();
  }

  Future<void> removeWater(int amount, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final water = await getWaterForDate(targetDate);

    int newValue = water.consumed - amount;
    if (newValue < 0) {
      newValue = 0;
    }

    await updateWater(newValue, date: targetDate);
  }

  Future<void> updateWater(int consumed, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateKey = formatDateKey(targetDate);
    if (uid == null) return;

    final docRef = _waterDocForDate(targetDate);
    final existingDoc = await docRef.get();
    int currentGoal = 3000;
    if (existingDoc.exists) {
      final data = existingDoc.data();
      currentGoal = (data?["goal"] as num?)?.toInt() ?? 3000;
    }

    await docRef.set(
      {
        "date": dateKey,
        "consumed": consumed,
        "goal": currentGoal,
        "updatedAt": Timestamp.now(),
      },
      SetOptions(merge: true),
    );

    final updatedWater = Water(
      date: dateKey,
      goal: currentGoal,
      consumed: consumed,
    );

    if (dateKey == today) {
      _cachedWater = updatedWater;
      await GoalCompletionService.instance.checkWaterGoal(
        consumedWater: consumed,
        waterGoal: currentGoal,
        date: targetDate,
      );
    }
    notifyListeners();
  }

  Future<void> updateGoal(int goal, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateKey = formatDateKey(targetDate);
    if (uid == null) return;

    final docRef = _waterDocForDate(targetDate);
    final existingDoc = await docRef.get();
    int currentConsumed = 0;
    if (existingDoc.exists) {
      final data = existingDoc.data();
      currentConsumed = (data?["consumed"] as num?)?.toInt() ?? 0;
    }

    await docRef.set(
      {
        "date": dateKey,
        "goal": goal,
        "consumed": currentConsumed,
        "updatedAt": Timestamp.now(),
      },
      SetOptions(merge: true),
    );

    final updatedWater = Water(
      date: dateKey,
      goal: goal,
      consumed: currentConsumed,
    );

    if (dateKey == today) {
      _cachedWater = updatedWater;
      await GoalCompletionService.instance.checkWaterGoal(
        consumedWater: currentConsumed,
        waterGoal: goal,
        date: targetDate,
      );
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    await getTodayWater(forceRefresh: true);
  }
}