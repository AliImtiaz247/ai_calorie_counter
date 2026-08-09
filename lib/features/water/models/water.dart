class Water {
  final String date;
  final int goal;
  final int consumed;

  const Water({required this.date, required this.goal, required this.consumed});

  Water copyWith({int? goal, int? consumed}) {
    return Water(
      date: date,
      goal: goal ?? this.goal,
      consumed: consumed ?? this.consumed,
    );
  }

  Map<String, dynamic> toMap() {
    return {"goal": goal, "consumed": consumed};
  }

  factory Water.fromMap(String date, Map<String, dynamic> map) {
    return Water(
      date: date,
      goal: map["goal"] ?? 3000,
      consumed: map["consumed"] ?? 0,
    );
  }
}
