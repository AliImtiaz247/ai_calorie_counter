enum AchievementType {
  streak,
  meals,
  hydration,
  consistency,
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final AchievementType type;
  final int target;
  final int progress;
  final bool unlocked;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.target,
    required this.progress,
    required this.unlocked,
  });

  double get progressRatio {
    if (target <= 0) return unlocked ? 1 : 0;
    return (progress / target).clamp(0.0, 1.0);
  }
}
