enum NutritionInsightType {
  positive,
  warning,
  neutral,
}

class NutritionInsight {
  final String title;
  final String message;
  final NutritionInsightType type;
  final String? metric;

  const NutritionInsight({
    required this.title,
    required this.message,
    required this.type,
    this.metric,
  });
}
