import '../models/nutrition_insight.dart';
import '../models/weekly_report.dart';

/// Generates low-cost personalized nutrition insights from locally aggregated
/// data. No Gemini request is required for these deterministic insights.
class NutritionInsightService {
  const NutritionInsightService._();

  static List<NutritionInsight> generate(WeeklyReport report) {
    if (!report.hasData) {
      return const [
        NutritionInsight(
          title: 'Start tracking',
          message:
              'Log your meals and water for a few days to unlock personalized nutrition insights.',
          type: NutritionInsightType.neutral,
        ),
      ];
    }

    final insights = <NutritionInsight>[];

    if (report.calorieGoalConsistency >= 0.70) {
      insights.add(
        NutritionInsight(
          title: 'Great calorie consistency',
          message:
              'You stayed within your calorie target range on ${report.daysMeetingCalorieGoal} of ${report.days} days.',
          type: NutritionInsightType.positive,
          metric: '${(report.calorieGoalConsistency * 100).round()}%',
        ),
      );
    } else if (report.daysWithMeals > 0) {
      insights.add(
        NutritionInsight(
          title: 'Calorie consistency can improve',
          message:
              'Your intake was close to your target on ${report.daysMeetingCalorieGoal} of ${report.days} days. Use your meal plan to keep daily intake more consistent.',
          type: NutritionInsightType.warning,
        ),
      );
    }

    if (report.mealConsistency >= 0.85) {
      insights.add(
        NutritionInsight(
          title: 'Strong tracking habit',
          message:
              'You logged meals on ${report.daysWithMeals} of ${report.days} days. Keeping this habit makes your progress easier to measure.',
          type: NutritionInsightType.positive,
          metric: '${(report.mealConsistency * 100).round()}%',
        ),
      );
    } else {
      insights.add(
        NutritionInsight(
          title: 'Log meals more consistently',
          message:
              'You logged meals on ${report.daysWithMeals} of ${report.days} days. More complete tracking will make your nutrition trends more reliable.',
          type: NutritionInsightType.neutral,
        ),
      );
    }

    if (report.waterGoalConsistency >= 0.70) {
      insights.add(
        NutritionInsight(
          title: 'Hydration is on track',
          message:
              'You reached your water goal on ${report.daysMeetingWaterGoal} of ${report.days} days.',
          type: NutritionInsightType.positive,
          metric: '${(report.waterGoalConsistency * 100).round()}%',
        ),
      );
    } else {
      insights.add(
        NutritionInsight(
          title: 'Hydration needs attention',
          message:
              'Your average intake was ${report.averageDailyWater} mL per day. Try spreading water across the day instead of catching up late.',
          type: NutritionInsightType.warning,
          metric: '${report.averageDailyWater} mL/day',
        ),
      );
    }

    if (report.averageDailyProtein > 0 &&
        report.averageDailyProtein < 50) {
      insights.add(
        NutritionInsight(
          title: 'Protein may be low',
          message:
              'Your logged protein averaged ${report.averageDailyProtein.toStringAsFixed(1)} g/day. Consider adding protein-rich foods to meals.',
          type: NutritionInsightType.warning,
          metric: '${report.averageDailyProtein.toStringAsFixed(1)} g/day',
        ),
      );
    } else if (report.averageDailyProtein >= 50) {
      insights.add(
        NutritionInsight(
          title: 'Good protein coverage',
          message:
              'Your logged protein averaged ${report.averageDailyProtein.toStringAsFixed(1)} g/day this week.',
          type: NutritionInsightType.positive,
          metric: '${report.averageDailyProtein.toStringAsFixed(1)} g/day',
        ),
      );
    }

    if (report.totalMeals >= 14) {
      insights.add(
        NutritionInsight(
          title: 'Useful nutrition history',
          message:
              'You logged ${report.totalMeals} meals this week, giving Calorix enough history to identify useful patterns.',
          type: NutritionInsightType.positive,
        ),
      );
    }

    return insights.take(6).toList();
  }
}
