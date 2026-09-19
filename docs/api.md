# API 명세

Base URL: `http://<host>:8000`
대화형 문서: `http://<host>:8000/docs`

모든 timestamp는 **naive UTC ISO-8601** 입니다 (예: `2026-09-19T12:00:00`).
Flutter 앱은 zone designator가 없는 값을 UTC로 해석합니다.

---

## Health

### `GET /health`

현재 활성화된 adapter를 함께 반환하므로, 시연 전 설정 확인에 사용합니다.

```json
{
  "status": "ok",
  "detector_mode": "mock",
  "audio_model_mode": "mock",
  "notification_mode": "console",
  "version": "0.1.0",
  "server_time": "2026-09-19T12:00:00"
}
```

---

## Hives

### `GET /api/hives`

모든 벌통. 읽을 때마다 상태를 재평가하므로, heartbeat가 끊긴 벌통은
별도의 백그라운드 작업 없이 `OFFLINE` 으로 전환됩니다.

```json
[
  {
    "id": "hive-a",
    "name": "벌통 A",
    "location": "1구역 동편",
    "status": "DANGER",
    "risk_score": 89,
    "hornet_count": 6,
    "max_hornet_count": 6,
    "audio_probability": 0.85,
    "last_updated": "2026-09-19T12:00:00",
    "monitoring_online": true,
    "last_heartbeat": "2026-09-19T11:59:55"
  }
]
```

### `GET /api/dashboard`

관리자 홈이 1회 호출로 필요한 전부를 받습니다.

```json
{
  "total": 4, "normal": 1, "caution": 1, "danger": 1, "offline": 1,
  "hives": [ /* HiveSummary[] */ ],
  "recent_alerts": [ /* AlertSummary[] */ ]
}
```

### `GET /api/hives/{id}`

`HiveSummary` 의 모든 필드에 더해:

```json
{
  "last_analyzed_at": "2026-09-19T12:00:00",
  "latest_snapshot_url": "/static/snapshots/hive-a_20260919120000_ab12cd34.jpg",
  "persistence_ratio": 0.76,
  "growth_per_second": 0.26,
  "camera_ok": true,
  "microphone_ok": true,
  "monitoring": true,
  "status_reason": "현재 6마리 탐지, 최근 최대 6마리, 음향 위험도 85%.",
  "recent_alerts": [ /* AlertSummary[] */ ]
}
```

### `GET /api/hives/{id}/status`

경량 폴링용. Risk Engine의 sub-score breakdown을 포함합니다.

```json
{
  "hive_id": "hive-a",
  "status": "DANGER",
  "risk_score": 89,
  "hornet_count": 6,
  "max_hornet_count": 6,
  "audio_probability": 0.85,
  "monitoring_online": true,
  "last_heartbeat": "2026-09-19T11:59:55",
  "last_analyzed_at": "2026-09-19T12:00:00",
  "status_reason": "현재 6마리 탐지, 최근 최대 6마리, 음향 위험도 85%.",
  "breakdown": {
    "visual_count_score": 100.0,
    "persistence_score": 76.19,
    "growth_score": 88.02,
    "audio_score": 85.0,
    "current_hornet_count": 6,
    "recent_max_hornet_count": 6,
    "persistence_ratio": 0.762,
    "growth_per_second": 0.264,
    "audio_probability": 0.85,
    "frames_considered": 21
  }
}
```

---

## Alerts

### `GET /api/alerts`

| 쿼리 | 설명 |
|---|---|
| `hive_id` | 특정 벌통으로 한정 |
| `severity` | `CAUTION` \| `DANGER` |
| `since` | 이 시각보다 **엄격히 나중**인 경보만. 관리자 앱의 폴링 fallback이 사용합니다 |
| `limit` | 기본 50, 최대 200 |

최신순으로 반환합니다.

```json
[
  {
    "id": "9f2c...",
    "hive_id": "hive-a",
    "hive_name": "벌통 A",
    "timestamp": "2026-09-19T12:00:00",
    "severity": "DANGER",
    "risk_score": 89,
    "hornet_count": 6,
    "message": "벌통 A에서 말벌 집단 공격 징후가 감지되었습니다."
  }
]
```

### `GET /api/alerts/{id}`

`AlertSummary` 에 더해 판단 근거와 측정값:

```json
{
  "max_hornet_count": 6,
  "audio_probability": 0.85,
  "persistence_ratio": 0.762,
  "growth_per_second": 0.264,
  "thumbnail_url": "/static/snapshots/...",
  "clip_url": null,
  "explanation": "현재 말벌 6마리가 탐지되었고 ... 즉시 확인이 필요합니다.",
  "resolved_at": null
}
```

