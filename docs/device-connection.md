# Device Connection (ESP32 Camera)

## Connection Type

The device is NOT a client.

It acts as a:

> WiFi Access Point + HTTP MJPEG Stream Server

---

## Network Setup

- SSID: XIAO-S3-CAM
- Password: password123
- Device IP: 192.168.4.1

---

## How iOS Connects

1. User manually connects to WiFi:
   - XIAO-S3-CAM

2. App sends HTTP request to:

   http://192.168.4.1/stream

---

## Stream Format

- Protocol: HTTP
- Content-Type: multipart/x-mixed-replace
- Data: continuous JPEG frames (MJPEG)

---

## Important Characteristics

- No internet access
- No router involved
- Local network only
- Single device server

---

## Integration Rule (CRITICAL)

Agent MUST:

- Treat this as a StreamService input
- DO NOT implement WebSocket
- DO NOT use WebRTC
- DO NOT assume JSON API
- DO NOT assume REST API

---

## Implementation Constraint

- Use URLSession
- Parse MJPEG stream manually
- Extract JPEG frames
- Convert to UIImage

---

## Development Phase Rule

Current phase:

- DO NOT connect to real device
- MUST use MockStreamService

Later phase:

- Replace mock with real MJPEG stream

---

## Failure Handling

If connection fails:

- Return nil frame
- DO NOT crash
- DO NOT retry aggressively

---

## Key Insight

This is NOT a video stream.

This is a:

> continuous sequence of JPEG images over HTTP

## Device Rule

- Camera input MUST come from StreamService
- StreamService MUST follow /docs/device-connection.md

---

## Relation to Caregiver Cloud Data

照護者主控台的 **裝置連線／健康摘要** 可經 **Firestore** 與 **SwiftData** 同步（見 `README.md` 資料契約）。  
**與本文件的邊界**：

- **ESP32 MJPEG**（`http://192.168.4.1/stream`）仍 **只** 允許由 `StreamService` 以 URLSession 解析；現階段預設 **MockStreamService**。
- **Firestore** 不取代 MJPEG；後端可另寫程序將裝置狀態寫入 Firestore，與 iOS 相機串流解耦。