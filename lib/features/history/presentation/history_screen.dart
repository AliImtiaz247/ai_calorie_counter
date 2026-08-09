import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/language_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/info_card.dart';
import '../../meals/data/meal_repository.dart';
import '../../meals/models/meal.dart';
import '../../profile/data/profile_repository.dart';
import '../../steps/data/step_repository.dart';
import '../../steps/models/step_log.dart';
import '../../water/data/water_repository.dart';
import '../../weight/data/weight_repository.dart';
import '../../weight/models/weight_log.dart';

class HistoryScreen extends StatefulWidget {
  final int initialTabIndex;

  const HistoryScreen({super.key, this.initialTabIndex = 0});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

enum DateRangeOption { days7, days14, days30, custom }

enum ChartType { line, bar }

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final MealRepository _mealRepository = MealRepository.instance;
  final WeightRepository _weightRepository = WeightRepository();
  final WaterRepository _waterRepository = WaterRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  DateRangeOption _selectedRange = DateRangeOption.days7;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _endDate = DateTime.now();

  ChartType _chartType = ChartType.bar;
  bool _isLoading = true;

  // Data stores
  List<Meal> _mealsList = [];
  List<WeightLog> _weightLogs = [];
  Map<String, int> _waterMap = {}; // dateKey -> consumed mL
  Map<String, StepLog> _stepsMap = {}; // dateKey -> StepLog
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _updateDateRange(DateRangeOption.days7);
    _loadAllHistoryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateDateRange(DateRangeOption option) {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    setState(() {
      _selectedRange = option;
      if (option == DateRangeOption.days7) {
        _startDate = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 6));
        _endDate = todayEnd;
      } else if (option == DateRangeOption.days14) {
        _startDate = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 13));
        _endDate = todayEnd;
      } else if (option == DateRangeOption.days30) {
        _startDate = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 29));
        _endDate = todayEnd;
      }
    });
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
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
      setState(() {
        _selectedRange = DateRangeOption.custom;
        _startDate = DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        );
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
      await _loadAllHistoryData();
    }
  }

  Future<void> _loadAllHistoryData() async {
    if (_mealsList.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final daysCount = _endDate.difference(_startDate).inDays + 1;

      // 1. Fetch Profile
      final profile = await _profileRepository.getProfile();

      // 2. Fetch Meals
      final meals = await _mealRepository.getMealsForLastDays(max(daysCount, 1));
      final filteredMeals = meals.where((m) {
        return m.createdAt.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
            m.createdAt.isBefore(_endDate.add(const Duration(seconds: 1)));
      }).toList();

      // 3. Fetch Water
      final waterMap = await _waterRepository.getWaterForLastDays(max(daysCount, 1));

      // 4. Fetch Weight Logs Stream single event
      final weightStream = _weightRepository.getWeightLogsStream();
      final weightLogs = await weightStream.first;

      final filteredWeight = weightLogs.where((w) {
        return w.date.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
            w.date.isBefore(_endDate.add(const Duration(seconds: 1)));
      }).toList();

      // 5. Fetch Steps History
      final stepsList = await StepRepository.instance.getStepHistoryForLastDays(max(daysCount, 1));
      final stepsMap = <String, StepLog>{};
      for (final s in stepsList) {
        stepsMap[s.date] = s;
      }

      if (!mounted) return;
      setState(() {
        _userProfile = profile;
        _mealsList = filteredMeals;
        _waterMap = waterMap;
        _weightLogs = filteredWeight;
        _stepsMap = stepsMap;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _formatDateKey(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  List<DateTime> get _daysInRange {
    final list = <DateTime>[];
    var current = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final endClean = DateTime(_endDate.year, _endDate.month, _endDate.day);

    while (!current.isAfter(endClean)) {
      list.add(current);
      current = current.add(const Duration(days: 1));
    }
    return list;
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LanguageService.tr("User History & Analytics"),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelColor: primaryColor,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.grey.shade600,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.restaurant_rounded, size: 20),
              text: LanguageService.tr("Logged Meals"),
            ),
            Tab(
              icon: const Icon(Icons.monitor_weight_outlined, size: 20),
              text: LanguageService.tr("Weight Milestones"),
            ),
            Tab(
              icon: const Icon(Icons.directions_walk_rounded, size: 20),
              text: LanguageService.tr("Steps Tracker"),
            ),
            Tab(
              icon: const Icon(Icons.water_drop_rounded, size: 20),
              text: LanguageService.tr("Hydration History"),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAllHistoryData,
          child: ResponsiveContentConstrained(
            maxWidth: Responsive.maxDashboardWidth(context),
            enableScroll: false,
            child: Column(
              children: [
              // Top Controls Header: Range Selector & Chart Type Selector
              _buildTopControls(isDark, primaryColor),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMealsTab(isDark, primaryColor),
                          _buildWeightTab(isDark, primaryColor),
                          _buildStepsTab(isDark, primaryColor),
                          _buildHydrationTab(isDark, primaryColor),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildTopControls(bool isDark, Color primaryColor) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Date range pill selector
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _rangePill(
                        label: LanguageService.tr("7 Days"),
                        option: DateRangeOption.days7,
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      _rangePill(
                        label: LanguageService.tr("14 Days"),
                        option: DateRangeOption.days14,
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      _rangePill(
                        label: LanguageService.tr("30 Days"),
                        option: DateRangeOption.days30,
                        isDark: isDark,
                        primaryColor: primaryColor,
                      ),
                      const SizedBox(width: 8),
                      _customRangePill(isDark, primaryColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Chart Type Toggle
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.bar_chart_rounded, size: 20),
                      color: _chartType == ChartType.bar
                          ? primaryColor
                          : (isDark ? Colors.white60 : Colors.grey.shade600),
                      tooltip: LanguageService.tr("Bar Chart"),
                      onPressed: () => setState(() => _chartType = ChartType.bar),
                    ),
                    IconButton(
                      icon: const Icon(Icons.show_chart_rounded, size: 20),
                      color: _chartType == ChartType.line
                          ? primaryColor
                          : (isDark ? Colors.white60 : Colors.grey.shade600),
                      tooltip: LanguageService.tr("Line Chart"),
                      onPressed: () => setState(() => _chartType = ChartType.line),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rangePill({
    required String label,
    required DateRangeOption option,
    required bool isDark,
    required Color primaryColor,
  }) {
    final isSelected = _selectedRange == option;
    return GestureDetector(
      onTap: () {
        _updateDateRange(option);
        _loadAllHistoryData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? const Color(0xFF334155) : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.grey.shade800),
          ),
        ),
      ),
    );
  }

  Widget _customRangePill(bool isDark, Color primaryColor) {
    final isSelected = _selectedRange == DateRangeOption.custom;
    final label = isSelected
        ? "${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d').format(_endDate)}"
        : LanguageService.tr("Custom Range");

    return GestureDetector(
      onTap: _pickCustomDateRange,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? const Color(0xFF334155) : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.grey.shade800),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: MEALS HISTORY
  // ===========================================================================

  Widget _buildMealsTab(bool isDark, Color primaryColor) {
    final days = _daysInRange;
    final dailyCalorieMap = <String, double>{};
    double totalProtein = 0;

    for (final day in days) {
      dailyCalorieMap[_formatDateKey(day)] = 0.0;
    }

    for (final meal in _mealsList) {
      final key = _formatDateKey(meal.createdAt);
      dailyCalorieMap[key] = (dailyCalorieMap[key] ?? 0) + meal.calories;
      totalProtein += meal.protein;
    }

    final totalCalories = _mealsList.fold<double>(0, (sum, m) => sum + m.calories);
    final avgDailyCal = days.isNotEmpty ? totalCalories / days.length : 0.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Card
          InfoCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryItem(
                  title: LanguageService.tr("Total Meals"),
                  value: "${_mealsList.length}",
                  icon: Icons.restaurant,
                  color: Colors.orange,
                ),
                _summaryItem(
                  title: LanguageService.tr("Avg Cal/Day"),
                  value: "${avgDailyCal.round()}",
                  icon: Icons.local_fire_department,
                  color: Colors.redAccent,
                ),
                _summaryItem(
                  title: LanguageService.tr("Protein"),
                  value: "${totalProtein.round()}g",
                  icon: Icons.fitness_center,
                  color: Colors.lightBlueAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Meals Graph Card
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LanguageService.tr("Calorie Intake Trend"),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 200,
                  child: _chartType == ChartType.bar
                      ? _buildMealsBarChart(days, dailyCalorieMap, primaryColor, isDark)
                      : _buildMealsLineChart(days, dailyCalorieMap, primaryColor, isDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logged Meals List Section
          Text(
            LanguageService.tr("Logged Meals History"),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (_mealsList.isEmpty)
            InfoCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    LanguageService.tr("No meals logged for the selected date range."),
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            )
          else
            ..._mealsList.map((m) => _buildMealRow(m, isDark, primaryColor)),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMealsBarChart(
      List<DateTime> days, Map<String, double> map, Color primaryColor, bool isDark) {
    double maxY = 2000.0;
    for (final v in map.values) {
      if (v > maxY) maxY = v * 1.15;
    }

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : Colors.black87,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final date = days[group.x.toInt()];
              final dateStr = DateFormat('EEE, MMM d').format(date);
              return BarTooltipItem(
                "$dateStr\n${rod.toY.round()} kcal",
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < days.length) {
                  final dt = days[idx];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('M/d').format(dt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(days.length, (i) {
          final val = map[_formatDateKey(days[i])] ?? 0.0;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: val,
                color: primaryColor,
                width: max(8.0, 24.0 - (days.length * 0.4)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMealsLineChart(
      List<DateTime> days, Map<String, double> map, Color primaryColor, bool isDark) {
    double maxY = 2000.0;
    for (final v in map.values) {
      if (v > maxY) maxY = v * 1.15;
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < days.length; i++) {
      final val = map[_formatDateKey(days[i])] ?? 0.0;
      spots.add(FlSpot(i.toDouble(), val));
    }

    return LineChart(
      LineChartData(
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : Colors.black87,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = days[spot.x.toInt()];
                final dateStr = DateFormat('EEE, MMM d').format(date);
                return LineTooltipItem(
                  "$dateStr\n${spot.y.round()} kcal",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < days.length) {
                  final dt = days[idx];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('M/d').format(dt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: primaryColor,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: primaryColor.withValues(alpha: 0.15),
            ),
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildMealRow(Meal meal, bool isDark, Color primaryColor) {
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
              meal.mealType == "Breakfast"
                  ? Icons.free_breakfast_rounded
                  : meal.mealType == "Lunch"
                      ? Icons.lunch_dining_rounded
                      : meal.mealType == "Dinner"
                          ? Icons.dinner_dining_rounded
                          : Icons.fastfood_rounded,
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  "${DateFormat('MMM d, h:mm a').format(meal.createdAt)} • P:${meal.protein.round()}g C:${meal.carbs.round()}g F:${meal.fat.round()}g",
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: WEIGHT MILESTONES
  // ===========================================================================

  Widget _buildWeightTab(bool isDark, Color primaryColor) {
    final currentWeight = _userProfile?.currentWeight ??
        (_weightLogs.isNotEmpty ? _weightLogs.last.weight : 70.0);
    final targetWeight = _userProfile?.targetWeight ?? 65.0;
    final initialWeight =
        _weightLogs.isNotEmpty ? _weightLogs.first.weight : currentWeight;

    final isLoss = targetWeight < initialWeight;
    final totalDiffToGoal = (initialWeight - targetWeight).abs();
    final currentProgress = (initialWeight - currentWeight).abs();

    final pctProgress = totalDiffToGoal > 0
        ? (currentProgress / totalDiffToGoal).clamp(0.0, 1.0)
        : 1.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Milestone Summary Cards
          Row(
            children: [
              Expanded(
                child: InfoCard(
                  child: Column(
                    children: [
                      Text(
                        LanguageService.tr("Start Weight"),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${initialWeight.toStringAsFixed(1)} kg",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InfoCard(
                  child: Column(
                    children: [
                      Text(
                        LanguageService.tr("Current Weight"),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${currentWeight.toStringAsFixed(1)} kg",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InfoCard(
                  child: Column(
                    children: [
                      Text(
                        LanguageService.tr("Target Weight"),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${targetWeight.toStringAsFixed(1)} kg",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Milestone Progress Card
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      LanguageService.tr("Milestone Goal Progress"),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${(pctProgress * 100).toStringAsFixed(0)}%",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pctProgress,
                    minHeight: 12,
                    backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isLoss
                      ? "${(currentWeight - targetWeight).clamp(0, 999).toStringAsFixed(1)} ${LanguageService.tr('kg left to lose to reach your goal')}"
                      : "${(targetWeight - currentWeight).clamp(0, 999).toStringAsFixed(1)} ${LanguageService.tr('kg left to gain to reach your goal')}",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Weight Trend Graph
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LanguageService.tr("Weight Progression Graph"),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 220,
                  child: _weightLogs.length < 2
                      ? Center(
                          child: Text(
                            LanguageService.tr("Log at least 2 weight entries to view graph."),
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                        )
                      : _chartType == ChartType.bar
                          ? _buildWeightBarChart(_weightLogs, targetWeight, primaryColor, isDark)
                          : _buildWeightLineChart(_weightLogs, targetWeight, primaryColor, isDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Weight History Log List
          Text(
            LanguageService.tr("Weight Log History"),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (_weightLogs.isEmpty)
            InfoCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    LanguageService.tr("No weight entries logged yet."),
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            )
          else
            ..._weightLogs.map((w) => _buildWeightRow(w, isDark, primaryColor)),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildWeightBarChart(
      List<WeightLog> logs, double target, Color primaryColor, bool isDark) {
    double minY = target * 0.8;
    double maxY = target * 1.2;

    for (final l in logs) {
      if (l.weight < minY) minY = l.weight * 0.9;
      if (l.weight > maxY) maxY = l.weight * 1.1;
    }

    return BarChart(
      BarChartData(
        minY: minY,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : Colors.black87,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final log = logs[group.x.toInt()];
              final dateStr = DateFormat('EEE, MMM d').format(log.date);
              return BarTooltipItem(
                "$dateStr\n${log.weight.toStringAsFixed(1)} kg",
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (val, meta) => Text(
                "${val.round()}kg",
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < logs.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('M/d').format(logs[idx].date),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(logs.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: logs[i].weight,
                color: primaryColor,
                width: max(8.0, 24.0 - (logs.length * 0.4)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildWeightLineChart(
      List<WeightLog> logs, double target, Color primaryColor, bool isDark) {
    double minY = target * 0.8;
    double maxY = target * 1.2;

    for (final l in logs) {
      if (l.weight < minY) minY = l.weight * 0.9;
      if (l.weight > maxY) maxY = l.weight * 1.1;
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < logs.length; i++) {
      spots.add(FlSpot(i.toDouble(), logs[i].weight));
    }

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : Colors.black87,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final log = logs[spot.x.toInt()];
                final dateStr = DateFormat('EEE, MMM d').format(log.date);
                return LineTooltipItem(
                  "$dateStr\n${log.weight.toStringAsFixed(1)} kg",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (val, meta) => Text(
                "${val.round()}kg",
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < logs.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('M/d').format(logs[idx].date),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: target,
              color: Colors.amber.shade700,
              strokeWidth: 2,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade700,
                ),
                labelResolver: (line) =>
                    "${LanguageService.tr('Goal')}: ${target.toStringAsFixed(1)}kg",
              ),
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: primaryColor,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: primaryColor.withValues(alpha: 0.15),
            ),
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightRow(WeightLog log, bool isDark, Color primaryColor) {
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_weight_outlined, color: primaryColor, size: 22),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(log.date),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  if (log.note != null && log.note!.isNotEmpty)
                    Text(
                      log.note!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Text(
            "${log.weight.toStringAsFixed(1)} kg",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: STEPS TRACKER HISTORY
  // ===========================================================================

  Widget _buildStepsTab(bool isDark, Color primaryColor) {
    final days = _daysInRange;
    int totalSteps = 0;
    int daysGoalMet = 0;
    double totalKm = 0.0;
    int totalKcal = 0;
    const dailyGoal = 10000;

    for (final day in days) {
      final key = _formatDateKey(day);
      final StepLog? log = _stepsMap[key];
      final int s = log?.steps ?? 0;
      totalSteps += s;
      totalKm += log?.distanceKm ?? (s * 0.75 / 1000.0);
      totalKcal += log?.caloriesBurned ?? (s * 0.04).round();
      if (s >= dailyGoal) daysGoalMet++;
    }

    final avgSteps = days.isNotEmpty ? (totalSteps / days.length).round() : 0;
    final pctProgress = days.isNotEmpty ? (daysGoalMet / days.length).clamp(0.0, 1.0) : 0.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Steps Summary Cards Grid
          Row(
            children: [
              Expanded(
                child: InfoCard(
                  child: Column(
                    children: [
                      Text(
                        LanguageService.tr("Avg Steps"),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$avgSteps",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InfoCard(
                  child: Column(
                    children: [
                      Text(
                        LanguageService.tr("Distance"),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${totalKm.toStringAsFixed(1)} km",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InfoCard(
                  child: Column(
                    children: [
                      Text(
                        LanguageService.tr("Burned"),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$totalKcal kcal",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InfoCard(
                  child: Column(
                    children: [
                      Text(
                        LanguageService.tr("Goal Met"),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$daysGoalMet / ${days.length}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Goal Attainment Progress Bar
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      LanguageService.tr("Goal Attainment Rate"),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${(pctProgress * 100).toStringAsFixed(0)}%",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF59E0B),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pctProgress,
                    minHeight: 12,
                    backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Step Activity Graph Card
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LanguageService.tr("Step Activity Graph"),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 200,
                  child: _chartType == ChartType.bar
                      ? _buildStepsBarChart(days, _stepsMap, dailyGoal, isDark)
                      : _buildStepsLineChart(days, _stepsMap, dailyGoal, isDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Daily Step Logs History List Section
          Text(
            LanguageService.tr("Step Log History"),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ...days.reversed.map((day) {
            final key = _formatDateKey(day);
            final log = _stepsMap[key];
            return _buildStepHistoryRow(day, log, dailyGoal, isDark);
          }),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStepsBarChart(
      List<DateTime> days, Map<String, StepLog> map, int goal, bool isDark) {
    double maxY = goal * 1.2;
    for (final day in days) {
      final key = _formatDateKey(day);
      final s = map[key]?.steps ?? 0;
      if (s > maxY) maxY = s * 1.15;
    }

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : Colors.black87,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final date = days[group.x.toInt()];
              final dateStr = DateFormat('EEE, MMM d').format(date);
              return BarTooltipItem(
                "$dateStr\n${rod.toY.toInt()} steps",
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('M/d').format(days[idx]),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(days.length, (i) {
          final key = _formatDateKey(days[i]);
          final val = (map[key]?.steps ?? 0).toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: val,
                color: const Color(0xFFF59E0B),
                width: max(8.0, 24.0 - (days.length * 0.4)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStepsLineChart(
      List<DateTime> days, Map<String, StepLog> map, int goal, bool isDark) {
    double maxY = goal * 1.2;
    final spots = <FlSpot>[];
    for (int i = 0; i < days.length; i++) {
      final key = _formatDateKey(days[i]);
      final val = (map[key]?.steps ?? 0).toDouble();
      if (val > maxY) maxY = val * 1.15;
      spots.add(FlSpot(i.toDouble(), val));
    }

    return LineChart(
      LineChartData(
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : Colors.black87,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = days[spot.x.toInt()];
                final dateStr = DateFormat('EEE, MMM d').format(date);
                return LineTooltipItem(
                  "$dateStr\n${spot.y.toInt()} steps",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('M/d').format(days[idx]),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: goal.toDouble(),
              color: const Color(0xFFF59E0B),
              strokeWidth: 2,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF59E0B),
                ),
                labelResolver: (line) => "${LanguageService.tr('Goal')}: $goal steps",
              ),
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFFF59E0B),
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            ),
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHistoryRow(
      DateTime date, StepLog? log, int goal, bool isDark) {
    final steps = log?.steps ?? 0;
    final km = log?.distanceKm ?? (steps * 0.75 / 1000.0);
    final kcal = log?.caloriesBurned ?? (steps * 0.04).round();
    final isGoalMet = steps >= goal;
    final pct = (steps / goal).clamp(0.0, 1.0);

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
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_walk_rounded,
              color: Color(0xFFF59E0B),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE, MMM d, yyyy').format(date),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "$steps / $goal steps • ${km.toStringAsFixed(1)} km • $kcal kcal",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isGoalMet
                  ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isGoalMet ? "Goal Met 🎉" : "${(pct * 100).toStringAsFixed(0)}%",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isGoalMet ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 4: HYDRATION HISTORY
  // ===========================================================================

  Widget _buildHydrationTab(bool isDark, Color primaryColor) {
    final days = _daysInRange;
    int totalConsumed = 0;
    int daysGoalMet = 0;
    const dailyGoal = 3000;

    for (final day in days) {
      final key = _formatDateKey(day);
      final consumed = _waterMap[key] ?? 0;
      totalConsumed += consumed;
      if (consumed >= dailyGoal) daysGoalMet++;
    }

    final avgDailyWater = days.isNotEmpty ? (totalConsumed / days.length).round() : 0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hydration Summary Cards
          Row(
            children: [
              Expanded(
                child: InfoCard(
                  child: Column(
                    children: [
                      Text(
                        LanguageService.tr("Avg Water/Day"),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${(avgDailyWater / 1000).toStringAsFixed(1)} L",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InfoCard(
                  child: Column(
                    children: [
                      Text(
                        LanguageService.tr("Days Goal Met"),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$daysGoalMet / ${days.length}",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InfoCard(
                  child: Column(
                    children: [
                      Text(
                        LanguageService.tr("Daily Goal"),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${(dailyGoal / 1000).toStringAsFixed(1)} L",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Hydration Chart Card
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LanguageService.tr("Weekly Hydration Graph"),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 200,
                  child: _chartType == ChartType.bar
                      ? _buildWaterBarChart(days, _waterMap, dailyGoal, primaryColor, isDark)
                      : _buildWaterLineChart(days, _waterMap, dailyGoal, primaryColor, isDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Hydration History List Section
          Text(
            LanguageService.tr("Hydration History"),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ...days.reversed.map((day) {
            final key = _formatDateKey(day);
            final consumed = _waterMap[key] ?? 0;
            return _buildWaterRow(day, consumed, dailyGoal, isDark, primaryColor);
          }),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildWaterBarChart(
      List<DateTime> days, Map<String, int> map, int goal, Color primaryColor, bool isDark) {
    double maxY = goal * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : Colors.black87,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final date = days[group.x.toInt()];
              final dateStr = DateFormat('EEE, MMM d').format(date);
              return BarTooltipItem(
                "$dateStr\n${rod.toY.toInt()} mL",
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('M/d').format(days[idx]),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(days.length, (i) {
          final val = (map[_formatDateKey(days[i])] ?? 0).toDouble();
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: val,
                color: const Color(0xFF0EA5E9),
                width: max(8.0, 24.0 - (days.length * 0.4)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildWaterLineChart(
      List<DateTime> days, Map<String, int> map, int goal, Color primaryColor, bool isDark) {
    double maxY = goal * 1.2;

    final spots = <FlSpot>[];
    for (int i = 0; i < days.length; i++) {
      final val = (map[_formatDateKey(days[i])] ?? 0).toDouble();
      spots.add(FlSpot(i.toDouble(), val));
    }

    return LineChart(
      LineChartData(
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => isDark ? const Color(0xFF1E293B) : Colors.black87,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = days[spot.x.toInt()];
                final dateStr = DateFormat('EEE, MMM d').format(date);
                return LineTooltipItem(
                  "$dateStr\n${spot.y.toInt()} mL",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('M/d').format(days[idx]),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: goal.toDouble(),
              color: const Color(0xFF0EA5E9),
              strokeWidth: 2,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0EA5E9),
                ),
                labelResolver: (line) => "${LanguageService.tr('Goal')}: ${goal}mL",
              ),
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF0EA5E9),
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
            ),
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterRow(
      DateTime date, int consumed, int goal, bool isDark, Color primaryColor) {
    final pct = (consumed / goal).clamp(0.0, 1.0);

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
          const Icon(Icons.water_drop_rounded, color: Color(0xFF0EA5E9), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE, MMM d, yyyy').format(date),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  "${(pct * 100).toStringAsFixed(0)}% ${LanguageService.tr('of daily goal')}",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "$consumed / $goal mL",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF0EA5E9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
