import 'package:flutter/foundation.dart';
import '../data/sensor_repository.dart';
import '../models/sensor_reading.dart';

class SensorDashboardViewModel extends ChangeNotifier {
  SensorDashboardViewModel(this._repository);
  final SensorRepository _repository;

  // [S00] 9주차의 loading, data, error 역할을 복습합니다.
  SensorReading? reading;
  bool isLoading = false;
  String? error;
  int httpRequests = 0;
  bool _disposed = false;

  Future<void> refresh() async {
    if (_disposed || isLoading) return;
    isLoading = true;
    error = null;
    httpRequests++;
    notifyListeners();
    try {
      final next = await _repository.fetchLatest();
      if (_disposed) return;
      reading = next;
    } catch (e) {
      if (!_disposed) error = '조회 실패: $e';
    } finally {
      if (!_disposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _repository.dispose();
    super.dispose();
  }
}