---

## Monitoring uploads

### `POST /api/monitor/observation`

기본 vision 경로입니다. 카메라 원본은 기기에 남고 온디바이스 추론 metadata만 JSON으로 전송합니다.

```json
{
  "hive_id": "hive-a",
  "device_id": "phone-abc123",
  "timestamp": "2026-09-19T12:00:00Z",
  "hornet_count": 1,
  "max_confidence": 0.91,
  "detections": [
    {
      "confidence": 0.91,
      "x": 0.1,
      "y": 0.2,
      "width": 0.3,
      "height": 0.4,
      "class_name": "hornet"
    }
  ],
  "inference_ms": 37,
  "model_version": "mock-v1"
}
```

좌표는 0~1 정규화 값이며 bounding box는 frame 안에 있어야 합니다. `hornet_count`는
`detections` 길이와 같아야 하고, 탐지가 없으면 `max_confidence`는 0입니다. 응답은 아래
`/frame` 응답과 동일하지만 이미지가 없으므로 `snapshot_url`은 `null`입니다. 저장된 관측은
기존 persistence/growth/audio fusion/risk/alert 파이프라인을 그대로 통과합니다.

### `POST /api/monitor/frame`

이전 앱과의 호환을 위해 유지하는 legacy 경로입니다. 새 monitoring 앱은 사용하지 않습니다.

`multipart/form-data`

| 필드 | 타입 | 설명 |
|---|---|---|
| `hive_id` | form | 대상 벌통 |
| `device_id` | form | 관찰 스마트폰 식별자 |
| `timestamp` | form | ISO-8601 (선택, 없으면 서버 시각) |
| `image` | file | JPEG. 8MB 초과 시 분석에서 제외됩니다 |

```json
{
  "status": "CAUTION",
  "risk_score": 44,
  "hornet_count": 2,
  "confidence": 0.87,
  "processed_at": "2026-09-19T12:00:00",
  "max_hornet_count": 2,
  "audio_probability": 0.2,
  "snapshot_url": "/static/snapshots/...",
  "alert_id": null
}
```

`alert_id` 는 **이 프레임이 경보를 유발한 경우에만** 값이 들어갑니다.

`status` 는 위험 등급이며 `OFFLINE` 이 되지 않습니다 — 업로드 중인 스마트폰은
정의상 온라인이므로, 자신의 heartbeat와 경합해 OFFLINE이 표시되는 일을 피합니다.

### `POST /api/monitor/audio`

`multipart/form-data` · 필드는 `image` 대신 `audio` (기본 m4a/AAC).

```json
{
  "hornet_probability": 0.31,
  "processed_at": "2026-09-19T12:00:00",
  "status": "CAUTION",
  "risk_score": 44
}
```

오디오는 **단독으로 경보를 만들지 않습니다.** Risk Engine에 입력될 뿐입니다.

### `POST /api/monitor/heartbeat`

```json
{
  "hive_id": "hive-a",
  "device_id": "phone-abc123",
  "timestamp": "2026-09-19T12:00:00",
  "camera_ok": true,
  "microphone_ok": true,
  "monitoring": true
}
```

응답:

```json
{
  "acknowledged": true,
  "hive_id": "hive-a",
  "status": "NORMAL",
  "risk_score": 3,
  "server_time": "2026-09-19T12:00:00",
  "next_heartbeat_seconds": 10.0
}
```

`OFFLINE_AFTER_SECONDS`(기본 45초) 동안 heartbeat가 없으면 해당 벌통은 OFFLINE이 됩니다.

---

## Devices

### `POST /api/devices`

```json
{ "device_id": "phone-abc123", "hive_id": "hive-a", "role": "monitor", "platform": "android" }
```

`(device_id, hive_id)` 기준 멱등입니다.

### `POST /api/devices/push-token`

```json
{ "token": "<FCM registration token>", "platform": "android", "device_id": "phone-xyz" }
```

token 기준 멱등입니다. FCM은 앱 재실행 시 같은 토큰을 재발급하므로,
중복 등록되면 관리자 폰이 두 번 울리게 됩니다.

---

## Pairing

관찰용 스마트폰을 벌통에 연결합니다. 서버 주소 입력 UX를 대체합니다.

### `POST /api/pairings`

관리자 앱이 벌통에 코드를 요청합니다. 호출할 때마다 새 코드가 나오며,
이전 코드도 만료 전까지는 계속 사용할 수 있습니다.

