class Sensor {
  final String id;
  final String deviceId;
  final String typeId;
  final String? label;
  final Map<String, dynamic> metadata;
  final SensorType? sensorType;

  Sensor({
    required this.id,
    required this.deviceId,
    required this.typeId,
    this.label,
    this.metadata = const {},
    this.sensorType,
  });

  factory Sensor.fromJson(Map<String, dynamic> json) {
    return Sensor(
      id: json['id'] ?? '',
      deviceId: json['device_id'] ?? '',
      typeId: json['type_id'] ?? '',
      label: json['label'],
      metadata: json['metadata'] ?? {},
      sensorType: json['sensor_types'] != null
          ? SensorType.fromJson(json['sensor_types'])
          : null,
    );
  }
}

class SensorType {
  final String key;
  final String name;
  final String? unit;

  SensorType({
    required this.key,
    required this.name,
    this.unit,
  });

  factory SensorType.fromJson(Map<String, dynamic> json) {
    return SensorType(
      key: json['key'] ?? '',
      name: json['name'] ?? '',
      unit: json['unit'],
    );
  }
}

