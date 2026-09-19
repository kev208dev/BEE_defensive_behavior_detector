# 벌통 지킴이 — 양봉장 말벌 집단 공격 조기 감지 시스템

2026 GovTech 경진대회 기술 구현 트랙 MVP.

일반 스마트폰 한 대를 벌통 앞에 고정해 **카메라와 마이크 센서**로 사용하고,
서버에서 Vision AI · Audio AI · Risk Engine으로 말벌 집단 공격 징후를 판단해
**양봉업자의 다른 스마트폰으로 경보를 전송**합니다.

별도의 sensor hardware, Raspberry Pi, IoT device를 사용하지 않습니다.

---

## 1. 서비스 개요

말벌(장수말벌 등)의 집단 공격은 짧은 시간에 벌통 하나를 궤멸시킵니다.
문제는 **공격이 시작된 순간을 아무도 보고 있지 않다**는 것입니다.

이 시스템은 그 공백을 메웁니다.

| 단계 | 내용 |
|---|---|
| 관찰 | 벌통 앞 스마트폰이 연속 camera stream에서 약 1초마다 표본을 골라 온디바이스 추론하고, 3초 단위 audio chunk를 전송 |
| 분석 | 스마트폰 Vision AI가 말벌 개체 수를, 서버 Audio AI가 말벌 음향 확률을 산출 |
| 판단 | Risk Engine이 최근 30초 관측 이력을 종합해 0~100 위험 점수 계산 |
| 경보 | NORMAL → CAUTION → DANGER 상태 전이 시점에만 Alert 생성 |
| 전달 | DANGER Alert 발생 시 관리자 스마트폰으로 Push, 탭하면 판단 근거 화면으로 이동 |

상태는 `NORMAL` · `CAUTION` · `DANGER` · `OFFLINE` 네 가지입니다.
`OFFLINE`은 위험 등급이 아니라 **관찰 스마트폰과 연결이 끊긴 상태**를 뜻하며,
heartbeat가 일정 시간 없으면 위험 점수와 무관하게 OFFLINE으로 표시됩니다.

---

## 2. Architecture

```
┌────────────────────────┐                      ┌────────────────────────┐
│   관찰용 스마트폰       │                      │  관리자 스마트폰        │
│   (Monitoring Mode)    │                      │   (Manager Mode)       │
│                        │                      │                        │
│  camera ──┐            │                      │   Dashboard            │
│  mic ─────┤            │                      │   Hive List / Detail   │
│           ▼            │                      │   Alert List / Detail  │
│  CameraService         │                      │           ▲            │
│  OnDeviceDetector      │                      │           │            │
│  AudioService          │                      │           │            │
│  ObservationUploadQueue│                      │   FCM Push   또는       │
│  HeartbeatService      │                      │   AlertWatcher 폴링     │
└──────────┬─────────────┘                      └───────────▲────────────┘
           │ JSON metadata + audio multipart                │
           │ POST /api/monitor/observation (~1 Hz)           │ Push / GET /api/alerts?since=
           │ POST /api/monitor/audio   (3s chunk)            │
           │ POST /api/monitor/heartbeat (10s)               │
           ▼                                                 │
┌──────────────────────────────────────────────────────────────────────────┐
│                          FastAPI Backend                                 │
│                                                                          │
│   ┌────────────────┐   ┌────────────────┐                                │
│   │ HornetDetector │   │ AudioClassifier│      ← 교체 가능한 인터페이스    │
│   │  mock / yolo   │   │ mock / librosa │                                │
│   └───────┬────────┘   └───────┬────────┘                                │
│           │ hornet_count       │ hornet_probability                      │
│           └──────────┬─────────┘                                         │
│                      ▼                                                   │
│            ┌───────────────────┐   AI 모델과 완전히 분리된 순수 모듈        │
│            │   Risk Engine     │   visual_count · persistence             │
│            │   0 ~ 100 score   │   · growth · audio 의 weighted sum       │
│            └─────────┬─────────┘                                         │
│                      ▼                                                   │
│            ┌───────────────────┐   상태 전이 기반 중복 경보 방지            │
│            │  Alert Manager    │   escalation only + recovery + cooldown  │
│            └─────────┬─────────┘                                         │
│                      ▼                                                   │
│            ┌───────────────────┐                                         │
│            │NotificationSender │   ← console / firebase                   │
│            └───────────────────┘                                         │
│                                                                          │
│   SQLModel + SQLite  ·  Hive / MonitoringDevice / VisionDetection /       │
│                         AudioDetection / Alert / PushDevice              │
└──────────────────────────────────────────────────────────────────────────┘
```

**설계 원칙 세 가지**

1. **AI와 판단 로직의 분리.** Risk Engine은 AI 라이브러리도 DB도 HTTP도 import하지 않습니다.
   관측값을 받아 점수를 돌려주는 순수 함수이므로, 모델을 바꿔도 판단 기준은 그대로입니다.
2. **Mock 우선.** YOLO weight, audio model, Firebase credential이 **하나도 없어도**
   전체 파이프라인이 동작합니다. 먼저 Mock으로 end-to-end를 완성하고 실제 모델을 붙입니다.
3. **UI와 business logic의 분리.** Figma 디자인이 도착하면 `theme/`과 `core/widgets/`,
   그리고 각 feature의 `presentation/`만 교체하면 됩니다. `domain/`·`data/`는 손대지 않습니다.

### Edge vision의 운영상 이점

모니터링 중에는 preview를 유지한 채 `startImageStream()`으로 들어오는 frame을 표본화하며,
still photo를 촬영하거나 JPEG를 만들지 않습니다. 따라서 셔터음이 없고 벌통 영상 원본이
기기 밖으로 나가지 않아 사생활 보호가 좋아집니다. 서버에는 수백 byte 수준의 탐지 metadata만
전송하므로 기존 수십 KB JPEG/초 방식보다 대역폭과 Railway 처리 비용이 크게 줄고, 네트워크
왕복 전에 결과를 볼 수 있어 지연도 낮습니다. 추론과 업로드는 각각 single-flight이며 바쁠 때는
오래된 frame/관측을 버려 장시간 실행해도 backlog가 쌓이지 않습니다.

