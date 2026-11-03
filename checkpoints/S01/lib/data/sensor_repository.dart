import '../models/sensor_reading.dart';
import 'sensor_service.dart';

// [S00] 전달받은 데이터를 앱의 모델로 바꿉니다.
class SensorRepository {
  SensorRepository(this._service);
  final SensorService _service;

  Future<SensorReading> fetchLatest() async {
    return SensorReading.fromJson(await _service.fetchLatest());
  }

  // S01-②: 수신한 문자열 Stream을 그대로 ViewModel에 전달합니다.
  Future<Stream<String>> openMessages() => _service.openMessages();

  void dispose() => _service.dispose();
}
