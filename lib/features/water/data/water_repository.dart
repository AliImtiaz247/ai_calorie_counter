import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/goal_completion_service.dart';
import '../models/water.dart';

/// Repository for daily water data.
///
/// Performance characteristics:
/// - Keeps today's water document in memory.
/// - Deduplicates concurrent reads for the same date.
/// - Uses Firestore atomic increment for additions, avoiding read-modify-write races.
/// - Updates the local cache immediately after successful writes.
class WaterRepository extends ChangeNotifier {
  WaterRepository._();

  static final WaterRepository _instance = WaterRepository._();

  factory WaterRepository() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Water? _cachedWater;
  String? _cachedDateKey;

  final Map<String, Future<Water>> _inFlightReads = <String, Future<Water>>{};

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  String formatDateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String get today => formatDateKey(DateTime.now());

  DocumentReference<Map<String, dynamic>> _waterDocForDate(DateTime dt) {
    final currentUid = uid;
    if (currentUid == null) {
      throw StateError('User is signed out.');
    }

    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('water')
        .doc(formatDateKey(dt));
  }

  void clearCache() {
    _cachedWater = null;
    _cachedDateKey = null;
    _inFlightReads.clear();
  }

  Future<Water> getTodayWater({bool forceRefresh = false}) {
    return getWaterForDate(DateTime.now(), forceRefresh: forceRefresh);
  }

  Future<Water> getWaterForDate(
    DateTime dt, {
    bool forceRefresh = false,
  }) async {
    final dateKey = formatDateKey(dt);

    if (!forceRefresh &&
        dateKey == today &&
        _cachedWater != null &&
        _cachedDateKey == dateKey) {
      return _cachedWater!;
    }

    if (uid == null) {
      return Water(date: dateKey, goal: 3000, consumed: 0);
    }

    if (!forceRefresh) {
      final existingRequest = _inFlightReads[dateKey];
      if (existingRequest != null) return existingRequest;
    }

    final future = _readWaterDocument(dt, dateKey);
    _inFlightReads[dateKey] = future;

    try {
      return await future;
    } finally {
      if (identical(_inFlightReads[dateKey], future)) {
        _inFlightReads.remove(dateKey);
      }
    }
  }

