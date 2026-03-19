# Architecture Rules (STRICT)

## Layer Definition

### 1. View (SwiftUI)
- UI only
- No business logic
- No data processing
- No API calls

---

### 2. ViewModel
- State management only
- Transforms data for UI
- Calls Services / Engine
- NO heavy logic

---

### 3. Service Layer
- External interaction only
- Examples:
  - StreamService (MJPEG)
  - AIService (CoreML / Gemini)
  - FeedbackService (haptic + voice)

---

### 4. Core Engine (MOST IMPORTANT)
- Pure logic
- No framework dependency
- Fully testable
- Example:
  - DecisionEngine

---

## STRICT RULES

- DO NOT put logic in View
- DO NOT call API from View
- DO NOT mix Service and Engine
- DO NOT create hidden dependencies

---

## Core Modules

### MUST IMPLEMENT (REAL)
- DecisionEngine
- FeedbackManager

---

### MUST STUB (NO REAL IMPLEMENTATION)

#### AI Layer
- CoreML inference
- Gemini API

#### Stream Layer
- MJPEG stream

---

## Stub Rules

For ALL external dependencies:

- Create protocol
- Create mock implementation
- Return fake data
- Add TODO for real implementation

Example:


protocol AIService {
func analyze(frame: UIImage) async -> AnalysisResult
}

class MockAIService: AIService {
func analyze(frame: UIImage) async -> AnalysisResult {
// TODO: integrate CoreML / Gemini
return .mock
}
}


---

## Data Flow (Single Direction)

Camera → AI → DecisionEngine → Feedback → User

NO circular flow allowed

---

## Priority Order

1. DecisionEngine
2. Feedback
3. AppState
4. UI
5. Integration (LAST)

---

## Performance Principle

- Real-time first
- Avoid heavy computation
- Avoid blocking main thread

---

## Failure Strategy

- If AI fails → fallback to safe state
- If system uncertain → escalate to human

---

## Key Insight

This is NOT an app.

This is a **real-time decision system with UI attached**