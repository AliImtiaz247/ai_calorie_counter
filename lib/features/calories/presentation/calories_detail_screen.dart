import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/language_service.dart';
import '../../../core/utils/health_calculator.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/info_card.dart';
import '../../profile/data/profile_repository.dart';
import '../../meals/data/meal_repository.dart';
import '../../meals/models/meal.dart';

class CaloriesDetailScreen extends StatefulWidget {
  final UserProfile? userProfile;
  final int dailyGoal;

  const CaloriesDetailScreen({
    super.key,
    this.userProfile,
    this.dailyGoal = 2000,
  });

  @override
  State<CaloriesDetailScreen> createState() => _CaloriesDetailScreenState();
}

class _CaloriesDetailScreenState extends State<CaloriesDetailScreen> {
  final MealRepository _mealRepository = MealRepository.instance;
  late DateTime _selectedDate;
  List<DateTime> _pastDays = [];
  Map<String, double> _dailyCalorieMap = {};
  List<Meal> _selectedDayMeals = [];
  bool _isLoading = true;

  final ProfileRepository _profileRepository = ProfileRepository();

  @override
  void initState() {
    super.initState();
    _mealRepository.addListener(_onMealRepoChanged);
    _selectedDate = DateTime.now();
    _generatePastDays();
    _loadHistoricalData();
  }

  @override
  void dispose() {
    _mealRepository.removeListener(_onMealRepoChanged);
    super.dispose();
  }

  void _onMealRepoChanged() {
    _loadHistoricalData();
  }

  void _generatePastDays() {
    final now = DateTime.now();
    _pastDays = List.generate(7, (i) {
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
    });
  }

