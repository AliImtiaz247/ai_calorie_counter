class UserProfile {
  final String name;
  final int age;
  final String gender;
  final double height;
  final double weight;
  final double targetWeight;
  final String activityLevel;
  final String goal;
  final int dailyCalories;

  UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.height,
    required this.weight,
    required this.targetWeight,
    required this.activityLevel,
    required this.goal,
    required this.dailyCalories,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'targetWeight': targetWeight,
      'activityLevel': activityLevel,
      'goal': goal,
      'dailyCalories': dailyCalories,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'],
      age: map['age'],
      gender: map['gender'],
      height: map['height'].toDouble(),
      weight: map['weight'].toDouble(),
      targetWeight: map['targetWeight'].toDouble(),
      activityLevel: map['activityLevel'],
      goal: map['goal'],
      dailyCalories: map['dailyCalories'],
    );
  }
}
