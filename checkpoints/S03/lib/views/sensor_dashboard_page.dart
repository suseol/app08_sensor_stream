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
          // S03-③: 수신 중에는 중지 버튼으로 바뀝니다.
          OutlinedButton(
            onPressed: vm.isConnecting
                ? null
                : (vm.isStreaming ? vm.stopRealtime : vm.startRealtime),
            child: Text(vm.isConnecting
                ? '연결 중...'
                : (vm.isStreaming ? '실시간 중지' : '실시간 시작')),
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
