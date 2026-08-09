import 'package:cloud_firestore/cloud_firestore.dart';

class WeightLog {
  final String id;
  final String userId;
  final double weight;
  final DateTime date;
  final String? note;

  const WeightLog({
    required this.id,
    required this.userId,
    required this.weight,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'weight': weight,
      'date': Timestamp.fromDate(date),
      'note': note,
    };
  }

  factory WeightLog.fromMap(Map<String, dynamic> map, String docId) {
    return WeightLog(
      id: docId,
      userId: map['userId']?.toString() ?? '',
      weight: (map['weight'] ?? 0.0).toDouble(),
      date: map['date'] is Timestamp
          ? (map['date'] as Timestamp).toDate()
          : DateTime.now(),
      note: map['note']?.toString(),
    );
  }
}
