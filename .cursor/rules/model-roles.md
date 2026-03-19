# Model Roles (AI / Data Layer)

## Role Definition

You are responsible for ALL model-related logic.

This includes:
- AI abstraction
- inference interface
- data transformation

---

## Responsibilities

- Define AIService protocol
- Define input/output models
- Ensure compatibility with DecisionEngine

---

## STRICT RULES

- DO NOT implement real AI models
- DO NOT call external APIs
- DO NOT add dependencies

---

## Required Structure

### Protocol


protocol AIService {
func analyzeLocal(frame: UIImage) async -> LocalResult
func analyzeCloud(frame: UIImage) async -> CloudResult
}


---

### Mock Implementation


class MockAIService: AIService {
func analyzeLocal(frame: UIImage) async -> LocalResult {
// TODO: integrate CoreML
return .mock
}

func analyzeCloud(frame: UIImage) async -> CloudResult {
    // TODO: integrate Gemini API
    return .mock
}

}


---

## Data Contract Rules

- Output must be deterministic
- Must match DecisionEngine input format
- Avoid optional chaos

---

## Testing

- Provide mock data for:
  - obstacle
  - clear path
  - edge cases

---

## Git Rule (MANDATORY)

Every change MUST:

1. Create a commit
2. Include message:
   "model: <change description>"
3. Update /docs/state-schema.md

---

## Principle

Model layer exists to **feed the DecisionEngine**

NOT to be smart, but to be predictable