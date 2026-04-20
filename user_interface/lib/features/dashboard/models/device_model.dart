class Device {
  final String id;
  final String name;
  final DateTime? lastSeen;
  final DateTime? lastReadingAt;
  final bool _isOnlineOverride;

  Device({
    required this.id,
    required this.name,
    this.lastSeen,
    this.lastReadingAt,
    bool isOnlineOverride = false,
  }) : _isOnlineOverride = isOnlineOverride;

  /// Online if either heartbeat (`last_seen`) or incoming readings are recent.
  bool get isOnline {
    const offlineTimeout = Duration(seconds: 90);
    if (_isOnlineOverride) return true; // Manual override for testing only
    DateTime? activity = lastSeen;
    if (lastReadingAt != null && (activity == null || lastReadingAt!.isAfter(activity))) {
      activity = lastReadingAt;
    }
    if (activity == null) return false;
    return DateTime.now().toUtc().difference(activity.toUtc()) < offlineTimeout;
  }

  Device copyWith({
    String? name,
    DateTime? lastSeen,
    DateTime? lastReadingAt,
    bool? isOnlineOverride,
  }) {
    return Device(
      id: id,
      name: name ?? this.name,
      lastSeen: lastSeen ?? this.lastSeen,
      lastReadingAt: lastReadingAt ?? this.lastReadingAt,
      isOnlineOverride: isOnlineOverride ?? _isOnlineOverride,
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    final lastReadingAt = json['last_reading_at'] != null
        ? DateTime.parse(json['last_reading_at'])
        : null;
    final lastSeen = json['last_seen'] != null
        ? DateTime.parse(json['last_seen'])
        : (lastReadingAt ?? (json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null));
    return Device(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Device',
      lastSeen: lastSeen,
      lastReadingAt: lastReadingAt,
      isOnlineOverride: json['is_online'] == true,
    );
  }
}

