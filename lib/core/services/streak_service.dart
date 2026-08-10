import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/streak_summary.dart';
import '../../features/meals/data/meal_repository.dart';
import '../../features/water/data/water_repository.dart';

/// Calculates engagement streaks using the existing batched meal and water
/// range queries. No Gemini calls or additional Firestore collections are
/// required.
class StreakService extends ChangeNotifier {
  StreakService._();

  static final StreakService instance = StreakService._();
  factory StreakService() => instance;

  static const String _longestStreakKey = 'calorix_longest_streak_v1';

  final MealRepository _mealRepository = MealRepository.instance;
  final WaterRepository _waterRepository = WaterRepository();

  StreakSummary _summary = const StreakSummary.empty();
  List<Achievement> _achievements = const [];
  Future<void>? _inFlight;

  StreakSummary get summary => _summary;
  List<Achievement> get achievements => List.unmodifiable(_achievements);

  Future<void> refresh({int days = 30}) {
    if (_inFlight != null) return _inFlight!;
    _inFlight = _refresh(days: days).whenComplete(() => _inFlight = null);
    return _inFlight!;
  }

  Future<void> _refresh({required int days}) async {
    if (days < 1) return;

    try {
      final results = await Future.wait<dynamic>([
        _mealRepository.getMealsForLastDays(days),
        _waterRepository.getWaterForLastDays(days),
      ]);

      final meals = results[0] as List;
      final water = results[1] as Map<String, int>;

      final activeDays = <String>{};
      for (final meal in meals) {
        activeDays.add(_dateKey(meal.createdAt as DateTime));
      }
      for (final entry in water.entries) {
        if (entry.value > 0) activeDays.add(entry.key);
      }

      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: days - 1));

      var longest = 0;
      var running = 0;
      for (var i = 0; i < days; i++) {
        final day = firstDay.add(Duration(days: i));
        if (activeDays.contains(_dateKey(day))) {
          running++;
          if (running > longest) longest = running;
        } else {
          running = 0;
        }
      }

      var current = 0;
      DateTime? lastActive;
      final todayKey = _dateKey(now);
      final todayIsActive = activeDays.contains(todayKey);
      final startIndex = todayIsActive ? days - 1 : days - 2;

      for (var i = startIndex; i >= 0; i--) {
        final day = firstDay.add(Duration(days: i));
        if (!activeDays.contains(_dateKey(day))) break;
        current++;
        lastActive = day;
      }

      final prefs = await SharedPreferences.getInstance();
      final savedLongest = prefs.getInt(_longestStreakKey) ?? 0;
      final newLongest = longest > savedLongest ? longest : savedLongest;
      if (newLongest != savedLongest) {
        await prefs.setInt(_longestStreakKey, newLongest);
      }

      _summary = StreakSummary(
        currentStreak: current,
        longestStreak: newLongest,
        activeDays: activeDays.length,
        lastActiveDate: lastActive,
      );

      final hydratedDays = water.values.where((value) => value > 0).length;
      _achievements = _buildAchievements(
        longestStreak: newLongest,
        totalMeals: meals.length,
        hydratedDays: hydratedDays,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('[StreakService] refresh failed: $e');
    }
  }

  List<Achievement> _buildAchievements({
    required int longestStreak,
    required int totalMeals,
    required int hydratedDays,
  }) {
    return [
      _achievement(
        id: 'streak_3',
        title: '3-Day Streak',
        description: 'Stay active for three consecutive days.',
        type: AchievementType.streak,
        target: 3,
        progress: longestStreak,
      ),
      _achievement(
        id: 'streak_7',
        title: '7-Day Streak',
        description: 'Stay active for a full week.',
        type: AchievementType.streak,
        target: 7,
        progress: longestStreak,
      ),
      _achievement(
        id: 'streak_30',
        title: '30-Day Streak',
        description: 'Build a consistent 30-day healthy routine.',
        type: AchievementType.streak,
        target: 30,
        progress: longestStreak,
      ),
      _achievement(
        id: 'meals_10',
        title: '10 Meals Tracked',
        description: 'Track your first ten meals.',
        type: AchievementType.meals,
        target: 10,
        progress: totalMeals,
      ),
      _achievement(
        id: 'meals_50',
        title: '50 Meals Tracked',
        description: 'Track fifty meals and build the habit.',
        type: AchievementType.meals,
        target: 50,
        progress: totalMeals,
      ),
      _achievement(
        id: 'hydration_7',
        title: 'Hydration Week',
        description: 'Log water on seven different days.',
        type: AchievementType.hydration,
        target: 7,
        progress: hydratedDays,
      ),
    ];
  }

  Achievement _achievement({
    required String id,
    required String title,
    required String description,
    required AchievementType type,
    required int target,
    required int progress,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      type: type,
      target: target,
      progress: progress,
      unlocked: progress >= target,
    );
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void clear() {
    _summary = const StreakSummary.empty();
    _achievements = const [];
    notifyListeners();
  }
}
