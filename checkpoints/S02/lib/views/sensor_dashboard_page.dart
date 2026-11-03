import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/sensor_service.dart';
import '../viewmodels/sensor_dashboard_view_model.dart';

// [S00] 화면 꾸미기는 제공하고 데이터 흐름에 집중합니다.
class SensorDashboardPage extends StatelessWidget {
  const SensorDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SensorDashboardViewModel>();
    final reading = vm.reading;
    return Scaffold(
      appBar: AppBar(title: const Text('실시간 센서 실습')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('모의 방 센서 / ${SensorService.room}'),
          const SelectableText('http://${SensorService.serverAddress}'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: vm.isLoading ? null : vm.refresh,
            child: const Text('한 번 조회'),
          ),
          Text('HTTP 요청: ${vm.httpRequests}회'),
          const SizedBox(height: 8),
          // S01-④: 시작만 연결하고 중지 버튼은 나중에 구현합니다.
          OutlinedButton(
            onPressed: (vm.isConnecting || vm.isStreaming)
                ? null
                : vm.startRealtime,
            child: Text(vm.isConnecting ? '연결 중...' : '실시간 시작'),
          ),
          Text('WebSocket 수신: ${vm.wsMessages}개'),
          if (vm.isLoading) const LinearProgressIndicator(),
          if (vm.error != null)
            Text(vm.error!, key: const Key('errorText')),
          const SizedBox(height: 16),
          Text(
            reading == null ? '아직 데이터가 없습니다.'
                : '${reading.temperature.toStringAsFixed(1)} °C',
            style: Theme.of(context).textTheme.headlineLarge,
            key: const Key('temperatureText'),
          ),
          if (reading != null) ...[
            Text('습도: ${reading.humidity.toStringAsFixed(1)} %'),
            Text('서버 순번: ${reading.sequence}'),
            Text('측정 시각: ${reading.recordedAt.toLocal()}'),
          ],
        ],
      ),
    );
  }
}
