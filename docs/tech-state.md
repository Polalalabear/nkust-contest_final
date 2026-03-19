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

## Streaming

- MJPEG via URLSession
- No WebRTC / no external streaming frameworks

---

## AI Integration (CURRENT STATE)

- CoreML → STUB ONLY (no real model integration yet)
- Gemini API → STUB ONLY (no network calls yet)

---

## Forbidden Technologies

Agent MUST NOT use:

- Third-party UI frameworks
- Firebase
- Realm
- WebSockets
- Any unknown SDK

---

## Rules

- Prefer native Apple frameworks
- Keep dependencies minimal
- Avoid abstraction unless necessary

---

## Key Principle

Technology is NOT flexible.

Consistency > experimentation