class ScanUsage {
  final int limit;
  final int used;
  final int remaining;
  final String? resetAt;

  const ScanUsage({
    required this.limit,
    required this.used,
    required this.remaining,
    this.resetAt,
  });

  bool get isLimitReached => remaining <= 0;

  /// Parses the authoritative scan usage returned by the Calorix backend.
  ///
  /// The backend can expose usage in either of these shapes:
  ///
  /// 1. Direct quota object:
  ///    { limit, used, remaining, resetAt }
  ///
  /// 2. Scan status object:
  ///    { dailyLimit, completedScans, remainingScans, quota: {...}, usage: {...} }
  ///
  /// Keeping this parser tolerant prevents frontend/backend schema drift from
  /// making the app fall back to an incorrect 5-scan limit.
  factory ScanUsage.fromJson(Map<String, dynamic> json) {
    final quota = json['quota'] is Map
        ? Map<String, dynamic>.from(json['quota'] as Map)
        : <String, dynamic>{};

    final usage = json['usage'] is Map
        ? Map<String, dynamic>.from(json['usage'] as Map)
        : <String, dynamic>{};

    final limit = _readInt(
          json['dailyLimit'],
        ) ??
        _readInt(quota['limit']) ??
        _readInt(usage['dailyLimit']) ??
        _readInt(json['limit']) ??
        4;

    final used = _readInt(
          json['completedScans'],
        ) ??
        _readInt(quota['used']) ??
        _readInt(usage['used']) ??
        _readInt(json['used']) ??
        0;

    final remaining = _readInt(
          json['remainingScans'],
        ) ??
        _readInt(quota['remaining']) ??
        _readInt(usage['remaining']) ??
        _readInt(json['remaining']) ??
        (limit - used).clamp(0, limit);

    final resetAt = _readString(json['resetAt']) ??
        _readString(quota['resetAt']) ??
        _readString(usage['resetAt']);

    return ScanUsage(
      limit: limit.clamp(0, 1000),
      used: used.clamp(0, 1000),
      remaining: remaining.clamp(0, 1000),
      resetAt: resetAt,
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
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