```json
// 요청
{ "hive_id": "hive-a" }

// 201 응답
{
  "id": "9f2c...",
  "code": "482731",
  "hive_id": "hive-a",
  "hive_name": "벌통 A",
  "expires_at": "2026-09-19T12:10:00",
  "expires_in_seconds": 600,
  "pair_uri": "beehiveguard://pair?code=482731"
}
```

`expires_in_seconds` 는 두 기기의 시계가 어긋나도 카운트다운이 맞도록
응답 시점 기준 남은 초를 함께 내려줍니다.
`pair_uri` 가 QR 코드에 담기는 값입니다.

### `GET /api/pairings/{id}`

관리자 앱이 sheet를 열어둔 동안 3초 간격으로 polling합니다.

```json
{
  "id": "9f2c...",
  "code": "482731",
  "status": "WAITING",
  "hive_id": "hive-a",
  "hive_name": "벌통 A",
  "claimed_device_id": null,
  "expires_at": "2026-09-19T12:10:00",
  "expires_in_seconds": 540
}
```

`status` 는 `WAITING` · `CLAIMED` · `EXPIRED` 입니다.
만료는 저장된 값이 아니라 `expires_at` 과 현재 시각으로 계산되므로,
별도의 background job 없이도 만료된 코드가 claim 가능한 상태로 남지 않습니다.
이미 claim된 코드는 TTL이 지나도 `CLAIMED` 로 유지됩니다 — 관리자 앱이 기다리는
값이 그것이기 때문입니다.

### `POST /api/pairings/claim`

관찰용 스마트폰이 코드를 사용합니다. 성공하면 `MonitoringDevice` 가
해당 벌통에 연결됩니다.

```json
// 요청
{ "code": "482731", "device_id": "phone-abc123" }

// 200 응답
{
  "success": true,
  "hive_id": "hive-a",
  "hive_name": "벌통 A",
  "device_id": "phone-abc123",
  "pairing_id": "9f2c..."
}
```

실패는 이유를 구분해 반환합니다. 앱이 "다시 입력"과 "새 코드 받기" 중
무엇을 안내할지 결정해야 하기 때문입니다.

| 상황 | HTTP | `detail.reason` |
|---|---|---|
| 없는 코드 / 숫자가 아님 | 404 | `INVALID_CODE` |
| 만료 | 410 | `EXPIRED` |
| 이미 사용됨 | 409 | `ALREADY_CLAIMED` |
| 시도 과다 | 429 | `RATE_LIMITED` |

```json
// 409 응답 본문
{
  "detail": {
    "success": false,
    "reason": "ALREADY_CLAIMED",
    "message": "이미 사용된 코드입니다. 새 코드를 발급받아주세요."
  }
}
```

코드는 `482 731` 처럼 공백이나 하이픈이 섞여 들어와도 정규화해 처리합니다.

> **기기 바인딩은 한 기기당 한 벌통입니다.** 스마트폰은 물리적으로 벌통 하나
> 앞에 있으므로, 다시 페어링하면 행이 추가되는 대신 **이동**합니다.
> `POST /api/devices` 와 `POST /api/monitor/heartbeat` 도 같은 헬퍼
> (`bind_device_to_hive`)를 사용해 동일하게 동작합니다.

---

## Demo (개발 전용)

제품 API가 아니라, 말벌 없이 시연을 재현하기 위한 도구입니다.

| Endpoint | 동작 |
|---|---|
| `POST /api/demo/reset` | 모든 관측·경보·기기 상태 삭제 후 벌통 재seed |
| `POST /api/demo/simulate` | 시나리오 전체를 즉시 재생 (`hive_id`, `frames_per_second`, `include_audio`, `reset_first`) |
| `POST /api/demo/observe` | 관측 1건 주입 (`hive_id`, `hornet_count`, `audio_probability`) — 실시간 재생용 |
| `POST /api/demo/script` | mock detector/classifier에 응답을 예약 (`hive_id`, `counts`, `audio_probabilities`) |
| `POST /api/demo/create-alert` | 상태 기계를 우회해 Alert 1건 강제 생성 + push |

`simulate` 와 `observe` 는 **실제 파이프라인**(Risk Engine + Alert Manager)을 그대로 통과합니다.
`create-alert` 만 상태 기계를 우회하며, push 경로 리허설 전용입니다.

`script` 는 legacy `/api/monitor/frame` 호환 경로를 말벌 없이 시연하기 위한 도구입니다.
새 Flutter monitoring 경로는 스마트폰의 `MODEL_MODE` detector 결과를 `/observation`으로 보냅니다.