  Future<void> _loadHistoricalData({bool forceShowSpinner = false}) async {
    if (forceShowSpinner || _dailyCalorieMap.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final allMeals = await _mealRepository.getMealsForLastDays(7);
      final map = <String, double>{};

      for (final day in _pastDays) {
        final key = _dateKey(day);
        map[key] = 0.0;
      }

      for (final meal in allMeals) {
        final key = _dateKey(meal.createdAt);
        if (map.containsKey(key)) {
          map[key] = (map[key] ?? 0) + meal.calories;
        }
      }

      final selectedMeals = await _mealRepository.getMealsByDate(_selectedDate);

      if (!mounted) return;
      setState(() {
        _dailyCalorieMap = map;
        _selectedDayMeals = selectedMeals;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _dateKey(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  Future<void> _onDateSelected(DateTime date) async {
    setState(() {
      _selectedDate = date;
    });

    final meals = await _mealRepository.getMealsByDate(date);
    if (!mounted) return;
    setState(() {
      _selectedDayMeals = meals;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, _, child) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF22C55E);

    final selectedKey = _dateKey(_selectedDate);
    final totalConsumed = _dailyCalorieMap[selectedKey] ?? 0.0;

    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    for (final m in _selectedDayMeals) {
      totalProtein += m.protein;
      totalCarbs += m.carbs;
      totalFat += m.fat;
    }

    return StreamBuilder<UserProfile?>(
      stream: _profileRepository.profileStream(),
      builder: (context, profileSnapshot) {
        final activeProfile = profileSnapshot.data ?? widget.userProfile;

        int goal = widget.dailyGoal > 0 ? widget.dailyGoal : 2000;
        if (activeProfile != null) {
          final bmr = HealthCalculator.calculateBMR(
            age: activeProfile.age > 0 ? activeProfile.age : 25,
            height: activeProfile.height > 0 ? activeProfile.height : 175.0,
            weight: activeProfile.currentWeight > 0
                ? activeProfile.currentWeight
                : 70.0,
            gender: activeProfile.gender,
          );
          goal = HealthCalculator.calculateDailyCalories(
            bmr: bmr,
            activity: activeProfile.activityLevel,
            goal: activeProfile.goal,
          );
        }

        final remaining = (goal - totalConsumed).clamp(0, goal).toDouble();
        final progress = (totalConsumed / goal).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LanguageService.tr("Calories Tracker"),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: LanguageService.tr("Pick Any Date"),
            onPressed: _selectCustomDate,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistoricalData,
              child: ResponsiveContentConstrained(
                maxWidth: Responsive.maxDashboardWidth(context),
                enableScroll: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Header & Custom Picker Action
                    _buildDateHeader(isDark, primaryColor),
                    const SizedBox(height: 12),

                    // Date Strip Selector
                    _buildDateStripSelector(isDark, primaryColor),
                    const SizedBox(height: 20),

                    // Overview Card
                    _buildOverviewCard(
                      totalConsumed: totalConsumed,
                      goal: goal,
                      remaining: remaining,
                      progress: progress,
                      protein: totalProtein,
                      carbs: totalCarbs,
                      fat: totalFat,
                      isDark: isDark,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 24),

                    // Daily Calories Challenge Section
                    _buildDailyCaloriesChallengeSection(
                      totalConsumed: totalConsumed,
                      goal: goal,
                      mealsCount: _selectedDayMeals.length,
                      isDark: isDark,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(height: 24),

                    // Graph Section
                    _buildCalorieChartSection(isDark, primaryColor, goal),
                    const SizedBox(height: 24),

                    // Daily Meals Breakdown Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${LanguageService.tr('Meals Logged')} (${DateFormat('MMM d').format(_selectedDate)})",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${_selectedDayMeals.length} ${LanguageService.tr('items')}",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Meals Log List
                    if (_selectedDayMeals.isEmpty)
                      _buildEmptyMealsState(isDark)
                    else
                      _buildMealsList(_selectedDayMeals, isDark, primaryColor),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
        );
      },
    );
  }

  Widget _buildDateStripSelector(bool isDark, Color primaryColor) {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pastDays.length,
        itemBuilder: (context, index) {
          final date = _pastDays[index];
          final isSelected =
              date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;

          final isToday =
              date.year == DateTime.now().year &&
              date.month == DateTime.now().month &&
              date.day == DateTime.now().day;

          return GestureDetector(
            onTap: () => _onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : (isDark ? Colors.white12 : Colors.black12),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isToday ? LanguageService.tr("Today") : DateFormat('EEE').format(date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d').format(date),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard({
    required double totalConsumed,
    required int goal,
    required double remaining,
    required double progress,
    required double protein,
    required double carbs,
    required double fat,
    required bool isDark,
    required Color primaryColor,
  }) {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LanguageService.tr("Calorie Summary"),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "${totalConsumed.toStringAsFixed(0)} ",
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        "/ $goal kcal",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      "${remaining.toStringAsFixed(0)} kcal",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      LanguageService.tr("Remaining"),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor:
                  isDark ? Colors.white12 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _macroBadge(LanguageService.tr("Protein"), "${protein.toStringAsFixed(0)}g",
                  Icons.fitness_center, Colors.amber),
              _macroBadge(LanguageService.tr("Carbs"), "${carbs.toStringAsFixed(0)}g",
                  Icons.rice_bowl, Colors.cyan),
              _macroBadge(LanguageService.tr("Fat"), "${fat.toStringAsFixed(0)}g",
                  Icons.opacity, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroBadge(
      String label, String value, IconData icon, Color accentColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: accentColor),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalorieChartSection(
      bool isDark, Color primaryColor, int goal) {
    final values = _pastDays.map((d) {
      final k = _dateKey(d);
      return _dailyCalorieMap[k] ?? 0.0;
    }).toList();

    double maxY = goal.toDouble() * 1.2;
    for (final v in values) {
      if (v > maxY) maxY = v * 1.15;
    }

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LanguageService.tr("Weekly Calorie Intake"),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${LanguageService.tr('Goal')}: $goal kcal",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        isDark ? const Color(0xFF1E293B) : Colors.black87,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = _pastDays[group.x.toInt()];
                      final dayStr = DateFormat('EEE, MMM d').format(day);
                      return BarTooltipItem(
                        "$dayStr\n",
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: "${rod.toY.round()} kcal",
                            style: const TextStyle(
                              color: Color(0xFF22C55E),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _pastDays.length) {
                          final date = _pastDays[index];
                          final isSelected =
                              date.year == _selectedDate.year &&
                              date.month == _selectedDate.month &&
                              date.day == _selectedDate.day;

                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('E').format(date),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? primaryColor
                                    : (isDark
                                        ? Colors.white60
                                        : Colors.grey.shade600),
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: goal / 2,
                  getDrawingHorizontalLine: (val) {
                    return FlLine(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(_pastDays.length, (i) {
                  final val = values[i];
                  final isSelected =
                      _pastDays[i].year == _selectedDate.year &&
                      _pastDays[i].month == _selectedDate.month &&
                      _pastDays[i].day == _selectedDate.day;

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        color: isSelected
                            ? primaryColor
                            : primaryColor.withValues(alpha: 0.4),
                        width: 18,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMealsState(bool isDark) {
    return InfoCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.no_food_outlined,
                size: 48,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                "${LanguageService.tr('No meals logged for')} ${DateFormat('EEEE, MMM d').format(_selectedDate)}",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealsList(
      List<Meal> meals, bool isDark, Color primaryColor) {
    return Column(
      children: meals.map((meal) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _mealIcon(meal.mealType),
                  color: primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.foodName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${meal.mealType} • P: ${meal.protein.toStringAsFixed(0)}g C: ${meal.carbs.toStringAsFixed(0)}g F: ${meal.fat.toStringAsFixed(0)}g",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                "${meal.calories.round()} kcal",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _mealIcon(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast_rounded;
      case 'lunch':
        return Icons.lunch_dining_rounded;
      case 'dinner':
        return Icons.dinner_dining_rounded;
      default:
        return Icons.apple_rounded;
    }
  }

  Widget _buildDailyCaloriesChallengeSection({
    required double totalConsumed,
    required int goal,
    required int mealsCount,
    required bool isDark,
    required Color primaryColor,
  }) {
    final isTargetMet =
        totalConsumed >= (goal * 0.8) && totalConsumed <= (goal * 1.1);
    final isOverGoal = totalConsumed > (goal * 1.1);

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (totalConsumed == 0) {
      statusText = "Log your meals to complete today's challenge!";
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.flag_rounded;
    } else if (isTargetMet) {
      statusText =
          "Great job! You are within your daily calorie target window! 🔥";
      statusColor = primaryColor;
      statusIcon = Icons.stars_rounded;
    } else if (isOverGoal) {
      statusText =
          "Over calorie goal by ${(totalConsumed - goal).round()} kcal.";
      statusColor = Colors.redAccent;
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusText =
          "Keep going! ${(goal - totalConsumed).round()} kcal needed to reach target.";
      statusColor = Colors.cyan;
      statusIcon = Icons.bolt_rounded;
    }

    final quest1Complete = isTargetMet;
    final quest2Complete = mealsCount >= 3;

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    LanguageService.tr("Daily Calorie Challenge"),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "🔥 5 Day Streak",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF22C55E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Status Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quests Checklist
          Text(
            LanguageService.tr("Today's Quests"),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),

          _buildQuestItem(
            title: LanguageService.tr("Hit Calorie Target"),
            subtitle: LanguageService.tr("Stay within 80% - 110% of daily goal"),
            isDone: quest1Complete,
            xp: "+100 XP",
            isDark: isDark,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 8),

          _buildQuestItem(
            title: LanguageService.tr("Log 3+ Meals"),
            subtitle: LanguageService.tr("Track Breakfast, Lunch & Dinner"),
            isDone: quest2Complete,
            xp: "+50 XP",
            isDark: isDark,
            primaryColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestItem({
    required String title,
    required String subtitle,
    required bool isDone,
    required String xp,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? primaryColor.withValues(alpha: 0.4)
              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDone
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isDone ? primaryColor : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDone
                  ? primaryColor.withValues(alpha: 0.15)
                  : Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              xp,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDone ? primaryColor : Colors.amber.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(bool isDark, Color primaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        InkWell(
          onTap: _selectCustomDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit_calendar_rounded,
                  size: 16,
                  color: primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  LanguageService.tr("Select Date"),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF22C55E),
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final alreadyInList = _pastDays.any(
        (d) =>
            d.year == picked.year &&
            d.month == picked.month &&
            d.day == picked.day,
      );

      if (!alreadyInList) {
        _pastDays = List.generate(7, (i) {
          return DateTime(picked.year, picked.month, picked.day)
              .subtract(Duration(days: 6 - i));
        });
      }

      await _onDateSelected(picked);
      await _loadHistoricalData();
    }
  }
}