---

## 3. Repository 구조

```
apps/
  mobile/                     Flutter 앱 (Monitoring / Manager 겸용)
    lib/
      app/                    app.dart · router.dart · theme/   ← Figma 교체 지점
      core/
        api/                  dio_client · api_client · endpoints · demo_data
        config/               app_config (dart-define) · mode_storage
        errors/               failure · error_mapper
        models/               freezed 도메인 모델
        widgets/              공용 컴포넌트 9종              ← Figma 교체 지점
        utils/                json_reader · formatters
      features/
        mode_selection/       역할 선택
        pairing/              QR·6자리 코드로 벌통 연결
        monitoring/           data / domain / presentation
        dashboard/            data / domain / presentation
        hives/                data / domain / presentation
        alerts/               data / domain / presentation
        settings/             data / domain / presentation
      main.dart
    test/                     flutter_test

services/
  backend/                    FastAPI + SQLModel + SQLite
    app/
      main.py config.py db.py models.py enums.py schemas.py
      api/                    health · hives · alerts · monitor · devices
                              · pairings · demo
      services/               risk_engine · alert_manager · hive_state
                              · pipeline · explanation · pairing · demo
      ai/                     detector · mock_detector · yolo_detector
                              · audio · mock_audio · librosa_audio · factory
      notifications/          sender · console · firebase · factory
    tests/                    pytest

data/samples/                 seed 데이터
scripts/                      run_backend.sh · run_tests.sh · demo_simulation.py
docs/                         API 명세 · Risk Engine 설명
```

---

## 4. 요구 사항

### Flutter

| 항목 | 버전 |
|---|---|
| Flutter | 3.47.5 (stable) 이상 |
| Dart | 3.13.4 이상 |
| Android | minSdk 21+ / compileSdk 34+ |
| iOS | 12.0 이상 |

주요 패키지: `flutter_riverpod` · `go_router` · `dio` · `freezed` · `json_serializable`
· `camera` · `record` · `image` · `permission_handler`
· `qr_flutter` · `mobile_scanner` (기기 페어링)
· `firebase_core` · `firebase_messaging` · `flutter_local_notifications`
· `shared_preferences`

### Python

| 항목 | 버전 |
|---|---|
| Python | 3.11 이상 |

필수: `fastapi` · `uvicorn` · `sqlmodel` · `pydantic` · `python-multipart` · `numpy` · `opencv-python-headless` · `pillow` · `pytest`

선택(실제 AI 모델 연결 시): `ultralytics` · `librosa` · `scikit-learn` · `firebase-admin`
→ `requirements-ai.txt`

---

## 5. Backend 실행

```bash
cd services/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

또는 한 줄로:

```bash
./scripts/run_backend.sh
```

확인:

```bash
curl http://127.0.0.1:8000/health
# {"status":"ok","detector_mode":"mock","audio_model_mode":"mock",
#  "notification_mode":"console", ...}
```

API 문서: <http://127.0.0.1:8000/docs>

> `--host 0.0.0.0` 이 중요합니다. 스마트폰은 `127.0.0.1`에 접근할 수 없으므로
> 서버가 LAN 인터페이스에서 수신해야 합니다.

### Database 초기화와 seed data

별도 명령이 필요 없습니다. 서버가 처음 뜰 때:

1. `SQLModel.metadata.create_all()` 로 테이블을 생성하고
2. DB가 비어 있으면 `data/samples/seed_hives.json` 의 벌통 4개를 넣습니다.

DB 파일은 `services/backend/beehive.db` 입니다.
완전히 초기화하려면 파일을 지우고 서버를 재시작하거나:

```bash
curl -X POST http://127.0.0.1:8000/api/demo/reset
```

---

## 6. Flutter 실행

```bash
cd apps/mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # freezed / json_serializable
flutter run
```

### Android

```bash
# 에뮬레이터: 10.0.2.2 가 호스트의 localhost 입니다 (기본값)
flutter run -d emulator-5554

