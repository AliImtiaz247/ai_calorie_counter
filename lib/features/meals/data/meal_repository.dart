import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/sync_service.dart';
import '../models/daily_meal_summary.dart';
import '../models/meal.dart';

/// Central meal repository with in-memory caching and request de-duplication.
class MealRepository extends ChangeNotifier {
  MealRepository._();

  static final MealRepository instance = MealRepository._();
  factory MealRepository() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get uid {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) throw StateError('User is signed out.');
    return currentUid;
  }

  List<Meal> _cachedMeals = <Meal>[];
  DateTime? _cachedDate;
  bool _loaded = false;
  DailyMealSummary _cachedSummary = DailyMealSummary.empty();

  // Prevent dashboard + meals/history screens from issuing the same read
  // simultaneously during startup.
  final Map<String, Future<List<Meal>>> _inFlightReads =
      <String, Future<List<Meal>>>{};

  List<Meal> get cachedMeals => List.unmodifiable(_cachedMeals);
  DailyMealSummary get cachedSummary => _cachedSummary;
  bool get loaded => _loaded;

  String dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime endOfDay(DateTime date) => DateTime(date.year, date.month, date.day + 1);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void clearCache() {
    _cachedMeals = <Meal>[];
    _cachedDate = null;
    _cachedSummary = DailyMealSummary.empty();
    _loaded = false;
    _inFlightReads.clear();
    notifyListeners();
  }

  void _calculateSummary() {
    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;
    double breakfast = 0;
    double lunch = 0;
    double dinner = 0;
    double snacks = 0;

    for (final meal in _cachedMeals) {
      calories += meal.calories;
      protein += meal.protein;
      carbs += meal.carbs;
      fat += meal.fat;

      switch (meal.mealType) {
        case 'Breakfast':
          breakfast += meal.calories;
          break;
        case 'Lunch':
          lunch += meal.calories;
          break;
        case 'Dinner':
          dinner += meal.calories;
          break;
        case 'Snacks':
          snacks += meal.calories;
          break;
      }
    }

    _cachedSummary = DailyMealSummary(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      breakfast: breakfast,
      lunch: lunch,
      dinner: dinner,
      snacks: snacks,
    );
  }

  Future<void> addMeal(Meal meal) async {
    final cachedDate = _cachedDate;

    if (cachedDate != null && _isSameDay(cachedDate, meal.createdAt)) {
      _cachedMeals.add(meal);
      _calculateSummary();
      notifyListeners();
    } else {
      // Do not insert a meal from another day into today's cached list.
      _loaded = false;
      _cachedDate = null;
      _cachedMeals = <Meal>[];
      _calculateSummary();
      notifyListeners();
    }

    SyncService.instance.addPendingItem(
      id: meal.id,
      title: meal.foodName,
      type: 'meal',
    );

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('meals')
          .doc(meal.id)
          .set(meal.toMap());

      SyncService.instance.removePendingItem(meal.id);
    } catch (e) {
      // SyncService can retry this item. The optimistic UI remains responsive.
      debugPrint('Background Firestore sync pending for meal ${meal.id}: $e');
    }
  }

  Future<List<Meal>> getMealsByDate(
    DateTime date, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _loaded &&
        _cachedDate != null &&
        _isSameDay(_cachedDate!, date)) {
      return _cachedMeals;
    }

    final dateKey = dateToString(date);

    if (!forceRefresh) {
      final existingRequest = _inFlightReads[dateKey];
      if (existingRequest != null) return existingRequest;
    }

    final future = _fetchMealsByDate(date);
    _inFlightReads[dateKey] = future;

    try {
      return await future;
    } finally {
      if (identical(_inFlightReads[dateKey], future)) {
        _inFlightReads.remove(dateKey);
      }
    }
  }

  Future<List<Meal>> _fetchMealsByDate(DateTime date) async {
    final start = startOfDay(date);
    final end = endOfDay(date);

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('meals')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(
          'createdAt',
          isLessThan: Timestamp.fromDate(end),
        )
        .orderBy('createdAt')
        .get();

    final meals = snapshot.docs
        .map((doc) => Meal.fromMap(doc.data()))
        .toList(growable: true);

    _cachedMeals = meals;
    _cachedDate = DateTime(date.year, date.month, date.day);
    _loaded = true;
    _calculateSummary();
    notifyListeners();

    return _cachedMeals;
  }

  Future<List<Meal>> getTodaysMeals({bool forceRefresh = false}) {
    return getMealsByDate(DateTime.now(), forceRefresh: forceRefresh);
  }

  Future<DailyMealSummary> getDailySummary(DateTime date) async {
    await getMealsByDate(date);
    return _cachedSummary;
  }

  Future<List<Meal>> getMealsForLastDays(int days) async {
    if (days <= 0) return <Meal>[];

    final now = DateTime.now();
    final start = startOfDay(now).subtract(Duration(days: days - 1));
    final end = endOfDay(now);

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('meals')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(
          'createdAt',
          isLessThan: Timestamp.fromDate(end),
        )
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Meal.fromMap(doc.data()))
        .toList();
  }

  Future<void> deleteMeal(String mealId) async {
    final index = _cachedMeals.indexWhere((meal) => meal.id == mealId);
    if (index == -1) return;

    final removedMeal = _cachedMeals[index];
    _cachedMeals.removeAt(index);
    _calculateSummary();
    notifyListeners();

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('meals')
          .doc(mealId)
          .delete();
    } catch (e) {
      _cachedMeals.insert(index, removedMeal);
      _calculateSummary();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateMeal(Meal meal) async {
    final index = _cachedMeals.indexWhere((item) => item.id == meal.id);
    if (index == -1) return;

    final oldMeal = _cachedMeals[index];
    _cachedMeals[index] = meal;
    _calculateSummary();
    notifyListeners();

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('meals')
          .doc(meal.id)
          .update(meal.toMap());
    } catch (e) {
      _cachedMeals[index] = oldMeal;
      _calculateSummary();
      notifyListeners();
      rethrow;
    }
  }
}
