import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/language_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/utils/responsive.dart';
import '../data/step_repository.dart';
import '../models/step_log.dart';

class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StepRepository _stepRepository = StepRepository.instance;

  StepLog? _todayLog;
  List<StepLog> _historyLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _stepRepository.addListener(_onRepoChanged);
    _loadStepData();
  }

  @override
  void dispose() {
    _stepRepository.removeListener(_onRepoChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onRepoChanged() {
    _loadStepData();
  }

  Future<void> _loadStepData() async {
    try {
      final todayLog = await _stepRepository.getTodaySteps();
      final history = await _stepRepository.getStepHistoryForLastDays(30);

      if (!mounted) return;
      setState(() {
        _todayLog = todayLog;
        _historyLogs = history;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showGoalSelectionDialog(int currentGoal) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int selectedGoal = currentGoal;
    final customController = TextEditingController(text: currentGoal.toString());

    final presetGoals = [5000, 7500, 10000, 12500, 15000];

    final newGoal = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.flag_rounded, color: Color(0xFF22C55E)),
              const SizedBox(width: 8),
              Text(
                LanguageService.tr("Daily Step Goal"),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LanguageService.tr("Select a daily step goal:"),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presetGoals.map((goal) {
                  final isSelected = selectedGoal == goal;
                  return ChoiceChip(
                    label: Text(NumberFormat("#,##0").format(goal)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF22C55E),
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setDialogState(() {
                          selectedGoal = goal;
                          customController.text = goal.toString();
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: customController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: LanguageService.tr("Custom Goal"),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixText: LanguageService.tr("steps"),
                ),
                onChanged: (val) {
                  final parsed = int.tryParse(val.trim());
                  if (parsed != null && parsed > 0) {
                    setDialogState(() => selectedGoal = parsed);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(LanguageService.tr("Cancel")),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final parsed = int.tryParse(customController.text.trim());
                final finalGoal = (parsed != null && parsed > 0) ? parsed : selectedGoal;
                Navigator.pop(context, finalGoal);
              },
              child: Text(LanguageService.tr("Save Goal")),
            ),
          ],
        ),
      ),
    );

    if (newGoal != null && newGoal > 0) {
      await _stepRepository.setDailyGoal(newGoal);
    }
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
    const primaryColor = Color(0xFF22C55E);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F9F7),
      appBar: AppBar(
        title: Text(
          LanguageService.tr("Steps"),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: LanguageService.tr("Set Daily Goal"),
            onPressed: () {
              if (_todayLog != null) {
                _showGoalSelectionDialog(_todayLog!.goal);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          indicatorWeight: 3,
          labelColor: primaryColor,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.grey.shade600,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: LanguageService.tr("Today")),
            Tab(text: LanguageService.tr("Week")),
            Tab(text: LanguageService.tr("Month")),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildTodayTab(isDark, primaryColor),
                  _buildHistoryTab(daysCount: 7, isDark: isDark, primaryColor: primaryColor),
                  _buildHistoryTab(daysCount: 30, isDark: isDark, primaryColor: primaryColor),
                ],
              ),
      ),
    );
  }

  // ===========================================================================
  // TODAY TAB
  // ===========================================================================

  Widget _buildTodayTab(bool isDark, Color primaryColor) {
    final log = _todayLog ??
        StepLog(
          id: _stepRepository.today,
          userId: _stepRepository.uid ?? 'local',
          date: _stepRepository.today,
          steps: 0,
          goal: 10000,
        );

    final formatter = NumberFormat("#,##0", "en_US");
    final pctCompleted = (log.completionPercentage * 100).toStringAsFixed(0);
    final trackingState = _stepRepository.trackingState;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 18,
      ),
      child: Column(
        children: [
          // Permission / Onboarding Banner if not actively tracking
          if (trackingState != StepTrackingState.active)
            _buildPermissionBanner(trackingState, isDark, primaryColor),

          // Main Step Progress Ring Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 190,
                      height: 190,
                      child: CircularProgressIndicator(
                        value: log.completionPercentage,
                        strokeWidth: 16,
                        strokeCap: StrokeCap.round,
                        backgroundColor:
                            isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.directions_walk_rounded,
                          color: primaryColor,
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatter.format(log.steps),
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          LanguageService.tr("steps"),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Goal & Percentage Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${LanguageService.tr('Goal')}: ${formatter.format(log.goal)} ${LanguageService.tr('steps')}",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showGoalSelectionDialog(log.goal),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              "$pctCompleted% ${LanguageService.tr('completed')}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.edit, size: 12, color: primaryColor),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3 Compact Stat Cards (Distance, Calories, Sync)
          Row(
            children: [
              Expanded(
                child: _buildCompactStatCard(
                  title: LanguageService.tr("Distance"),
                  value: "${log.distanceKm.toStringAsFixed(1)} km",
                  subtitle: LanguageService.tr("Estimated"),
                  icon: Icons.location_on_rounded,
                  color: const Color(0xFF0EA5E9),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactStatCard(
                  title: LanguageService.tr("Calories"),
                  value: "${log.caloriesBurned} kcal",
                  subtitle: LanguageService.tr("Active burn"),
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: SyncService.instance.isOnlineNotifier,
                  builder: (context, isOnline, _) {
                    return ValueListenableBuilder<SyncStatus>(
                      valueListenable: SyncService.instance.statusNotifier,
                      builder: (context, status, _) {
                        String valueText = LanguageService.tr("Synced");
                        String subtitleText = LanguageService.tr("Auto-Synced");
                        IconData syncIcon = Icons.cloud_done_rounded;
                        Color syncColor = const Color(0xFF10B981);

                        if (!isOnline) {
                          valueText = LanguageService.tr("Offline");
                          subtitleText = LanguageService.tr("Saved locally");
                          syncIcon = Icons.cloud_off_rounded;
                          syncColor = const Color(0xFF64748B);
                        } else if (status == SyncStatus.syncing) {
                          valueText = LanguageService.tr("Syncing...");
                          subtitleText = LanguageService.tr("Uploading");
                          syncIcon = Icons.sync_rounded;
                          syncColor = const Color(0xFFF59E0B);
                        } else if (log.syncStatus == 'pending' || status == SyncStatus.pending) {
                          valueText = LanguageService.tr("Pending");
                          subtitleText = LanguageService.tr("Queued");
                          syncIcon = Icons.cloud_queue_rounded;
                          syncColor = const Color(0xFF0EA5E9);
                        }

                        return _buildCompactStatCard(
                          title: LanguageService.tr("Sync"),
                          value: valueText,
                          subtitle: subtitleText,
                          icon: syncIcon,
                          color: syncColor,
                          isDark: isDark,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Hourly Step Chart
          _buildHourlyChart(log, isDark, primaryColor),
        ],
      ),
    );
  }

  // ===========================================================================
  // PERMISSION / ONBOARDING BANNER
  // ===========================================================================

  Widget _buildPermissionBanner(
      StepTrackingState state, bool isDark, Color primaryColor) {
    if (state == StepTrackingState.sensorUnavailable) {
      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LanguageService.tr("Step Tracking Unavailable"),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    LanguageService.tr(
                        "This device doesn't provide the required step data for automatic tracking."),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (state == StepTrackingState.permissionDenied ||
        state == StepTrackingState.permissionPermanentlyDenied) {
      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.do_not_disturb_on_rounded, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                Text(
                  LanguageService.tr("Step Tracking Disabled"),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              LanguageService.tr(
                  "Calorix no longer has permission to access your physical activity data to automatically track steps."),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (state == StepTrackingState.permissionPermanentlyDenied) {
                  await _stepRepository.openAppSettings();
                } else {
                  await _stepRepository.enableStepTracking();
                }
              },
              child: Text(state == StepTrackingState.permissionPermanentlyDenied
                  ? LanguageService.tr("Open App Settings")
                  : LanguageService.tr("Enable Step Tracking")),
            ),
          ],
        ),
      );
    }

    // Default Not Setup State -> Track Your Steps Card
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_run_rounded, color: primaryColor, size: 26),
              const SizedBox(width: 10),
              Text(
                LanguageService.tr("Track Your Steps"),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            LanguageService.tr(
                "Calorix can automatically track your daily steps to help you understand your activity and calorie burn."),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: () => _stepRepository.enableStepTracking(),
                child: Text(LanguageService.tr("Allow Step Tracking")),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () {},
                child: Text(
                  LanguageService.tr("Not Now"),
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HOURLY CHART
  // ===========================================================================

  Widget _buildHourlyChart(StepLog log, bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LanguageService.tr("Hourly Activity"),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (log.hourlySteps.values.fold<int>(0, max) + 500).toDouble().clamp(1000.0, 50000.0),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final hour = value.toInt();
                        if (hour % 4 == 0) {
                          return Text(
                            "$hour:00",
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
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(24, (hour) {
                  final count = log.hourlySteps[hour] ?? 0;
                  return BarChartGroupData(
                    x: hour,
                    barRods: [
                      BarChartRodData(
                        toY: count.toDouble(),
                        color: primaryColor,
                        width: 6,
                        borderRadius: BorderRadius.circular(4),
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

  // ===========================================================================
  // COMPACT STAT CARD
  // ===========================================================================

  Widget _buildCompactStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HISTORY TAB (WEEK / MONTH)
  // ===========================================================================

  Widget _buildHistoryTab({
    required int daysCount,
    required bool isDark,
    required Color primaryColor,
  }) {
    final history = _historyLogs.take(daysCount).toList();
    if (history.isEmpty) {
      return Center(
        child: Text(
          LanguageService.tr("No step history available yet."),
          style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600),
        ),
      );
    }

    final totalSteps = history.fold<int>(0, (sum, item) => sum + item.steps);
    final avgSteps = (totalSteps / history.length).round();
    final maxStepLog = history.reduce((a, b) => a.steps > b.steps ? a : b);
    final formatter = NumberFormat("#,##0", "en_US");

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 18,
      ),
      child: Column(
        children: [
          // Overview Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryCol(
                  title: LanguageService.tr("Total"),
                  value: formatter.format(totalSteps),
                  isDark: isDark,
                ),
                Container(height: 30, width: 1, color: isDark ? Colors.white12 : Colors.grey.shade300),
                _buildSummaryCol(
                  title: LanguageService.tr("Daily Avg"),
                  value: formatter.format(avgSteps),
                  isDark: isDark,
                ),
                Container(height: 30, width: 1, color: isDark ? Colors.white12 : Colors.grey.shade300),
                _buildSummaryCol(
                  title: LanguageService.tr("Best Day"),
                  value: formatter.format(maxStepLog.steps),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // History Bar Chart
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  daysCount == 7
                      ? LanguageService.tr("Past 7 Days")
                      : LanguageService.tr("Past 30 Days"),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (history.map((e) => e.steps).fold<int>(0, max) + 1000).toDouble().clamp(5000.0, 50000.0),
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < history.length) {
                                if (daysCount == 7 || idx % 5 == 0) {
                                  final dt = DateTime.tryParse(history[idx].date);
                                  return Text(
                                    dt != null ? DateFormat('E').format(dt) : '',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                                    ),
                                  );
                                }
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(history.length, (idx) {
                        final item = history[idx];
                        return BarChartGroupData(
                          x: idx,
                          barRods: [
                            BarChartRodData(
                              toY: item.steps.toDouble(),
                              color: item.steps >= item.goal
                                  ? primaryColor
                                  : primaryColor.withValues(alpha: 0.5),
                              width: daysCount == 7 ? 14 : 6,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCol({
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