# 실제 기기: PC의 LAN IP 를 지정합니다
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=http://192.168.0.10:8000
```

`usesCleartextTraffic="true"` 가 설정되어 있어 개발용 평문 HTTP가 동작합니다.
**실제 배포 시에는 반드시 제거하고 HTTPS를 사용해야 합니다.**

#### GitHub Actions로 APK 받기

로컬에 Android SDK가 없어도 됩니다. **Actions → Android debug APK → Run workflow**
를 누르거나, 작업 브랜치에 push하면 자동으로 실행됩니다.

워크플로는 `flutter pub get` → codegen → `flutter analyze` → `flutter test` →
`flutter build apk --debug` 순서로 진행하고, 결과물을
`beehive-guard-debug-apk` artifact로 업로드합니다. 내려받아 압축을 풀고
`adb install app-debug.apk` 또는 파일 전송으로 설치하면 됩니다.

**Firebase 설정 파일 없이 빌드됩니다.** `com.google.gms.google-services` Gradle
플러그인을 적용하지 않았기 때문에 `google-services.json` 이 빌드 입력이 아닙니다.
해당 파일이 없는 기기에서는 Firebase 초기화가 실패하고 `PushService` 가 이를
잡아내며, 관리자 폰은 폴링 fallback으로 경보를 받습니다 (§13 참고).

> `compileSdk` 는 `android/app/build.gradle.kts` 에 **36** 으로 고정되어 있고,
> 워크플로의 `ANDROID_COMPILE_SDK` 와 반드시 같은 값이어야 합니다.
>
> `permission_handler` 는 **12.x 로 고정**했습니다. 13.x 는
> `permission_handler_android` 14.x 를 끌어오는데 이 플러그인이 Android API 37로
> 컴파일되며, API 37은 stable SDK 채널에 아직 배포되지 않아 CI는 물론 일반
> 개발 PC에서도 빌드할 수 없습니다. 12.0.3 은 `permission_handler_android` 13.0.1
> (compileSdk 35)을 사용하고 이 앱이 쓰는 Dart API는 동일합니다.
> API 37이 정식 배포되면 두 값을 함께 올리면 됩니다.

### iOS

```bash
cd apps/mobile/ios && pod install && cd ..
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=http://192.168.0.10:8000
```

실제 기기에서는 Xcode에서 signing team 설정이 필요합니다.
카메라·마이크는 **시뮬레이터에서 동작하지 않으므로** 관찰 모드는 실제 기기로 테스트하세요.

> **서버 주소는 앱 화면에 노출되지 않습니다.** 일반 사용자는 주소를 입력하거나
> 볼 필요가 없고, 벌통 연결은 §6-1의 페어링 코드로 처리합니다. 개발 중에는
> `--dart-define=API_BASE_URL=...` 로만 바꾸며, debug 빌드의 설정 화면 맨 아래
> "개발자 정보"에 현재 주소가 읽기 전용으로 표시됩니다.

---

## 6-1. 기기 페어링 (벌통 연결)

관찰용 스마트폰은 **서버 주소를 입력하지 않습니다.** 관리자 폰이 발급한 코드로
벌통에 연결하며, 이 연결은 재시작해도 유지됩니다.

### 관리자 폰

```
Dashboard → 벌통 선택 → 벌통 상세 → "모니터링 기기 연결"
```

Bottom sheet에 다음이 표시됩니다.

- **QR 코드** — `beehiveguard://pair?code=482731` 형식의 deep link를 담습니다
- **6자리 숫자 코드** — `482 731` 처럼 읽기 쉽게 끊어서 표시
- **남은 유효시간** — `09:58` 카운트다운
- **연결 대기 상태** — 3초마다 polling하며, 연결되면 자동으로 "연결 완료"로 바뀝니다

코드가 만료되면 **새 코드 발급** 버튼이 나타납니다.

### 관찰용 폰

```
앱 실행 → 관찰 모드 → 자동으로 /pair 화면
```

두 가지 방법 중 하나를 쓰면 됩니다.

1. **QR 코드 스캔** — `mobile_scanner` 로 관리자 폰 화면을 비춥니다.
   우리 앱의 코드가 아니면 무시하므로 다른 QR을 비춰도 오류가 나지 않습니다.
2. **6자리 코드 입력** — 숫자 키패드로 입력하며, 6자리가 채워지면 자동 전송됩니다.

연결에 성공하면 `hiveId` · `hiveName` · `deviceId` 가 로컬에 저장되고
**벌통 선택 과정 없이** 바로 모니터링 설정 화면으로 이동합니다.
다음 실행부터는 코드를 다시 입력할 필요가 없습니다.

연결을 끊으려면 **설정 → 연결된 벌통 → 연결 해제** 를 누릅니다.

### 실패 사례별 안내

| 상황 | HTTP | 앱 표시 |
|---|---|---|
| 없는 코드 | 404 | 존재하지 않는 코드입니다. 다시 확인해주세요. |
| 만료된 코드 | 410 | 만료된 코드입니다. 새 코드를 발급받아주세요. |
| 이미 사용된 코드 | 409 | 이미 사용된 코드입니다. 새 코드를 발급받아주세요. |
| 시도 과다 | 429 | 시도 횟수가 너무 많습니다. 잠시 후 다시 시도해주세요. |

### 보안 (MVP 수준)

- 코드는 `secrets` 모듈로 생성합니다 (`random` 아님)
- TTL 10분, **1회용** — 한 번 claim되면 재사용 불가
- 활성 코드 사이에서 중복되지 않음
- claim endpoint는 클라이언트 주소 기준으로 **rate limit** (기본 5분에 10회).
  6자리는 100만 가지뿐이라 제한이 없으면 brute force가 가능합니다.
- 회원가입·로그인 시스템은 도입하지 않았습니다 (스펙 요구사항)

> **TODO:** rate limiter는 프로세스 메모리에 있어 worker가 여러 개면 창이 공유되지
> 않습니다. worker를 늘리기 전에 Redis나 테이블로 옮겨야 합니다
> (`app/services/pairing.py`의 `ClaimRateLimiter` 참고).

---

## 7. 환경 변수

### Backend (`services/backend/.env`, 전부 선택 사항)

전체 목록과 기본값은 `services/backend/.env.example` 에 있습니다.

| 변수 | 기본값 | 설명 |
|---|---|---|
| `DETECTOR_MODE` | `mock` | `mock` \| `yolo` |
| `YOLO_MODEL_PATH` | (없음) | `.pt` weight 경로 |
| `YOLO_CONFIDENCE_THRESHOLD` | `0.35` | 탐지 신뢰도 하한 |
| `YOLO_HORNET_CLASSES` | `hornet,wasp,vespa` | 말벌로 간주할 class 이름 |
| `AUDIO_MODEL_MODE` | `mock` | `mock` \| `librosa` |
| `AUDIO_MODEL_PATH` | (없음) | joblib 직렬화된 분류기 경로 |
| `NOTIFICATION_MODE` | `console` | `console` \| `firebase` |
| `FIREBASE_CREDENTIALS_PATH` | (없음) | service account JSON 경로 |
| `DATABASE_URL` | `sqlite:///./beehive.db` | |
| `PUBLIC_BASE_URL` | (없음) | 스냅샷 URL 생성용 절대 주소 |
| `RISK_WINDOW_SECONDS` | `30` | 분석 window 길이 |
| `AUDIO_FRESHNESS_SECONDS` | `20` | 이보다 오래된 audio는 무시 |
| `WEIGHT_VISUAL_COUNT` | `0.40` | 개체 수 가중치 |
| `WEIGHT_PERSISTENCE` | `0.25` | 지속성 가중치 |
| `WEIGHT_GROWTH` | `0.20` | 증가율 가중치 |
| `WEIGHT_AUDIO` | `0.15` | 음향 가중치 |
| `COUNT_SATURATION` | `6` | 개체 수 만점 기준 |
| `RECENT_MAX_BLEND` | `0.35` | 최근 최대값 반영 비율 |
| `GROWTH_SATURATION` | `0.30` | 증가율 만점 기준 (마리/초) |
| `PERSISTENCE_MIN_FRAMES` | `3` | 지속성 인정 최소 프레임 |
| `CAUTION_THRESHOLD` | `35` | CAUTION 기준 점수 |
| `DANGER_THRESHOLD` | `65` | DANGER 기준 점수 |
| `OFFLINE_AFTER_SECONDS` | `45` | heartbeat 없음 → OFFLINE |
| `ALERT_COOLDOWN_SECONDS` | `60` | 경보 최소 간격 |
| `ALERT_RECOVERY_SECONDS` | `120` | 동일 등급 재경보 대기 시간 |
| `ALERT_ON_CAUTION` | `true` | CAUTION에서도 Alert 생성 |

