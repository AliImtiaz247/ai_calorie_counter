import 'package:flutter/material.dart';

class CalorieProgressCard extends StatelessWidget {
  final double consumedCalories;
  final double dailyGoal;
  final double protein;
  final double proteinGoal;
  final double carbs;
  final double carbsGoal;
  final double fat;
  final double fatGoal;

  const CalorieProgressCard({
    super.key,
    required this.consumedCalories,
    required this.dailyGoal,
    required this.protein,
    required this.proteinGoal,
    required this.carbs,
    required this.carbsGoal,
    required this.fat,
    required this.fatGoal,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF22C55E);
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final progressBgColor = isDark ? Colors.white12 : Colors.grey.shade200;

    final remaining = (dailyGoal - consumedCalories).clamp(0, dailyGoal);
    final calorieProgress = (consumedCalories / dailyGoal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(
                        value: calorieProgress,
                        strokeWidth: 10,
                        backgroundColor: progressBgColor,
                        color: primaryColor,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${(calorieProgress * 100).toInt()}%",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          "Completed",
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Calories",
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      consumedCalories.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      "${remaining.toStringAsFixed(0)} kcal Remaining",
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Goal : ${dailyGoal.toStringAsFixed(0)} kcal",
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _NutritionBar(
            title: "Protein",
            value: protein,
            goal: proteinGoal,
            color: Colors.redAccent,
            isDark: isDark,
            progressBgColor: progressBgColor,
          ),
          const SizedBox(height: 12),
          _NutritionBar(
            title: "Carbs",
            value: carbs,
            goal: carbsGoal,
            color: Colors.orange,
            isDark: isDark,
            progressBgColor: progressBgColor,
          ),
          const SizedBox(height: 12),
          _NutritionBar(
            title: "Fat",
            value: fat,
            goal: fatGoal,
            color: Colors.blue,
            isDark: isDark,
            progressBgColor: progressBgColor,
          ),
        ],
      ),
    );
  }
}

class _NutritionBar extends StatelessWidget {
  final String title;
  final double value;
  final double goal;
  final Color color;
  final bool isDark;
  final Color progressBgColor;

  const _NutritionBar({
    required this.title,
    required this.value,
    required this.goal,
    required this.color,
    required this.isDark,
    required this.progressBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (value / goal).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              "${value.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} g",
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: progressBgColor,
            color: color,
          ),
        ),
      ],
    );
  }
}