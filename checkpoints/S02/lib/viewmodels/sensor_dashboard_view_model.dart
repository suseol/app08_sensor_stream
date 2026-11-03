import 'dart:async';
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

  StreamSubscription<SensorReading>? _subscription;
  bool isConnecting = false;
  bool isStreaming = false;
  int wsMessages = 0;

  // S02-②: 새로운 SensorReading을 상태에 반영하면 Provider가 화면을 갱신합니다.
  Future<void> startRealtime() async {
    if (_disposed || isConnecting || isStreaming) return;
    isConnecting = true;
    error = null;
    notifyListeners();
    try {
      final readings = await _repository.watchReadings();
      if (_disposed) return;
      _subscription = readings.listen(
        (next) {
          if (_disposed) return;
          reading = next;
          wsMessages++;
          notifyListeners();
        },
        onError: (Object e) {
          if (_disposed) return;
          error = '수신 오류: $e';
          isStreaming = false;
          notifyListeners();
        },
        onDone: () {
          if (_disposed) return;
          isStreaming = false;
          notifyListeners();
        },
      );
      isStreaming = true;
    } catch (e) {
      if (!_disposed) error = '연결 실패: $e';
    } finally {
      if (!_disposed) {
        isConnecting = false;
        notifyListeners();
      }
    }
  }

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
    _subscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
