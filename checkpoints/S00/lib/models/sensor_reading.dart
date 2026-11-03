// [S00] REST와 WebSocket에서 받은 센서값을 동일한 모델로 표현합니다.
class SensorReading {
  const SensorReading({
    required this.bootId,
    required this.sequence,
    required this.recordedAt,
    required this.temperature,
    required this.humidity,
    required this.deviceOn,
  });

  final String bootId;
  final int sequence;
  final DateTime recordedAt;
  final double temperature;
  final double humidity;
  final bool deviceOn;

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    // 수업용: 서버 JSON의 필드와 타입이 올바르다고 가정하고 상세 검사는 생략합니다.
    return SensorReading(
      bootId: json['bootId'] as String,
      sequence: json['sequence'] as int,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      deviceOn: json['deviceOn'] as bool,
    );
  }
}
