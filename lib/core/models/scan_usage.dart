class ScanUsage {
  final int limit;
  final int used;
  final int remaining;
  final String? resetAt;

  ScanUsage({
    required this.limit,
    required this.used,
    required this.remaining,
    this.resetAt,
  });

  bool get isLimitReached => remaining <= 0;

  factory ScanUsage.fromJson(Map<String, dynamic> json) {
    final limit = json['limit'] is int ? json['limit'] as int : 5;
    final used = json['used'] is int ? json['used'] as int : 0;
    final remaining = json['remaining'] is int
        ? json['remaining'] as int
        : (limit - used).clamp(0, limit);
    final resetAt = json['resetAt'] as String?;

    return ScanUsage(
      limit: limit,
      used: used,
      remaining: remaining,
      resetAt: resetAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'limit': limit,
        'used': used,
        'remaining': remaining,
        'resetAt': resetAt,
      };

  @override
  String toString() {
    return 'ScanUsage(limit: $limit, used: $used, remaining: $remaining, resetAt: $resetAt)';
  }
}