  Future<Water> _readWaterDocument(DateTime dt, String dateKey) async {
    try {
      final doc = await _waterDocForDate(dt).get();

      if (!doc.exists || doc.data() == null) {
        final water = Water(date: dateKey, goal: 3000, consumed: 0);

        // Only create today's document automatically. Historical reads should
        // remain read-only so opening history does not create empty documents.
        if (dateKey == today) {
          await _waterDocForDate(dt).set({
            ...water.toMap(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          _cachedWater = water;
          _cachedDateKey = dateKey;
        }

        return water;
      }

      final water = Water.fromMap(dateKey, doc.data()!);

      if (dateKey == today) {
        _cachedWater = water;
        _cachedDateKey = dateKey;
      }

      return water;
    } catch (e) {
      debugPrint('Error reading water document for $dateKey: $e');

      // Do not overwrite a valid cache with a fallback value.
      if (dateKey == today &&
          _cachedWater != null &&
          _cachedDateKey == dateKey) {
        return _cachedWater!;
      }

      return Water(date: dateKey, goal: 3000, consumed: 0);
    }
  }

  Future<Map<String, int>> getWaterForLastDays(int days) async {
    if (uid == null || days <= 0) return <String, int>{};

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final end = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));

    final result = <String, int>{};
    for (var i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      result[formatDateKey(day)] = 0;
    }

    try {
      // Only fetch the requested range instead of the entire water collection.
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('water')
          .where(
            'date',
            isGreaterThanOrEqualTo: formatDateKey(start),
          )
          .where(
            'date',
            isLessThan: formatDateKey(end),
          )
          .get();

      for (final doc in snapshot.docs) {
        if (result.containsKey(doc.id)) {
          result[doc.id] = (doc.data()['consumed'] as num?)?.toInt() ?? 0;
        }
      }
    } catch (e) {
      debugPrint('Error loading historical water data: $e');
    }

    return result;
  }

  Future<void> addWater(int amount, {DateTime? date}) async {
    if (amount <= 0 || uid == null) return;

    final targetDate = date ?? DateTime.now();
    final dateKey = formatDateKey(targetDate);

    Water? current;
    if (dateKey == today &&
        _cachedWater != null &&
        _cachedDateKey == dateKey) {
      current = _cachedWater;
    } else {
      current = await getWaterForDate(targetDate);
    }

    final newConsumed = current.consumed + amount;

    try {
      // Atomic increment prevents lost updates if two taps/requests happen
      // nearly simultaneously and avoids another Firestore read.
      await _waterDocForDate(targetDate).set({
        'date': dateKey,
        'goal': current.goal,
        'consumed': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final updatedWater = Water(
        date: dateKey,
        goal: current.goal,
        consumed: newConsumed,
      );

      if (dateKey == today) {
        _cachedWater = updatedWater;
        _cachedDateKey = dateKey;
        notifyListeners();

        await GoalCompletionService.instance.checkWaterGoal(
          consumedWater: newConsumed,
          waterGoal: current.goal,
          date: targetDate,
        );
      }
    } catch (e) {
      debugPrint('Failed to add water: $e');
      rethrow;
    }
  }

  Future<void> removeWater(int amount, {DateTime? date}) async {
    if (amount <= 0 || uid == null) return;

    final targetDate = date ?? DateTime.now();
    final water = await getWaterForDate(targetDate);
    final newValue = (water.consumed - amount).clamp(0, 1 << 30);

    await updateWater(newValue, date: targetDate);
  }

  Future<void> updateWater(int consumed, {DateTime? date}) async {
    if (uid == null) return;

    final targetDate = date ?? DateTime.now();
    final dateKey = formatDateKey(targetDate);

    Water current;
    if (dateKey == today &&
        _cachedWater != null &&
        _cachedDateKey == dateKey) {
      current = _cachedWater!;
    } else {
      current = await getWaterForDate(targetDate);
    }

    final safeConsumed = consumed < 0 ? 0 : consumed;

    await _waterDocForDate(targetDate).set({
      'date': dateKey,
      'consumed': safeConsumed,
      'goal': current.goal,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final updatedWater = Water(
      date: dateKey,
      goal: current.goal,
      consumed: safeConsumed,
    );

    if (dateKey == today) {
      _cachedWater = updatedWater;
      _cachedDateKey = dateKey;
      notifyListeners();

      await GoalCompletionService.instance.checkWaterGoal(
        consumedWater: safeConsumed,
        waterGoal: current.goal,
        date: targetDate,
      );
    }
  }

  Future<void> updateGoal(int goal, {DateTime? date}) async {
    if (uid == null || goal <= 0) return;

    final targetDate = date ?? DateTime.now();
    final dateKey = formatDateKey(targetDate);

    Water current;
    if (dateKey == today &&
        _cachedWater != null &&
        _cachedDateKey == dateKey) {
      current = _cachedWater!;
    } else {
      current = await getWaterForDate(targetDate);
    }

    await _waterDocForDate(targetDate).set({
      'date': dateKey,
      'goal': goal,
      'consumed': current.consumed,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final updatedWater = Water(
      date: dateKey,
      goal: goal,
      consumed: current.consumed,
    );

    if (dateKey == today) {
      _cachedWater = updatedWater;
      _cachedDateKey = dateKey;
      notifyListeners();

      await GoalCompletionService.instance.checkWaterGoal(
        consumedWater: current.consumed,
        waterGoal: goal,
        date: targetDate,
      );
    }
  }

  Future<void> refresh() async {
    await getTodayWater(forceRefresh: true);
    notifyListeners();
  }
}
