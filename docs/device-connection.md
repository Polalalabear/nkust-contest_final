# Device Connection (ESP32 Camera)

## Connection Type

The device operates in **STA (Station) mode**:

> ESP32 connects to the test phone's hotspot as a client, obtaining an IP from DHCP.

---

## Network Setup

- **Mode**: STA（連至手機熱點）
- **Phone Hotspot SSID**: _(手機熱點 SSID)_
- **ESP32 assigned IP**: `172.20.10.3`（固定或 DHCP 保留）
- **Stream endpoint**: `http://172.20.10.3/stream`

> ⚠️ 舊 AP 模式資訊（SSID: XIAO-S3-CAM, IP: 192.168.4.1）已廢棄，目前不使用。

---

## How iOS Connects

1. iPhone 連至**與 ESP32 相同的手機熱點**網路：
   - iOS 裝置與 ESP32 共用同一個 hotspot 子網段。

2. App sends HTTP request to:

   http://172.20.10.3/stream

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

Current phase: **realDeviceAllowed**（真機串流已啟用）

- `StreamDevelopmentPhase.current = .realDeviceAllowed`
- `StreamServiceFactory.makeDefault()` 回傳 `MJPEGStreamService`
- Live 模式下 app 會嘗試連線 `http://172.20.10.3/stream`
- Mock 模式仍只走 `MockStreamService`

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

- **ESP32 MJPEG**（`http://172.20.10.3/stream`，STA 模式）仍 **只** 允許由 `StreamService` 以 URLSession 解析；現階段 `StreamDevelopmentPhase.current = .realDeviceAllowed`，live 模式使用 `MJPEGStreamService`。
- **Firestore** 不取代 MJPEG；後端可另寫程序將裝置狀態寫入 Firestore，與 iOS 相機串流解耦。