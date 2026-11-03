import 'dart:convert';
import '../models/sensor_reading.dart';
import 'sensor_service.dart';

// [S00] 전달받은 데이터를 앱의 모델로 바꿉니다.
class SensorRepository {
  SensorRepository(this._service);
  final SensorService _service;

  Future<SensorReading> fetchLatest() async {
    return SensorReading.fromJson(await _service.fetchLatest());
  }

  // S02-①: 수신한 JSON 메시지를 SensorReading 객체 Stream으로 변환합니다.
  Future<Stream<SensorReading>> watchReadings() async {
    final messages = await _service.openMessages();
    // 수업용: 서버가 올바른 센서 JSON을 보낸다고 가정합니다.
    return messages.map((raw) =>
        SensorReading.fromJson(jsonDecode(raw) as Map<String, dynamic>));
  }

  void dispose() => _service.dispose();
}
