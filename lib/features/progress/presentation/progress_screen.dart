import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/language_service.dart';
import '../../../core/utils/responsive.dart';
import '../../profile/data/profile_repository.dart';
import '../../weight/data/weight_repository.dart';
import '../../weight/models/weight_log.dart';

class ProgressScreen extends StatefulWidget {
  final UserProfile? userProfile;

  const ProgressScreen({super.key, this.userProfile});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final WeightRepository _weightRepository = WeightRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  double? _targetWeightOverride;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: LanguageService.currentLanguageNotifier,
      builder: (context, _, child) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile = widget.userProfile;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LanguageService.tr('Progress & Weight'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            tooltip: LanguageService.tr('Edit Target Weight'),
            onPressed: () {
              final target = _targetWeightOverride ?? profile?.targetWeight ?? 65.0;
              _showEditTargetWeightDialog(target);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWeightDialog,
        icon: const Icon(Icons.add_rounded),
        label: Text(LanguageService.tr('Log Weight')),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _profileRepository.profileStream(),
        builder: (context, profileSnapshot) {
          final activeProfile = profileSnapshot.data ?? profile;

          return StreamBuilder<List<WeightLog>>(
            stream: _weightRepository.getWeightLogsStream(),
            builder: (context, snapshot) {
              final logs = snapshot.data ?? [];
              final currentWeight = logs.isNotEmpty
                  ? logs.last.weight
                  : (activeProfile?.currentWeight ?? 70.0);
              final targetWeight =
                  _targetWeightOverride ?? activeProfile?.targetWeight ?? 65.0;

              return ResponsiveContentConstrained(
                maxWidth: Responsive.maxDashboardWidth(context),
                enableScroll: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Goal Progress Header Card
                    _buildGoalCard(
                      currentWeight,
                      targetWeight,
                      logs,
                      activeProfile,
                      isDark,
                    ),
                    const SizedBox(height: 24),

                    // Weight Progression Chart Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          LanguageService.tr('Weight Chart'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${logs.length} ${LanguageService.tr('logs')}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white60
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Chart Container
                    _buildChartCard(logs, targetWeight, isDark),
                    const SizedBox(height: 24),

                    // Weight History Section
                    Text(
                      LanguageService.tr('Weight History'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (logs.isEmpty)
                      _buildEmptyState(isDark)
                    else
                      _buildWeightLogList(logs, isDark),
                    const SizedBox(height: 80), // Fab space
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildGoalCard(
    double current,
    double target,
    List<WeightLog> logs,
    UserProfile? activeProfile,
    bool isDark,
  ) {
    final diff = current - target;
    final isLoss = diff > 0;
    final remainingStr = diff.abs().toStringAsFixed(1);

    // Baseline start weight: first log's weight or profile baseline
    final startWeight = logs.isNotEmpty
        ? logs.first.weight
        : (activeProfile?.currentWeight ?? current);
    double progress = 0.0;
    if ((startWeight - target).abs() > 0.1) {
      progress =
          ((startWeight - current) / (startWeight - target)).clamp(0.0, 1.0);
    } else {
      progress = current == target ? 1.0 : 0.5;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
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
                    LanguageService.tr("Current Weight"),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${current.toStringAsFixed(1)} kg",
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.track_changes_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 26,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showEditTargetWeightDialog(target),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            LanguageService.tr("Target Weight"),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${target.toStringAsFixed(1)} kg",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LanguageService.tr("Goal Progress"),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
              Text(
                "${(progress * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isLoss
                  ? Colors.amber.withValues(alpha: 0.12)
                  : const Color(0xFF22C55E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  isLoss ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                  color: isLoss ? Colors.amber.shade800 : const Color(0xFF22C55E),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isLoss
                      ? "$remainingStr ${LanguageService.tr('kg left to lose to reach your goal')}"
                      : "$remainingStr ${LanguageService.tr('kg left to gain to reach your goal')}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isLoss ? Colors.amber.shade900 : const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(List<WeightLog> logs, double target, bool isDark) {
    if (logs.length < 2) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              LanguageService.tr("Log at least 2 weight entries to view graph."),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    final spots = logs.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.weight);
    }).toList();

    final weights = logs.map((l) => l.weight).toList();
    final minW = (weights.reduce((a, b) => a < b ? a : b) - 2).clamp(0.0, 300.0);
    final maxW = weights.reduce((a, b) => a > b ? a : b) + 2;

    return Container(
      height: 240,
      padding: const EdgeInsets.only(top: 20, bottom: 12, right: 20, left: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          minY: minW,
          maxY: maxW,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < logs.length) {
                    final date = logs[index].date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        DateFormat('d MMM').format(date),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  return Text(
                    "${value.toInt()}",
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: target,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                strokeWidth: 2,
                dashArray: [6, 6],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  labelResolver: (line) => '${LanguageService.tr('Target')}: ${target.toStringAsFixed(1)}kg',
                ),
              ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2.5,
                    strokeColor: Theme.of(context).colorScheme.primary,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(30),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.monitor_weight_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            LanguageService.tr("No weight entries logged yet."),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            LanguageService.tr("Tap 'Log Weight' below to record your first entry."),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightLogList(List<WeightLog> logs, bool isDark) {
    final reversedLogs = logs.reversed.toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reversedLogs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final log = reversedLogs[index];
        final prevLog = (index + 1 < reversedLogs.length) ? reversedLogs[index + 1] : null;
        final diff = prevLog != null ? (log.weight - prevLog.weight) : 0.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.scale_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${log.weight.toStringAsFixed(1)} kg",
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEE, d MMM yyyy').format(log.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                    if (log.note != null && log.note!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        log.note!,
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
              if (prevLog != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: diff <= 0
                        ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                        : Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: diff <= 0 ? const Color(0xFF15803D) : Colors.amber.shade900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.grey),
                onPressed: () => _confirmDeleteLog(log.id),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddWeightDialog() async {
    final weightController = TextEditingController(
      text: widget.userProfile?.currentWeight.toStringAsFixed(1) ?? "",
    );
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Log Weight Entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        hintText: 'e.g. 72.5',
                        suffixText: 'kg',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (Optional)',
                        hintText: 'e.g. After workout',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Date: ${DateFormat('d MMM yyyy').format(selectedDate)}",
                          style: const TextStyle(fontSize: 13),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDate = picked);
                            }
                          },
                          child: const Text('Change Date'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final w = double.tryParse(weightController.text);
                    if (w != null && w > 0) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final w = double.tryParse(weightController.text)!;
      final note = noteController.text.trim();
      await _weightRepository.addWeightLog(
        w,
        date: selectedDate,
        note: note.isNotEmpty ? note : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight logged successfully!')),
      );
    }
  }

  Future<void> _confirmDeleteLog(String logId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Log'),
        content: const Text('Are you sure you want to delete this weight entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _weightRepository.deleteWeightLog(logId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight entry deleted.')),
      );
    }
  }

  Future<void> _showEditTargetWeightDialog(double currentTarget) async {
    final controller = TextEditingController(
      text: currentTarget > 0 ? currentTarget.toStringAsFixed(1) : "",
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Target Weight'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Target Weight (kg)',
            hintText: 'e.g. 65.0',
            suffixText: 'kg',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.replaceAll(',', '.'));
              if (val != null && val > 0) {
                Navigator.pop(context, val);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      try {
        await ProfileRepository().updateTargetWeight(result);
        if (!mounted) return;
        setState(() {
          _targetWeightOverride = result;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Target weight updated to ${result.toStringAsFixed(1)} kg',
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update target weight: $e')),
        );
      }
    }
  }
}