### Flutter (`--dart-define`)

| 변수 | 기본값 | 설명 |
|---|---|---|
| `API_BASE_URL` | Railway production URL | 백엔드 주소 (빌드 시에만 지정, 앱 UI에 없음) |
| `ANALYSIS_INTERVAL_MS` | `1000` | 연속 stream에서 추론할 표본 간격 (≈1 Hz) |
| `MODEL_MODE` | `mock` | 온디바이스 detector (`mock` / `tflite`) |
| `TFLITE_MODEL_ASSET` | `assets/models/hornet.tflite` | 실제 모델 asset 경로 |
| `MODEL_VERSION` | `hornet-tflite-v1` | observation에 기록할 모델 버전 |
| `AUDIO_CHUNK_SECONDS` | `3` | 오디오 청크 길이 |
| `HEARTBEAT_INTERVAL_SECONDS` | `10` | heartbeat 주기 |
| `ALERT_POLL_INTERVAL_SECONDS` | `10` | 경보 폴링 주기 |
| `DEMO_MODE` | `false` | 서버 없이 화면만 확인 |
| `ENABLE_FIREBASE` | `true` | Firebase 초기화 시도 |

---

## 8. Mock Mode — 아무것도 없이 실행하기

이 프로젝트에서 가장 중요한 성질입니다.
**YOLO weight도, audio model도, Firebase 설정도 없는 상태에서 전체가 동작합니다.**

