import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

// [S00] 서버에서 JSON을 가져오는 HTTP 통신 담당.
class SensorService {
  // 교수자가 알려준 IP:포트로 변경합니다. 10.0.2.2는 같은 PC의 Android 에뮬레이터용입니다.
  static const serverAddress = '10.0.2.2:8765';
  static const room = 'room01';
  final http.Client _client = http.Client();
  WebSocketChannel? _channel;

  Future<Map<String, dynamic>> fetchLatest() async {
    final url = Uri.parse('http://$serverAddress/api/snapshot?room=$room');
    final response = await _client.get(url);
    // 수업용: HTTP 상태 코드와 JSON 형식의 상세 검사는 생략합니다.
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // S01-①: WebSocket 메시지 수신을 준비합니다.
  Future<Stream<String>> openMessages() async {
    final url = Uri.parse('ws://$serverAddress/ws?room=$room');
    final channel = WebSocketChannel.connect(url);
    _channel = channel;
    await channel.ready;
    return channel.stream.cast<String>();
  }

  // S03-①: 사용자가 실시간 수신을 중지할 때 연결을 닫습니다.
  void closeSocket() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    closeSocket();
    _client.close();
  }
}
