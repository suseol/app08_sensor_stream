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

  StreamSubscription<String>? _subscription;
  bool isConnecting = false;
  bool isStreaming = false;
  int wsMessages = 0;

  // S01-③: WebSocket JSON 메시지를 콘솔에 출력합니다. 화면 센서값은 아직 바뀌지 않습니다.
  Future<void> startRealtime() async {
    if (_disposed || isConnecting || isStreaming) return;
    isConnecting = true;
    error = null;
    notifyListeners();
    try {
      final messages = await _repository.openMessages();
      if (_disposed) return;
      _subscription = messages.listen(
        (raw) {
          if (_disposed) return;
          debugPrint('WebSocket JSON: $raw');
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
