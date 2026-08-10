import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/notifications/services/notification_local_storage.dart';
import 'notification_service.dart';

class GoalCompletionService {
  GoalCompletionService._();

  static final GoalCompletionService instance = GoalCompletionService._();
  factory GoalCompletionService() => instance;

  final NotificationLocalStorage _localStorage = NotificationLocalStorage.instance;
  final NotificationService _notificationService = NotificationService.instance;

  static const String _notifiedGoalKeysPref = 'calorix_notified_goal_keys_v1';
  final Set<String> _notifiedKeys = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKeys = prefs.getStringList(_notifiedGoalKeysPref) ?? [];
      _notifiedKeys.addAll(savedKeys);
      _initialized = true;
    } catch (e) {
      debugPrint("GoalCompletionService init error: $e");
    }
  }

  String _formatDateKey(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  Future<bool> _hasBeenNotified(String key) async {
    if (!_initialized) await init();
    if (_notifiedKeys.contains(key)) return true;

    // Check existing notifications list
    final existingList = await _localStorage.getNotifications();
    if (existingList.any((n) => n.id == key)) {
      _notifiedKeys.add(key);
      return true;
    }
    return false;
  }

  Future<void> _markAsNotified(String key) async {
    if (!_initialized) await init();
    _notifiedKeys.add(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_notifiedGoalKeysPref, _notifiedKeys.toList());
    } catch (e) {
      debugPrint("GoalCompletionService error saving notified key: $e");
    }
  }

  /// Check Step Goal Completion
  Future<void> checkStepGoal({
    required int steps,
    required int goal,
    DateTime? date,
  }) async {
    if (goal <= 0 || steps < goal) return;

    final prefs = await SharedPreferences.getInstance();
    final goalAlertsEnabled = prefs.getBool('settings_goal_alert') ?? true;
    final stepNotifEnabled = prefs.getBool('settings_step_goal_notif') ?? true;
    if (!goalAlertsEnabled || !stepNotifEnabled) return;

    final dateStr = _formatDateKey(date ?? DateTime.now());
    final key = 'goal_step_${dateStr}_$goal';

    if (await _hasBeenNotified(key)) return;

    await _markAsNotified(key);

    final formattedGoal = NumberFormat('#,##0').format(goal);
    final formattedSteps = NumberFormat('#,##0').format(steps);

    debugPrint("[GoalCompletionService] 🎉 Step Goal Complete: $steps / $goal");

    await _notificationService.notifyGoalReached(
      id: key,
      type: 'goal',
      title: '🎉 Goal Complete!',
      message: 'You\'ve reached your $formattedGoal step goal today ($formattedSteps steps). Amazing work!',
      category: 'steps',
      goalType: 'step',
      goalTarget: goal,
      goalProgress: steps,
    );
  }

  /// Check Calorie Goal Completion
  Future<void> checkCalorieGoal({
    required double consumedCalories,
    required double calorieGoal,
    DateTime? date,
  }) async {
    if (calorieGoal <= 0 || consumedCalories < calorieGoal) return;

    final prefs = await SharedPreferences.getInstance();
    final goalAlertsEnabled = prefs.getBool('settings_goal_alert') ?? true;
    final calorieNotifEnabled = prefs.getBool('settings_calorie_goal_notif') ?? true;
    if (!goalAlertsEnabled || !calorieNotifEnabled) return;

    final dateStr = _formatDateKey(date ?? DateTime.now());
    final roundedGoal = calorieGoal.round();
    final roundedConsumed = consumedCalories.round();
    final key = 'goal_calorie_${dateStr}_$roundedGoal';

    if (await _hasBeenNotified(key)) return;

    await _markAsNotified(key);

    final formattedGoal = NumberFormat('#,##0').format(roundedGoal);
    final formattedConsumed = NumberFormat('#,##0').format(roundedConsumed);

    debugPrint("[GoalCompletionService] 🔥 Calorie Goal Complete: $consumedCalories / $calorieGoal");

    await _notificationService.notifyGoalReached(
      id: key,
      type: 'goal',
      title: '🔥 Calorie Goal Complete!',
      message: 'You\'ve reached your $formattedGoal kcal goal today ($formattedConsumed kcal).',
      category: 'calories',
      goalType: 'calorie',
      goalTarget: roundedGoal,
      goalProgress: roundedConsumed,
    );
  }

  /// Check Water Goal Completion
  Future<void> checkWaterGoal({
    required int consumedWater,
    required int waterGoal,
    DateTime? date,
  }) async {
    if (waterGoal <= 0 || consumedWater < waterGoal) return;

    final prefs = await SharedPreferences.getInstance();
    final goalAlertsEnabled = prefs.getBool('settings_goal_alert') ?? true;
    final waterNotifEnabled = prefs.getBool('settings_water_goal_notif') ?? true;
    if (!goalAlertsEnabled || !waterNotifEnabled) return;

    final dateStr = _formatDateKey(date ?? DateTime.now());
    final key = 'goal_water_${dateStr}_$waterGoal';

    if (await _hasBeenNotified(key)) return;

    await _markAsNotified(key);

    final formattedGoal = NumberFormat('#,##0').format(waterGoal);
    final formattedConsumed = NumberFormat('#,##0').format(consumedWater);

    debugPrint("[GoalCompletionService] 💧 Water Goal Complete: $consumedWater / $waterGoal");

    await _notificationService.notifyGoalReached(
      id: key,
      type: 'goal',
      title: '💧 Water Goal Complete!',
      message: 'You\'ve reached your $formattedGoal mL water goal today ($formattedConsumed mL). Great hydration!',
      category: 'water',
      goalType: 'water',
      goalTarget: waterGoal,
      goalProgress: consumedWater,
    );
  }

  /// Check Weight Goal Completion
  Future<void> checkWeightGoal({
    required double currentWeight,
    required double targetWeight,
    String? userId,
  }) async {
    if (currentWeight <= 0 || targetWeight <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    final goalAlertsEnabled = prefs.getBool('settings_goal_alert') ?? true;
    if (!goalAlertsEnabled) return;

    // Check if current weight reached target weight (within 0.2kg margin)
    final diff = (currentWeight - targetWeight).abs();
    if (diff > 0.2 && currentWeight > targetWeight) return;

    final uid = userId ?? _notificationService.uid ?? 'local';
    final formattedTarget = targetWeight.toStringAsFixed(1);
    final key = 'goal_weight_${uid}_$formattedTarget';

    if (await _hasBeenNotified(key)) return;

    await _markAsNotified(key);

    debugPrint("[GoalCompletionService] ⚖️ Weight Goal Reached: $currentWeight -> $targetWeight");

    await _notificationService.notifyGoalReached(
      id: key,
      type: 'goal',
      title: '⚖️ Weight Goal Reached!',
      message: 'You\'ve reached your $formattedTarget kg target weight goal! Outstanding achievement!',
      category: 'weight',
      goalType: 'weight',
      goalTarget: targetWeight,
      goalProgress: currentWeight,
    );
  }

  /// Reset in-memory notified state on user logout
  void onLogout() {
    _notifiedKeys.clear();
    _initialized = false;
  }
}
