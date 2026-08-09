import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/sync_service.dart';
import '../models/daily_meal_summary.dart';
import '../models/meal.dart';

class MealRepository extends ChangeNotifier {
  MealRepository._();

  static final MealRepository instance = MealRepository._();
  factory MealRepository() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String uid = FirebaseAuth.instance.currentUser!.uid;

  // ===========================================================
  // CACHE
  // ===========================================================

  List<Meal> _cachedMeals = [];

  DateTime? _cachedDate;

  bool _loaded = false;

  DailyMealSummary _cachedSummary = DailyMealSummary.empty();

  // ===========================================================
  // GETTERS
  // ===========================================================

  List<Meal> get cachedMeals => List.unmodifiable(_cachedMeals);

  DailyMealSummary get cachedSummary => _cachedSummary;

  bool get loaded => _loaded;

  // ===========================================================
  // HELPERS
  // ===========================================================

  String dateToString(DateTime date) {
    return "${date.year}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day + 1);
  }

  void clearCache() {
    _cachedMeals.clear();
    _cachedDate = null;
    _cachedSummary = DailyMealSummary.empty();
    _loaded = false;
  }

  // ===========================================================
  // SUMMARY CALCULATOR
  // ===========================================================

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
        case "Breakfast":
          breakfast += meal.calories;
          break;

        case "Lunch":
          lunch += meal.calories;
          break;

        case "Dinner":
          dinner += meal.calories;
          break;

        case "Snacks":
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
    // ===========================================================
  // ADD MEAL (Optimistic Update)
  // ===========================================================

  Future<void> addMeal(Meal meal) async {
    final mealDate = meal.createdAt;
    final isSameDateAsCached = _cachedDate != null &&
        _cachedDate!.year == mealDate.year &&
        _cachedDate!.month == mealDate.month &&
        _cachedDate!.day == mealDate.day;

    if (isSameDateAsCached) {
      _cachedMeals.add(meal);
    } else {
      _loaded = false;
      _cachedDate = null;
      _cachedMeals.clear();
    }

    _calculateSummary();
    notifyListeners();

    SyncService.instance.addPendingItem(
      id: meal.id,
      title: meal.foodName,
      type: 'meal',
    );

    try {
      await _firestore
          .collection("users")
          .doc(uid)
          .collection("meals")
          .doc(meal.id)
          .set(meal.toMap());

      SyncService.instance.removePendingItem(meal.id);
    } catch (e) {
      debugPrint("Background Firestore sync pending for meal ${meal.id}");
    }
  }

  // ===========================================================
  // LOAD MEALS BY DATE
  // ===========================================================

  Future<List<Meal>> getMealsByDate(DateTime date, {bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _loaded &&
        _cachedDate != null &&
        _cachedDate!.year == date.year &&
        _cachedDate!.month == date.month &&
        _cachedDate!.day == date.day) {
      return _cachedMeals;
    }

    final start = startOfDay(date);
    final end = endOfDay(date);

    final snapshot = await _firestore
        .collection("users")
        .doc(uid)
        .collection("meals")
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(
          "createdAt",
          isLessThan: Timestamp.fromDate(end),
        )
        .orderBy("createdAt")
        .get();

    _cachedMeals = snapshot.docs
        .map((doc) => Meal.fromMap(doc.data()))
        .toList();

    _cachedDate = DateTime(
      date.year,
      date.month,
      date.day,
    );

    _loaded = true;

    _calculateSummary();

    notifyListeners();

    return _cachedMeals;
  }

  // ===========================================================
  // TODAY'S MEALS
  // ===========================================================

  Future<List<Meal>> getTodaysMeals({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (forceRefresh ||
        _cachedDate == null ||
        _cachedDate!.year != now.year ||
        _cachedDate!.month != now.month ||
        _cachedDate!.day != now.day) {
      _loaded = false;
    }
    return await getMealsByDate(now, forceRefresh: forceRefresh);
  }

  // ===========================================================
  // DAILY SUMMARY
  // ===========================================================

  Future<DailyMealSummary> getDailySummary(
    DateTime date,
  ) async {
    await getMealsByDate(date);

    return _cachedSummary;
  }

  // ===========================================================
  // LAST X DAYS
  // ===========================================================

  Future<List<Meal>> getMealsForLastDays(int days) async {
    final now = DateTime.now();

    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));

    final end = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection("users")
        .doc(uid)
        .collection("meals")
        .where(
          "createdAt",
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(
          "createdAt",
          isLessThan: Timestamp.fromDate(end),
        )
        .orderBy("createdAt", descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Meal.fromMap(doc.data()))
        .toList();
  }
    // ===========================================================
  // DELETE MEAL (Optimistic Update)
  // ===========================================================

  Future<void> deleteMeal(String mealId) async {
    final index = _cachedMeals.indexWhere((m) => m.id == mealId);

    if (index == -1) return;

    final removedMeal = _cachedMeals[index];

    // Remove instantly from UI
    _cachedMeals.removeAt(index);

    _calculateSummary();

    notifyListeners();

    try {
      await _firestore
          .collection("users")
          .doc(uid)
          .collection("meals")
          .doc(mealId)
          .delete();
    } catch (e) {
      // Rollback if Firestore fails
      _cachedMeals.insert(index, removedMeal);

      _calculateSummary();

      notifyListeners();

      rethrow;
    }
  }

  // ===========================================================
  // UPDATE MEAL (Optimistic Update)
  // ===========================================================

  Future<void> updateMeal(Meal meal) async {
    final index = _cachedMeals.indexWhere((m) => m.id == meal.id);

    if (index == -1) return;

    final oldMeal = _cachedMeals[index];

    // Update instantly
    _cachedMeals[index] = meal;

    _calculateSummary();

    notifyListeners();

    try {
      await _firestore
          .collection("users")
          .doc(uid)
          .collection("meals")
          .doc(meal.id)
          .update(meal.toMap());
    } catch (e) {
      // Rollback
      _cachedMeals[index] = oldMeal;

      _calculateSummary();

      notifyListeners();

      rethrow;
    }
  }
}