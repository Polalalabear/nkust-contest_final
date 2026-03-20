# Tech Stack (STRICT ENFORCEMENT)

## Purpose

Define ALL allowed technologies.

Agent MUST NOT introduce any technology not listed here.

---

## iOS

- SwiftUI (Primary UI framework)
- UIKit (only if necessary)

---

## Architecture

- MVVM (mandatory)
- Layer separation enforced:
  - View
  - ViewModel
  - Service
  - Engine

---

## Concurrency

- async/await (preferred)
- Combine (optional, only if justified)

---

## Media & Hardware

- AVFoundation (camera / video)
- AVAudioSession (audio control)
- AVSpeechSynthesizer (TTS)

---

## Feedback

- CoreHaptics (mandatory for vibration)

---

## Accessibility

- Accessibility API (mandatory)
- VoiceOver support required

---

## Data Persistence

- SwiftData (only for local storage)

---

## Backend / Cloud (PROJECT-SPECIFIC)

本專案已整合 **Firebase**（見 Xcode SPM 與 `GoogleService-Info.plist`）：

- Firebase Core（`FirebaseApp.configure()` 於 `AppDelegate`）
- Firestore（照護者「真實資料」模式：儀表板快照監聽）
- Firebase Auth / Analytics / AI 等套件已連結，實際登入與推論流程可逐步啟用

**規則**：除本文件列出的 Firebase 模組外，**不可**再新增其他雲端 SDK（除非同步更新本文件與 README）。

---

## Streaming

- MJPEG via URLSession
- No WebRTC / no external streaming frameworks

**必讀**：`/docs/device-connection.md` — 相機串流僅能經 `StreamService`；開發階段仍使用 **MockStreamService**，不可接真實 ESP32 串流，直到專案明確進入下一階段。

---

## AI Integration (CURRENT STATE)

- CoreML → STUB ONLY (no real model integration yet)
- Gemini API → STUB ONLY (no network calls yet)
- Firebase AI 套件已載入 → 實際呼叫需另開任務與本文件註記

---

## Forbidden Technologies

Agent MUST NOT use:

- Third-party UI frameworks
- Realm
- WebSockets (for camera/device stream; Firestore 即時監聽不在此限)
- Any unknown SDK **not** listed in this file

---

## Rules

- Prefer native Apple frameworks
- Keep dependencies minimal
- Avoid abstraction unless necessary

---

## Key Principle

Technology is NOT flexible.

Consistency > experimentation

**例外**：若 `architecture.md` 與本文件衝突，以 **architecture.md** 為優先。
