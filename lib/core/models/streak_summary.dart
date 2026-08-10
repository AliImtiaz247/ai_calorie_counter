class StreakSummary {
  final int currentStreak;
  final int longestStreak;
  final int activeDays;
  final DateTime? lastActiveDate;

  const StreakSummary({
    required this.currentStreak,
    required this.longestStreak,
    required this.activeDays,
    this.lastActiveDate,
  });

  const StreakSummary.empty()
      : currentStreak = 0,
        longestStreak = 0,
        activeDays = 0,
        lastActiveDate = null;
}
