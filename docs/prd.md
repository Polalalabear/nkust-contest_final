# Product Overview

## Concept
A vision-assisted navigation system for visually impaired users.

The system converts real-world visual input into **actionable navigation decisions** (stop / move left / move right / safe) in real-time.

---

## Core Value

- Reduce cognitive load: user does not interpret environment, only reacts to instructions
- Real-time safety: obstacle avoidance works offline (on-device)
- Seamless fallback: AI → human assistance when uncertainty is high

---

## Primary User
- Visually impaired person (main user)
- Caregiver (secondary user)

---

## Core Feature (Single Source of Truth)

### Walking Decision System

Transform camera input into:

- STOP (immediate danger)
- MOVE LEFT / RIGHT (direction correction)
- SAFE (no feedback)

---

## Modes

### 1. Walk Mode (Primary)
- Fully automatic
- No manual interaction required
- Real-time feedback (haptic + voice)

---

### 2. Recognition Mode
- User asks system to identify object
- AI attempts recognition
- Fallback to human if confidence is low

---

### 3. LTC Mode (Remote Assistance)
- Contact caregiver
- Share camera
- Share location

---

## Feedback System

### Haptic (Primary)
- Strong vibration → STOP
- Short-short → move left
- Short-long → move right
- None → safe

### Voice (Secondary)
Format:
"前方 X 公尺 + 物件 + 建議動作"

---

## System Principle

- Prioritize reaction speed over information completeness
- Never overload user with information
- Always output a clear next action

---

## Non-Goals (Important)

- NOT a general AI assistant
- NOT a visual exploration tool
- NOT a complex UI application

This is a **real-time decision system**