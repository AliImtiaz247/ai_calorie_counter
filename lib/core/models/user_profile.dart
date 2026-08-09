import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String name;
  final String email;

  final int age;
  final double height;
  final double currentWeight;
  final double targetWeight;

  final String gender;
  final String activityLevel;
  final String goal;

  final String? avatarUrl;

  final DateTime? createdAt;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.age,
    required this.height,
    required this.currentWeight,
    required this.targetWeight,
    required this.gender,
    required this.activityLevel,
    required this.goal,
    this.avatarUrl,
    this.createdAt,
  });

  /// Empty profile
  factory UserProfile.empty() {
    return const UserProfile(
      uid: '',
      name: '',
      email: '',
      age: 0,
      height: 0,
      currentWeight: 0,
      targetWeight: 0,
      gender: '',
      activityLevel: '',
      goal: '',
      avatarUrl: null,
      createdAt: null,
    );
  }

  bool get isEmpty => uid.isEmpty;

  bool get isNotEmpty => uid.isNotEmpty;

  /// Returns the default avatar asset path based on user gender
  String get defaultAvatarAsset {
    final g = gender.trim().toLowerCase();
    if (g.contains('female') || g.contains('woman') || g.contains('girl')) {
      return 'assets/images/default_female_avatar.png';
    }
    return 'assets/images/default_male_avatar.png';
  }

  /// Whether a custom network avatar is uploaded
  bool get hasCustomAvatar => avatarUrl != null && avatarUrl!.trim().isNotEmpty;

  UserProfile copyWith({
    String? uid,
    String? name,
    String? email,
    int? age,
    double? height,
    double? currentWeight,
    double? targetWeight,
    String? gender,
    String? activityLevel,
    String? goal,
    String? avatarUrl,
    DateTime? createdAt,
    bool removeAvatar = false,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      age: age ?? this.age,
      height: height ?? this.height,
      currentWeight: currentWeight ?? this.currentWeight,
      targetWeight: targetWeight ?? this.targetWeight,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      avatarUrl: removeAvatar ? null : (avatarUrl ?? this.avatarUrl),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "uid": uid,
      "name": name,
      "email": email,
      "age": age,
      "height": height,
      "currentWeight": currentWeight,
      "targetWeight": targetWeight,
      "gender": gender,
      "activityLevel": activityLevel,
      "goal": goal,
      "avatarUrl": avatarUrl,
      "createdAt": createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map["uid"]?.toString() ?? "",

      name: map["name"]?.toString() ?? "",

      email: map["email"]?.toString() ?? "",

      age: (map["age"] ?? 0) is int
          ? map["age"]
          : int.tryParse(map["age"].toString()) ?? 0,

      height: (map["height"] ?? 0).toDouble(),

      currentWeight: (map["currentWeight"] ?? 0).toDouble(),

      targetWeight: (map["targetWeight"] ?? 0).toDouble(),

      gender: map["gender"]?.toString() ?? "",

      activityLevel: map["activityLevel"]?.toString() ?? "",

      goal: map["goal"]?.toString() ?? "",

      avatarUrl: map["avatarUrl"],

      createdAt: map["createdAt"] is Timestamp
          ? (map["createdAt"] as Timestamp).toDate()
          : null,
    );
  }

  @override
  String toString() {
    return '''
UserProfile(
 uid: $uid,
 name: $name,
 email: $email,
 age: $age,
 height: $height,
 currentWeight: $currentWeight,
 targetWeight: $targetWeight,
 gender: $gender,
 activityLevel: $activityLevel,
 goal: $goal,
 avatarUrl: $avatarUrl
)
''';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is UserProfile &&
            runtimeType == other.runtimeType &&
            uid == other.uid;
  }

  @override
  int get hashCode => uid.hashCode;
}