```bash
# 기본값이 곧 mock mode 입니다. 추가 설정이 필요 없습니다.
cd services/backend && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- `DETECTOR_MODE=mock` — `MockHornetDetector`. 이미지 바이트 해시로 결정적인 개체 수를 산출하고,
  demo 시나리오가 주입되면 그 값을 순서대로 반환합니다.
- `AUDIO_MODEL_MODE=mock` — `MockAudioClassifier`. 0.05~0.35 대역의 환경음 수준 확률을 반환합니다.
- `NOTIFICATION_MODE=console` — `ConsoleNotificationSender`. 실제 push 대신 콘솔에 출력합니다.

`DETECTOR_MODE=yolo` 로 설정했는데 weight 파일이나 `ultralytics` 가 없으면,
**서버가 죽지 않고** 경고 로그를 남긴 뒤 mock으로 자동 fallback합니다.
Firebase도 동일합니다. 시연 도중 설정 하나가 빠져 전체가 멈추는 일이 없도록 한 설계입니다.

### Flutter Demo Mode

```bash
flutter run --dart-define=DEMO_MODE=true
```

repository가 in-memory 구현으로 교체되어 서버 없이 모든 화면을 볼 수 있습니다.
디자이너에게 빌드를 전달하거나 화면을 검토할 때 사용합니다.
다만 **실제 backend 연동이 기본 개발 목표**입니다.

---

## 9. Risk Engine

`services/backend/app/services/risk_engine.py`

최근 `RISK_WINDOW_SECONDS`(기본 30초) 관측 이력을 네 가지 지표로 환산해 가중 합산합니다.

| 지표 | 의미 | 기본 가중치 |
|---|---|---|
| `visual_count` | 현재 개체 수 + 최근 최대값 blend | 0.40 |
| `persistence` | window 내 말벌이 탐지된 프레임 비율 | 0.25 |
| `growth` | 개체 수 증가 속도 (마리/초) | 0.20 |
| `audio` | 음향 분석 말벌 확률 | 0.15 |

핵심 설계 포인트:

- **persistence gate** — `PERSISTENCE_MIN_FRAMES`(기본 3) 미만의 탐지는 지속성 점수가 크게 감쇄됩니다.
  정찰 말벌 한 마리가 스쳐 지나가는 것과 말벌이 벌통 앞에 눌러앉은 것을 구분하는 장치입니다.
- **recent max blend** — 프레임 한 장이 누락돼도 점수가 급락하지 않습니다.
- **growth는 증가만** — 개체 수가 줄어드는 상황은 0점이며 음수가 되지 않습니다.
- **audio 단독으로는 DANGER에 도달하지 않습니다.** 소리는 보강 근거이지 증거가 아닙니다.

### ⚠️ 임계값에 대한 중요한 고지

> **이 시스템의 가중치와 임계값(CAUTION 35, DANGER 65 등)은
> MVP 검증을 위한 heuristic이며, 과학적으로 검증된 실제 말벌 집단 공격 기준이 아닙니다.**
>
> 이 값들은 시연 시나리오에서 NORMAL → CAUTION → DANGER 전이가
> 명확히 드러나도록 선택되었습니다.
> 실제 양봉 현장에 적용하려면 실측 관측 데이터로 재도출해야 하며,
> 수의·곤충학 전문가의 검토가 필요합니다.
>
> 모든 가중치와 임계값은 코드 수정 없이 환경 변수로 변경할 수 있습니다.

---

## 10. 중복 경보 방지

1초에 한 프레임씩 올라오는 상황에서, DANGER 상태의 벌통은 아무 장치가 없으면
**1분에 60개의 경보**를 만들어냅니다. Alert는 프레임이 아니라 **사건(episode)** 을
나타내야 합니다.

`services/backend/app/services/alert_manager.py` 가 세 가지 규칙으로 이를 보장합니다.

1. **상태 승격 시에만 생성** — NORMAL → CAUTION, NORMAL/CAUTION → DANGER 전이에서만 Alert가 생깁니다.
   DANGER가 유지되는 동안에는 새 Alert가 생기지 않습니다. 하나의 공격 = 하나의 Alert.
2. **recovery window** — 동일 등급은 `ALERT_RECOVERY_SECONDS`(기본 120초)가 지나야 다시 발생합니다.
   신호가 깜빡이며 DANGER↔NORMAL을 오가도 한 건으로 묶입니다.
   충분히 시간이 지난 뒤의 새로운 공격은 정상적으로 새 Alert가 됩니다.
3. **cooldown** — 안전장치로 `ALERT_COOLDOWN_SECONDS`(기본 60초) 최소 간격을 둡니다.
   단, **등급이 올라가는 경우는 언제나 통과**합니다. 고조되는 위협이 타이머에 막히면 안 됩니다.

Push는 **DANGER Alert에 대해서만** 전송됩니다. CAUTION은 앱에 기록·표시되지만
양봉업자를 깨우지는 않습니다.

---

## 11. API

| Method | Path | 설명 |
|---|---|---|
| GET | `/health` | 상태 + 현재 활성화된 adapter 확인 |
| GET | `/api/hives` | 벌통 목록 |
| GET | `/api/dashboard` | 상태별 집계 + 벌통 + 최근 경보 (관리자 홈 1회 호출) |
| GET | `/api/hives/{id}` | 벌통 상세 |
| GET | `/api/hives/{id}/status` | 벌통 상태 (경량 폴링용, breakdown 포함) |
| GET | `/api/alerts` | 경보 목록 (`hive_id`, `severity`, `since`, `limit`) |
| GET | `/api/alerts/{id}` | 경보 상세 (판단 근거 포함) |
| POST | `/api/monitor/frame` | 프레임 업로드 (multipart) |
| POST | `/api/monitor/observation` | 온디바이스 탐지 metadata 업로드 (JSON, 기본 경로) |
| POST | `/api/monitor/audio` | 오디오 청크 업로드 (multipart) |
| POST | `/api/monitor/heartbeat` | 관찰 스마트폰 생존 신호 |
| POST | `/api/pairings` | 페어링 코드 발급 (관리자) |
| GET | `/api/pairings/{id}` | 페어링 상태 polling (관리자) |
| POST | `/api/pairings/claim` | 코드 사용해 연결 (관찰 기기) |
| POST | `/api/devices` | 관찰 기기 등록 |
| POST | `/api/devices/push-token` | FCM 토큰 등록 |
| POST | `/api/demo/reset` | 모든 관측·경보 삭제 후 재seed |
| POST | `/api/demo/simulate` | 시나리오 즉시 재생 |
| POST | `/api/demo/observe` | 관측 1건 주입 (실시간 재생용) |
| POST | `/api/demo/script` | mock detector에 시나리오 예약 (실제 카메라 경로 시연용) |
| POST | `/api/demo/create-alert` | DANGER Alert 강제 생성 + push |

`/api/demo/*` 는 **`DEBUG=true` 일 때만** 등록됩니다. 인증이 없고 `reset` 은
페어링 세션까지 전부 지우므로, production(`DEBUG=false`)에서는 mount하지 않고
404를 반환합니다.

상세 요청/응답 스키마는 [`docs/api.md`](docs/api.md) 또는
서버 실행 후 <http://127.0.0.1:8000/docs> 를 참고하세요.

주요 응답 예시:

```jsonc
// POST /api/monitor/observation 요청 (이미지 없음)
{
  "hive_id": "hive-a",
  "device_id": "phone-abc123",
  "timestamp": "2026-09-19T12:00:00Z",
  "hornet_count": 2,
  "max_confidence": 0.87,
  "detections": [
    {"confidence": 0.87, "x": 0.1, "y": 0.2, "width": 0.3, "height": 0.4, "class_name": "hornet"},
    {"confidence": 0.81, "x": 0.5, "y": 0.3, "width": 0.2, "height": 0.3, "class_name": "hornet"}
  ],
  "inference_ms": 38,
  "model_version": "mock-v1"
}

// 응답 (`/frame`과 같은 위험도 계약)
{
  "status": "CAUTION",
  "risk_score": 44,
  "hornet_count": 2,
  "confidence": 0.87,
  "processed_at": "2026-09-19T12:00:00",
  "max_hornet_count": 2,
  "audio_probability": 0.2,
  "snapshot_url": null,
  "alert_id": "9f2c..."      // 이 관측이 경보를 유발한 경우에만
}

// POST /api/monitor/audio
{ "hornet_probability": 0.31, "processed_at": "2026-09-19T12:00:00" }
```

---

## 12. 권한 설정

### Android — `android/app/src/main/AndroidManifest.xml` (설정 완료)

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

### iOS — `ios/Runner/Info.plist` (설정 완료)

```xml
<key>NSCameraUsageDescription</key>
<string>벌통 앞 상황을 촬영해 말벌 집단 공격 징후를 분석하기 위해 카메라를 사용합니다.</string>
<key>NSMicrophoneUsageDescription</key>
<string>벌통의 날갯짓 소리를 분석해 말벌 위험을 감지하기 위해 마이크를 사용합니다.</string>
```

런타임 권한은 `permission_handler` 로 모니터링 설정 화면에서 요청합니다.
**권한이 거부되어도 앱은 절대 crash하지 않습니다.**
카메라 권한이 없으면 모니터링 시작 버튼이 비활성화되고 안내가 표시되며,
마이크 권한이 없으면 **영상 분석만으로 계속 동작**합니다.
"다시 묻지 않음"으로 거부된 경우 설정 화면을 여는 버튼이 나타납니다.

---

## 13. Firebase 설정 (선택 사항)

**Firebase 없이도 전체 시연이 가능합니다.** 아래는 실제 FCM push를 쓸 때만 필요합니다.

### 왜 선택 사항인가

관리자 앱에는 두 가지 전달 경로가 있습니다.

1. **FCM push** — 제품의 정식 경로.
2. **폴링 fallback** — `AlertWatcher` 가 `GET /api/alerts?since=` 를 주기적으로 조회해
   새 DANGER 경보를 발견하면 `flutter_local_notifications` 로 로컬 알림을 띄웁니다.

두 경로는 alert id 기준으로 중복이 제거되므로 동시에 켜두어도 알림이 두 번 오지 않습니다.
Firebase 설정이 늦어지거나 시연장 네트워크에 문제가 생겨도 데모가 성립합니다.

### 설정 절차

1. [Firebase Console](https://console.firebase.google.com) 에서 프로젝트 생성
2. **Android 앱 추가** — package name `kr.ainuri.beehive.beehive_guard`
   → `google-services.json` 을 `apps/mobile/android/app/` 에 배치
3. **iOS 앱 추가** — bundle id 동일
   → `GoogleService-Info.plist` 를 Xcode로 `Runner` 타겟에 추가
4. Android Gradle 플러그인 추가:
   ```groovy
   // android/settings.gradle.kts 의 plugins 블록
   id("com.google.gms.google-services") version "4.4.2" apply false
   // android/app/build.gradle.kts 의 plugins 블록
   id("com.google.gms.google-services")
   ```
5. **서버 키 발급** — 프로젝트 설정 → 서비스 계정 → 새 비공개 키 생성
6. 백엔드 설정:
   ```bash
   export NOTIFICATION_MODE=firebase
   export FIREBASE_CREDENTIALS_PATH=/path/to/service-account.json
   pip install -r requirements-ai.txt   # firebase-admin 포함
   ```

> `google-services.json` 과 service account 키는 `.gitignore` 에 등록되어 있습니다.
> **절대 저장소에 커밋하지 마세요.**

Push payload는 `alertId` · `hiveId` · `severity` · `route` 를 담으며,
탭하면 `/alerts/:id` 로 deep link 됩니다 (foreground / background / terminated 모두 처리).

---

## 14. 실제 YOLO 모델 연결

MVP는 mock detector로 동작하지만, 실제 모델을 붙이는 데 코드 수정이 필요 없습니다.

```bash
pip install -r requirements-ai.txt        # ultralytics

export DETECTOR_MODE=yolo
export YOLO_MODEL_PATH=/path/to/hornet_yolov8.pt
export YOLO_CONFIDENCE_THRESHOLD=0.35
export YOLO_HORNET_CLASSES=hornet,wasp,vespa
```

**모델 학습 시 참고:**

- 단일 클래스(말벌만) 모델이면 class 이름이 무엇이든 모든 탐지를 말벌로 간주합니다.
- 다중 클래스 모델이면 `YOLO_HORNET_CLASSES` 에 포함된 class만 집계합니다.
- 벌통 입구를 향한 고정 카메라 시점의 데이터로 학습하는 것이 가장 효과적입니다.
- 꿀벌과 말벌의 구분이 핵심이므로, 꿀벌을 negative class로 충분히 포함시키세요.

`YoloHornetDetector` 는 프레임 디코딩 실패나 추론 예외를 "탐지 없음"으로 처리합니다.
손상된 프레임 한 장이 모니터링 전체를 중단시키지 않도록 한 설계입니다.

---

## 15. 실제 Audio 모델 연결

```bash
pip install -r requirements-ai.txt        # librosa, scikit-learn

export AUDIO_MODEL_MODE=librosa
export AUDIO_MODEL_PATH=/path/to/audio_model.joblib
```

`LibrosaAudioClassifier` 가 기대하는 feature vector:

| 항목 | 값 |
|---|---|
| sample rate | 22050 Hz |
| MFCC 계수 | 20개 |
| feature 순서 | `mfcc_mean_0..19` → `mfcc_std_0..19` → `spectral_centroid_mean` → `zero_crossing_rate_mean` |
| feature 길이 | 42 |
| positive class index | 1 (= 말벌 존재) |
| 직렬화 | `joblib.dump(classifier, 'audio_model.joblib')` |

`app/ai/librosa_audio.py` 의 `describe_training_recipe()` 가 같은 정보를 코드로 반환합니다.
말벌은 꿀벌보다 날갯짓 주파수가 낮으므로 저주파 대역의 에너지 분포가 유효한 신호입니다.

---

## 16. 테스트 실행

```bash
# 전체
./scripts/run_tests.sh

# Backend만
cd services/backend && ./.venv/bin/python -m pytest -v

# Flutter만
cd apps/mobile && flutter analyze && flutter test
```

현재 상태: **backend 99 tests · Flutter 93 tests 통과, `flutter analyze` 이슈 0건.**

### Risk Engine 테스트가 검증하는 것

임계값 숫자가 아니라 **행동(behavior)** 을 단언합니다. 임계값은 설정이므로,
숫자를 고정하면 테스트만 깨지기 쉬워지고 실제로 강해지지는 않습니다.

| 시나리오 | 기대 동작 |
|---|---|
| 말벌 0마리 | NORMAL |
| 1마리가 잠깐 출현 | DANGER로 가지 않음 · 사라지면 점수 하락 |
| 3~5마리가 여러 프레임 지속 | CAUTION 이상 |
| 개체 수 급증 | 동일 개체 수의 평탄한 경우보다 높은 점수 |
| visual + audio 동시 상승 | 각각 단독보다 높은 점수 |
| heartbeat 없음 | OFFLINE (위험 점수와 무관하게 우선) |

그 외에 단조성(개체 수·음향 확률이 오르면 점수도 오른다), window 밖 관측 무시,
가중치·임계값 변경이 실제로 판정을 바꾸는지, 프레임이 순서 없이 도착해도 같은 결과인지를 검증합니다.

### Flutter 테스트가 검증하는 것

- **camera image stream** — still photo 촬영 호출 없음, 플랫폼별 안전한 pixel format, 표본 간격 준수.
- **온디바이스 추론** — 동시에 한 건만 실행하고 busy 중 frame drop. UI isolate 밖에서 전처리·TFLite 추론.
- **`ObservationUploadQueue`** — 단일 업로드 유지, 오래된 관측 drop, 최신값 우선, 업로드 실패 후에도 모니터링 지속.
- **JSON 파싱** — 필드 누락·타입 불일치·파싱 불가 timestamp에도 예외가 발생하지 않음.
- **공용 컴포넌트** — 각 컴포넌트의 표시·콜백 계약. Figma 교체 후에도 같은 테스트로 검증 가능합니다.
- **화면 이동** — repository를 fixture로 교체한 상태에서 역할 선택 → 대시보드 → 상세까지 전체 흐름.

---

## 17. Demo 실행

경진대회에 실제 말벌을 가져갈 수 없으므로 **시뮬레이션은 필수 기능**입니다.
아래 모든 방식이 **실제 Risk Engine과 Alert 상태 기계를 그대로 통과**합니다.
하드코딩된 애니메이션이 아닙니다.

```bash
# 1) 즉시 재생 — 타임라인 전체를 한 번에 계산
python3 scripts/demo_simulation.py --hive-id hive-a

# 2) 실시간 재생 — 1초에 한 관측씩, 점수가 올라가는 것을 보여줄 때
python3 scripts/demo_simulation.py --hive-id hive-a --live

# 3) 관리자 폰 진동만 확인
python3 scripts/demo_simulation.py --hive-id hive-a --create-alert
```

### 시나리오

| 시각 | 말벌 수 | 음향 확률 | 상태 |
|---|---|---|---|
| t=0 | 0 | 0.05 | NORMAL |
| t=5 | 1 | 0.10 | NORMAL |
| t=10 | 2 | 0.20 | **CAUTION** (경보 발생) |
| t=15 | 4 | 0.30 | CAUTION |
| t=20 | 6 | 0.85 | **DANGER** (경보 + Push) |

실행 결과 예시:

```
Backend OK — detector=mock audio=mock notifications=console

Replaying the scripted attack on 'hive-a'...

  t=  0.0s  hornets=0   risk=  1  NORMAL
  t=  5.0s  hornets=1   risk= 17  NORMAL
  t= 10.0s  hornets=2   risk= 44  CAUTION   ← ALERT
  t= 15.0s  hornets=4   risk= 62  CAUTION
  t= 18.0s  hornets=4   risk= 65  DANGER    ← ALERT
  t= 20.0s  hornets=6   risk= 89  DANGER

Alerts created: 2  Notifications sent: 0
```

**21개 프레임을 처리했지만 Alert는 2건입니다.** 중복 경보 방지가 동작한다는 증거입니다.

`Notifications sent` 는 등록된 관리자 기기 수를 셉니다.
관리자 앱이 아직 push token을 등록하지 않았다면 0으로 표시되며,
`ConsoleNotificationSender` 는 그와 무관하게 백엔드 콘솔에 경보 내용을 출력합니다.

시뮬레이션은 실제 camera monitoring 경로와 독립적으로 유지되며,
`--live` 를 제외하면 즉시 완료되어 대시보드가 바로 DANGER를 보여줍니다.

---

## 18. 경진대회 시연 절차

### 사전 준비 (시연 30분 전)

```bash
# 1. 노트북 IP 확인
hostname -I

# 2. 백엔드 실행
./scripts/run_backend.sh

# 3. 정상 동작 확인
python3 scripts/demo_simulation.py --hive-id hive-a
curl http://127.0.0.1:8000/api/alerts

# 4. 상태 초기화
curl -X POST http://127.0.0.1:8000/api/demo/reset
```

두 스마트폰을 노트북과 **같은 Wi-Fi**에 연결하고, 각각 빌드합니다.

```bash
# 관찰용 스마트폰
flutter run -d <monitor-device> --dart-define=API_BASE_URL=http://<노트북IP>:8000

# 관리자 스마트폰
flutter run -d <manager-device> --dart-define=API_BASE_URL=http://<노트북IP>:8000
```

### 시연 흐름

**관리자 스마트폰 — 먼저 벌통을 연결합니다**

0. 앱 실행 → **관리자 모드** → **벌통 A** → **모니터링 기기 연결**
   → QR 코드와 6자리 코드가 표시됩니다

**관찰용 스마트폰 (벌통 앞 삼각대에 고정)**

1. 앱 실행 → **관찰 모드** 선택
2. QR 코드를 스캔하거나 6자리 코드 입력 → 자동으로 벌통 A에 연결
3. 카메라·마이크 권한 허용
4. 서버 연결 상태가 초록색인지 확인
5. **모니터링 시작**
6. 카메라 앞에서 준비한 말벌 영상 재생
   - (mock detector 사용 시) 노트북에서 `--script-camera` 실행
   - (실제 YOLO 사용 시) 영상만 재생하면 됩니다
7. 화면에서 실시간 변화 확인:
   `말벌 수 0 → 1 → 2 → 4 → 6` · `위험 점수 상승` · `NORMAL → CAUTION → DANGER`

**관리자 스마트폰 (심사위원에게 보여주는 화면)**

8. 알림 수신 — **"벌통 A에서 말벌 집단 공격 징후가 감지되었습니다."**
9. 알림 탭 → **경보 상세** 화면으로 deep link
10. 판단 근거 확인:
    > "현재 말벌 4마리가 탐지되었고 최근 30초 내 최대 4마리까지 관측되었습니다,
    > 최근 분석 프레임의 74%에서 말벌이 연속적으로 확인되어 일시적인 통과가 아닌
    > 지속적인 체류로 판단됩니다, 말벌 개체 수가 초당 약 0.24마리 속도로 빠르게
    > 증가하고 있습니다, 음향 분석에서 말벌 관련 신호가 30% 확률로 함께 감지되었습니다.
    > 집단 공격 가능성이 높아 즉시 확인이 필요합니다."

    (위 문구는 `demo_simulation.py` 기본 시나리오의 실제 출력입니다. 경보는 DANGER에
    진입하는 **순간**에 생성되므로, 시나리오 끝의 6마리가 아니라 그 시점의 값이 기록됩니다.)
11. 탐지 스냅샷과 측정값(위험 점수·개체 수·지속성·증가 속도·음향 위험도) 확인

### 강조할 포인트

- **추가 하드웨어가 0원입니다.** 쓰지 않는 구형 스마트폰이 곧 센서입니다.
- **판단 근거를 사람이 읽을 수 있습니다.** LLM 호출 없이 Risk Engine 결과로 생성됩니다.
- **경보가 스팸이 되지 않습니다.** 21프레임 → 2건. 상태 전이 기반 설계입니다.
- **모델이 교체 가능합니다.** mock ↔ YOLO가 환경 변수 하나 차이입니다.

### 문제 발생 시 대비책

| 증상 | 대응 |
|---|---|
| 스마트폰이 서버에 연결되지 않음 | 같은 Wi-Fi인지 확인 후 `--dart-define=API_BASE_URL=...` 로 재빌드 |
| 페어링 코드가 만료됨 | 관리자 폰에서 **새 코드 발급** |
| Wi-Fi 불안정 | `python3 scripts/demo_simulation.py --live` 로 노트북 화면만으로 시연 |
| Push가 오지 않음 | 폴링 fallback이 최대 10초 내 로컬 알림을 띄웁니다 |
| 카메라가 말벌을 못 잡음 | `--script-camera` 로 시나리오 예약 |
| 상태가 꼬임 | `curl -X POST .../api/demo/reset` 후 재시작 |

---

## 19. 현재 Mock으로 남아 있는 부분

| 영역 | 현재 | 실제 연결 방법 |
|---|---|---|
| 말벌 탐지 | `MockHornetDetector` (해시 기반 결정적 값) | §14 — 학습된 YOLO weight |
| 음향 분류 | `MockAudioClassifier` (환경음 수준 확률) | §15 — 학습된 scikit-learn 모델 |
| Push 전송 | `ConsoleNotificationSender` (콘솔 출력) | §13 — Firebase service account |

인터페이스(`HornetDetector` · `AudioClassifier` · `NotificationSender`)는 이미 확정되어 있으므로,
세 가지 모두 **애플리케이션 코드 수정 없이 환경 변수만으로** 교체됩니다.

---

## 20. 알려진 제약

- **Background camera capture는 구현하지 않았습니다.** 화면이 켜진 상태에서 동작하는 것이
  MVP 목표입니다. 관찰용 스마트폰은 충전기를 연결하고 화면 꺼짐을 해제해 두세요.
- **실시간 영상 스트리밍이 없습니다.** 의도된 설계입니다 (WebRTC·RTMP 미사용, 약 1 FPS).
- **인증 체계가 없습니다.** MVP 범위 밖입니다. 신뢰된 로컬 네트워크를 전제합니다.
- **평문 HTTP를 사용합니다.** 개발 편의를 위한 것이며 실제 배포 시 HTTPS가 필요합니다.
- **SQLite 단일 파일 DB입니다.** 벌통 수십 개 규모까지는 충분하지만 그 이상은 PostgreSQL이 필요합니다.
- **스냅샷이 무한히 쌓입니다.** 장기 운영 시 정리 작업이 필요합니다.
- **`beehiveguard://` deep link는 앱 내 스캐너에서만 처리합니다.** OS에 URL scheme을
  등록하지 않았으므로 기본 카메라 앱으로 QR을 찍으면 앱이 열리지 않습니다.
  등록하려면 별도 deep link 패키지가 필요해, 스펙의 "과도한 패키지 추가 금지"에
  따라 보류했습니다.
- **페어링 rate limiter가 프로세스 메모리에 있습니다.** worker를 여러 개 띄우면
  제한 창이 공유되지 않습니다. §6-1의 TODO를 참고하세요.
- **임계값이 검증되지 않았습니다.** §9의 고지를 반드시 함께 읽어 주세요.

---

## 21. Figma 디자인 적용 준비

디자인이 도착했을 때 **business logic을 전혀 건드리지 않고** 교체할 수 있도록 구성되어 있습니다.

### 교체 지점 (딱 두 곳)

```
lib/app/theme/tokens.dart      colors · typography · spacing · radius
lib/core/widgets/              AppButton · StatusBadge · HiveCard · AlertCard
                               MetricCard · ConnectionBadge · SectionHeader
                               EmptyState · ErrorState
```

각 feature의 `presentation/` 도 자유롭게 교체 가능합니다.

### 지켜지고 있는 규칙

- 화면 위젯 안에 HTTP 요청 코드가 없습니다 — 전부 `ApiClient` 와 repository를 거칩니다.
- 화면 위젯 안에 camera / audio 코드가 없습니다 — `CameraService` · `AudioService` 가 소유합니다.
- `domain/` · `data/` 레이어는 `theme/` 도 `widgets/` 도 import하지 않습니다.
- 모든 색상·치수는 token을 통해서만 사용합니다. 하드코딩된 값이 없습니다.
- 상태별 색상 매핑은 `statusColor()` 한 곳에만 존재합니다.

### 검증 방법

공용 컴포넌트 테스트(`test/widgets/components_test.dart`)는 **표시 내용과 콜백 계약**을
검증하므로, 디자인을 바꾼 뒤에도 같은 테스트가 그대로 통과해야 합니다.
통과한다면 로직이 깨지지 않았다는 뜻입니다.

---

## 22. 라이선스 / 문의

2026 GovTech 경진대회 출품작입니다.
