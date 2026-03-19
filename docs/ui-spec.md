# UI Specification (STRICT)

## Global Rules

- Minimal UI
- Large touch targets
- Fully operable without vision
- VoiceOver compatible
- No complex layout

---

## Screen: WalkMode

### Layout

- VStack
  - Top: StatusBar
    - connection status (text)
    - battery level (text)
  - Spacer
  - Center: MainButton (VERY LARGE)
  - Spacer
  - Bottom: ModeIndicator ("Walk Mode")

---

### Interaction (CRITICAL)

- Single Tap → replay last instruction
- Double Tap → mute (temporary)
- Long Press → voice command
- Very Long Press → SOS

---

### Constraints

- MainButton must be the largest element
- No small buttons
- No hidden gestures
- All actions must be accessible via VoiceOver

---

## Screen: RecognitionMode

### Layout

- Fullscreen camera preview
- Minimal overlay

---

### Behavior

- Show nothing unless needed
- Feedback via voice

---

## Screen: LTCMode

### Layout

- Vertical list of contacts

---

### Interaction

- Swipe up/down → navigate contacts
- Tap → read contact name
- Double tap → call

---

## Screen: Dashboard (Caregiver)

### Layout

- Top: Live camera feed
- Middle: Map (placeholder)
- Bottom: Control buttons

---

### Controls

- Call
- Send voice message
- View logs

---

## DO NOT

- Add extra UI components
- Add animations
- Redesign layout
- Add visual complexity

---

## Design Principle

UI is NOT for viewing.

UI is for **control + feedback only**