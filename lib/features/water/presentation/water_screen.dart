import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/language_service.dart';
import '../../../core/utils/responsive.dart';
import '../data/water_repository.dart';
import '../models/water.dart';
import '../widget/water_bottle.dart';


class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  final WaterRepository repository = WaterRepository();

  DateTime _selectedDate = DateTime.now();
  List<DateTime> _pastDays = [];
  Map<String, int> _weeklyWaterMap = {};

  Water? water;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    repository.addListener(_onRepoChanged);
    _selectedDate = DateTime.now();
    _generatePastDays();
    _loadWaterData();
  }

  @override
  void dispose() {
    repository.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    _loadWaterData();
  }

  void _generatePastDays() {
    final now = DateTime.now();
    _pastDays = List.generate(7, (i) {
      return DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
    });
  }

  Future<void> _loadWaterData() async {
    setState(() {
      loading = true;
    });

    try {
      final selectedWater = await repository.getWaterForDate(_selectedDate);
      final weeklyMap = await repository.getWaterForLastDays(7);

      if (!mounted) return;

      setState(() {
        water = selectedWater;
        _weeklyWaterMap = weeklyMap;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _onDateSelected(DateTime date) async {
    setState(() {
      _selectedDate = date;
      loading = true;
    });

    final selectedWater = await repository.getWaterForDate(date);
    if (!mounted) return;
    setState(() {
      water = selectedWater;
      loading = false;
    });
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF0EA5E9),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E293B),
                    onSurface: Colors.white,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF0EA5E9),
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null && !isSameDay(picked, _selectedDate)) {
      _onDateSelected(picked);
    }
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _updateLocalWater({int? goal, int? consumed}) async {
    if (!mounted || water == null) return;

    final updatedWater = water!.copyWith(goal: goal, consumed: consumed);
    final key = repository.formatDateKey(_selectedDate);

    setState(() {
      water = updatedWater;
      _weeklyWaterMap[key] = updatedWater.consumed;
    });
  }

  Future<void> addWaterAmount(int amount) async {
    if (water == null) return;

    final updatedConsumed = water!.consumed + amount;
    await _updateLocalWater(consumed: updatedConsumed);

    try {
      await repository.addWater(amount, date: _selectedDate);
      _loadWaterData();
    } catch (_) {
      await _loadWaterData();
    }
  }

  Future<void> removeWaterAmount(int amount) async {
    if (water == null) return;

    final updatedConsumed = (water!.consumed - amount).clamp(
      0,
      water!.consumed,
    );
    await _updateLocalWater(consumed: updatedConsumed);

    try {
      await repository.removeWater(amount, date: _selectedDate);
      _loadWaterData();
    } catch (_) {
      await _loadWaterData();
    }
  }

  Future<void> editGoal() async {
    final controller = TextEditingController(text: water!.goal.toString());

    final value = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(LanguageService.tr("Daily Water Goal")),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: "mL"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LanguageService.tr("Cancel")),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, int.tryParse(controller.text));
            },
            child: Text(LanguageService.tr("Save")),
          ),
        ],
      ),
    );

    if (value == null || value <= 0) return;

    await _updateLocalWater(goal: value);

    try {
      await repository.updateGoal(value, date: _selectedDate);
    } catch (_) {
      await _loadWaterData();
    }
  }

  Future<void> showAddDialog() async {
    final controller = TextEditingController();

    final value = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(LanguageService.tr("Add Water")),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: "mL"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LanguageService.tr("Cancel")),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, int.tryParse(controller.text));
            },
            child: Text(LanguageService.tr("Add")),
          ),
        ],
      ),
    );

    if (value == null || value <= 0) return;

    await addWaterAmount(value);
  }

  Future<void> showRemoveDialog() async {
    final controller = TextEditingController();

    final value = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(LanguageService.tr("Remove Water")),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: "mL"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LanguageService.tr("Cancel")),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, int.tryParse(controller.text));
            },
            child: Text(LanguageService.tr("Remove")),
          ),
        ],
      ),
    );

    if (value == null || value <= 0) return;

    await removeWaterAmount(value);
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
    final primaryColor = const Color(0xFF0EA5E9);

    if (loading && water == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final progress = (water!.consumed / water!.goal).clamp(0.0, 1.0);
    final isToday = isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageService.tr("Water Tracker")),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: LanguageService.tr("Select Date"),
            onPressed: _pickCustomDate,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: LanguageService.tr("Edit Goal"),
            onPressed: editGoal,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxContentWidth = min(constraints.maxWidth, 640.0);
            final titleFontSize = min(32.0, maxContentWidth * 0.09);
            final subtitleFontSize = min(16.0, maxContentWidth * 0.045);

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.horizontalPadding(context),
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Date Selector Strip
                      _buildDateStripSelector(isDark, primaryColor),
                      const SizedBox(height: 16),

                      // Intake Header Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
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
                                        Icons.water_drop_rounded,
                                        color: primaryColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      isToday
                                          ? LanguageService.tr("Today's Intake")
                                          : DateFormat('EEEE, MMM d').format(_selectedDate),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "${(progress * 100).toStringAsFixed(0)}%",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "${water!.consumed} / ${water!.goal} mL",
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${(water!.goal - water!.consumed).clamp(0, water!.goal)} mL ${LanguageService.tr('Remaining')}",
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                                fontSize: subtitleFontSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Animated Water Bottle
                      Center(
                        child: WaterBottle(
                          progress: progress,
                          consumed: water!.consumed,
                          goal: water!.goal,
                          maxWidth: maxContentWidth,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RawMaterialButton(
                            onPressed: showRemoveDialog,
                            elevation: 2,
                            fillColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                            padding: const EdgeInsets.all(14),
                            shape: const CircleBorder(),
                            child: const Icon(
                              Icons.remove_rounded,
                              size: 26,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => addWaterAmount(250),
                              icon: const Icon(Icons.local_drink_rounded, size: 20),
                              label: const Text("+ 250 mL"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                elevation: 4,
                                shadowColor: primaryColor.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          RawMaterialButton(
                            onPressed: showAddDialog,
                            elevation: 2,
                            fillColor: primaryColor,
                            padding: const EdgeInsets.all(14),
                            shape: const CircleBorder(),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 26,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // 7-Day Water Chart Section
                      _buildWaterChartSection(isDark, primaryColor, water!.goal),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateStripSelector(bool isDark, Color primaryColor) {
    return SizedBox(
      height: 70,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pastDays.length,
        itemBuilder: (context, index) {
          final day = _pastDays[index];
          final isSelected = isSameDay(day, _selectedDate);
          final isToday = isSameDay(day, DateTime.now());

          return GestureDetector(
            onTap: () => _onDateSelected(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 58,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? primaryColor
                      : (isDark ? Colors.white12 : Colors.grey.shade300),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isToday ? LanguageService.tr("Today") : DateFormat('EEE').format(day),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white60 : Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d').format(day),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
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

  Widget _buildWaterChartSection(bool isDark, Color primaryColor, int goal) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LanguageService.tr("Weekly Hydration Graph"),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                "${LanguageService.tr('Goal')}: $goal mL",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            LanguageService.tr("Tap any bar to view logged water intake for that date."),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: max((goal * 1.25), 4000.0),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final day = _pastDays[groupIndex];
                      final dayStr = DateFormat('EEE, MMM d').format(day);
                      return BarTooltipItem(
                        "$dayStr\n${rod.toY.toInt()} mL",
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    if (!event.isInterestedForInteractions ||
                        barTouchResponse == null ||
                        barTouchResponse.spot == null) {
                      return;
                    }
                    final index = barTouchResponse.spot!.touchedBarGroupIndex;
                    if (index >= 0 && index < _pastDays.length) {
                      _onDateSelected(_pastDays[index]);
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == (goal / 2).round() || value == goal) {
                          return Text(
                            "${(value / 1000).toStringAsFixed(1)}L",
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.grey.shade600,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _pastDays.length) {
                          final day = _pastDays[index];
                          final isSelected = isSameDay(day, _selectedDate);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('EEE').format(day),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected
                                    ? primaryColor
                                    : (isDark ? Colors.white60 : Colors.grey.shade600),
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
                  horizontalInterval: (goal / 2).toDouble(),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(_pastDays.length, (index) {
                  final day = _pastDays[index];
                  final key = repository.formatDateKey(day);
                  final consumed = (_weeklyWaterMap[key] ?? 0).toDouble();
                  final isSelected = isSameDay(day, _selectedDate);

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: consumed,
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isSelected
                              ? [const Color(0xFF0284C7), primaryColor]
                              : [
                                  primaryColor.withValues(alpha: 0.5),
                                  primaryColor.withValues(alpha: 0.8),
                                ],
                        ),
                        width: isSelected ? 18 : 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: (goal * 1.2).toDouble(),
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade100,
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
}
