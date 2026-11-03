# LAB08 센서 스트림 실습 (10주차)

Flutter `sensor_stream` 앱으로 **REST 한 번 조회 → WebSocket JSON 수신 → Provider 화면 갱신 → 실시간 중지**를 단계적으로 구현합니다. 처음 실행하는 `lib/`는 **S00 Starter**이며, 차트와 AI 게이지 실습은 포함하지 않았습니다.

## 폴더 구조

- `lib/` : 학생이 직접 수정할 S00 시작 코드. **항상 이 폴더의 `main.dart`를 실행**합니다.
- `checkpoints/S00~S03/lib/` : 큰 단계별 전체 코드 참고본 또는 복구용 소스. **독립 Flutter 프로젝트가 아닙니다.**
- `server/` : Python 모의 센서 서버와 웹 제어판.

| 단계 | 목표 | 실행 확인 |
|---|---|---|
| S00 | REST와 Provider 복습 | `한 번 조회`로 온도 변경 |
| S01 | WebSocket 연결, JSON 콘솔 출력 | 수신 횟수 증가, 온도 화면은 자동으로 갱신되지 않음 |
| S02 | JSON → `SensorReading`, `notifyListeners()` | 화면의 온도와 습도 자동 갱신 |
| S03 | 실시간 구독 및 소켓 중지 | 실시간 시작과 중지를 반복 |

## 1. Flutter 프로젝트 준비

[Flutter SDK](https://docs.flutter.dev/get-started/install), Android Studio, Android 에뮬레이터가 설치되어 있어야 합니다.
저장소에는 학습용 Dart 소스만 들어 있으므로, 최초 한 번 Flutter 플랫폼 파일을 생성합니다.

```powershell
git clone https://github.com/suseol/app08_sensor_stream.git
cd app08_sensor_stream
flutter create . --project-name sensor_stream --platforms=android
flutter pub get
```

**중요:** `checkpoints/S01/lib/main.dart`를 직접 실행하지 마세요. `android/`가 있는 **저장소 최상위 폴더**를 Android Studio로 열고 `lib/main.dart`만 실행합니다. 이미 Flutter 프로젝트가 구성되어 있다면 `flutter create`는 생략합니다.

## 2. 모의 서버 실행 (교수자 PC 또는 본인 PC)

프로젝트 최상위 폴더에서 별도 터미널을 엽니다. Python 3.11 이상 권장.

```powershell
py -m pip install -r server/requirements.txt
py server/mock_sensor_server.py --host 0.0.0.0
```

서버 포트는 `8765`입니다. `--host 0.0.0.0`은 다른 학생 PC의 접속을 허용하는 주소 바인딩이며, 접속 URL에는 `0.0.0.0`이 아닌 **서버 PC의 실제 IP**를 사용합니다.

서버 PC 브라우저에서 확인:

- JSON 응답: `http://127.0.0.1:8765/api/snapshot?room=room01`
- 서버 확인: `http://127.0.0.1:8765/health`
- 웹 제어판: `http://127.0.0.1:8765/`

교수자 PC의 IPv4 주소는 Windows `ipconfig`로 확인합니다. 학교망에서는 단말 간 통신 허용 및 Windows 방화벽의 TCP 8765 허용 여부를 확인하세요. **모의 서버에는 인증이 없으므로 공인 인터넷에 직접 노출하지 마세요.**

### Room별 변화

| Room | 온도 패턴 |
|---|---|
| `room01` | 약 22.5~27.5°C 사이 완만한 주기 변화 |
| `room02` | 약 5초마다 20.5°C와 30.5°C 부근을 오가는 급격한 변화 |
| `room03` | 약 8초마다 22, 26, 29, 24°C로 바뀌는 계단식 변화 |

같은 Room에 접속한 학생들은 같은 측정 데이터를 받습니다. 웹 제어판에서 Room을 선택하면 해당 방만 조작할 수 있습니다.

## 3. Flutter 앱의 서버 주소 설정

`lib/data/sensor_service.dart`의 **상수 두 개**를 수정합니다.

```dart
static const serverAddress = '10.0.2.2:8765';
static const room = 'room01';
```

- 본인 PC에서 서버와 **Android 에뮬레이터**를 함께 실행할 때: `10.0.2.2:8765`
- 교수자 PC에서 서버를 실행할 때: 예) `192.168.0.10:8765` (실제 교수자 PC IP로 변경)
- 앱의 REST URL: `http://서버IP:8765/api/snapshot?room=room01`
- 앱의 WebSocket URL: `ws://서버IP:8765/ws?room=room01`

이번 수업은 HTTP와 WS를 사용합니다. **Flutter Android 프로젝트에서** 인터넷 권한과 개발용 cleartext 허용을 확인하세요.

`android/app/src/main/AndroidManifest.xml` 파일의 `<manifest>` 아래에 다음을 추가합니다 (이미 존재하면 중복 추가하지 않음).

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

그리고 `<application>` 시작 태그에 다음 속성을 추가합니다.

```xml
android:usesCleartextTraffic="true"
```

이후 앱을 실행합니다.

```powershell
flutter run
```

## 4. 단계별 코딩과 체크포인트 활용

`lib/`를 S00부터 직접 수정합니다. 각 단계에서 현상 확인 후 다음 기능을 추가합니다.

완료본을 잠깐 실행하려면 작업 중인 `lib`를 **먼저 별도 폴더에 복사**한 다음, 해당 체크포인트의 `lib` 내부 파일을 루트 `lib`에 덮어씁니다. 예를 들어 PowerShell에서:

```powershell
Copy-Item .\lib .\lib_mywork -Recurse
Copy-Item .\checkpoints\S02\lib\* .\lib\ -Recurse -Force
flutter run
```

실습을 계속하려면 백업한 `lib_mywork` 내용을 `lib`에 다시 복사합니다. 체크포인트 폴더 자체를 프로젝트로 열지 않습니다. 단계별 패키지 의존성은 동일하므로 `pubspec.yaml`을 교체할 필요가 없습니다.

**수업 포인트:** S01에서는 JSON이 콘솔에 보이지만 화면 값은 변하지 않습니다. S02에서 `reading`과 `notifyListeners()`를 연결하면 REST 요청 횟수 증가 없이 화면 값이 갱신됩니다.
