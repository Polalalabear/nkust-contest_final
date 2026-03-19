# State Schema (AUTO-UPDATED BY AGENT)

## Purpose

This file is the **single source of truth for system state evolution**.

It MUST be updated automatically by the agent AFTER:
- a feature is implemented
- tests pass successfully

---

## Update Rules (STRICT)

Every update MUST:

1. Append (DO NOT overwrite)
2. Include timestamp
3. Include related files
4. Include test result
5. Be atomic (one feature per entry)

---

## Entry Format (MANDATORY)

### [Timestamp]

**Feature**
- What was implemented

**Modules Affected**
- File paths

**State Changes**
- What state was added/modified

**Test Coverage**
- What was tested
- Result: PASS / FAIL

**Notes**
- Edge cases / limitations
- TODO (if any)

---

## Example

### [2026-03-19 14:30]

**Feature**
- Implement DecisionEngine risk scoring

**Modules Affected**
- /Core/DecisionEngine.swift

**State Changes**
- Added RiskScore model
- Added Action enum

**Test Coverage**
- Unit test for 3x3 grid scoring
- Result: PASS

**Notes**
- Threshold values are hardcoded
- TODO: make configurable

---

## Enforcement

Agent MUST:

- Refuse to proceed if last step is not logged
- Keep entries concise and structured
- Never remove historical entries

---

## Key Principle

This file is NOT documentation.

It is a **machine-readable development log**

---

### [2026-03-19 14:40]

**Feature**
- Build MVVM app skeleton with strict layer/module separation and stub-only external services

**Modules Affected**
- /nkust-contest/nkust-contest/App/AppEntry.swift
- /nkust-contest/nkust-contest/App/AppRouter.swift
- /nkust-contest/nkust-contest/State/AppState.swift
- /nkust-contest/nkust-contest/Shared/Models/AppMode.swift
- /nkust-contest/nkust-contest/Shared/Models/DecisionModels.swift
- /nkust-contest/nkust-contest/Core/Engine/DecisionEngine.swift
- /nkust-contest/nkust-contest/Core/Engine/FeedbackManager.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/**
- /nkust-contest/nkust-contest/Modules/RecognitionMode/**
- /nkust-contest/nkust-contest/Modules/LTCMode/**
- /nkust-contest/nkust-contest/Modules/Dashboard/**
- /nkust-contest/nkust-contest/Services/AI/AIService.swift
- /nkust-contest/nkust-contest/Services/Stream/StreamService.swift
- /nkust-contest/nkust-contest/Services/Feedback/FeedbackService.swift
- /nkust-contest/nkust-contest/ContentView.swift (removed)
- /nkust-contest/nkust-contest/nkust_contestApp.swift (removed)

**State Changes**
- Added global `AppState` container scaffold with mode/mute state placeholders
- Added app navigation entry points for Walk/Recognition/LTC/Dashboard modules
- Added deterministic decision/result model scaffolding for future engine logic

**Test Coverage**
- iOS compile check with `xcodebuild` against `generic/platform=iOS` and local DerivedData
- Result: PASS

**Notes**
- All Service implementations are stubs with TODOs for real integrations
- `#Preview` macros were removed to avoid sandbox macro-plugin failure during CI-like build

---

### [2026-03-19 14:47]

**Feature**
- Fix MemberImportVisibility compile errors and add #Preview to all View files

**Modules Affected**
- /nkust-contest/nkust-contest/App/AppEntry.swift
- /nkust-contest/nkust-contest/App/AppRouter.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/View/WalkModeView.swift
- /nkust-contest/nkust-contest/Modules/RecognitionMode/View/RecognitionModeView.swift
- /nkust-contest/nkust-contest/Modules/LTCMode/View/LTCModeView.swift
- /nkust-contest/nkust-contest/Modules/Dashboard/View/DashboardView.swift

**State Changes**
- Added `import Combine` to AppEntry and all View files (required by MemberImportVisibility for @StateObject)
- Added `#Preview` blocks to AppRouter, WalkModeView, RecognitionModeView, LTCModeView, DashboardView

**Test Coverage**
- Full unsandboxed xcodebuild compile check: generic/platform=iOS
- Result: PASS

**Notes**
- `#Preview` macros require unsandboxed swift-plugin-server; they compile in Xcode but fail in sandboxed CLI
- Stale Xcode index may still show phantom errors for deleted ContentView/nkust_contestApp until index rebuild

---

### [2026-03-19 16:15]

**Feature**
- Full UI implementation based on reference designs (ui/ folder)
- Migrated to iOS 26 @Observable syntax, SF Symbols for all icons
- Role selection flow: ChooseUserView → DeviceInfoView → MainTabView (visually impaired) or DashboardView (caregiver)
- Page-swipeable mode switching: Walk ↔ Recognition ↔ LTC
- Caregiver dashboard with summary + map tabs

**Modules Affected**
- /nkust-contest/nkust-contest/App/AppEntry.swift (→ @Observable)
- /nkust-contest/nkust-contest/App/AppRouter.swift (role-based routing)
- /nkust-contest/nkust-contest/State/AppState.swift (→ @Observable, added device/phone/voice state)
- /nkust-contest/nkust-contest/Shared/Models/AppMode.swift (added UserRole, swipe hints)
- /nkust-contest/nkust-contest/Shared/Models/DecisionModels.swift (ObstacleInfo, DirectionInfo, TrafficLightInfo, ContactInfo)
- /nkust-contest/nkust-contest/Shared/Components/* (5 new shared components)
- /nkust-contest/nkust-contest/Modules/ChooseUser/View/ChooseUserView.swift (new)
- /nkust-contest/nkust-contest/Modules/DeviceInfo/View/DeviceInfoView.swift (new)
- /nkust-contest/nkust-contest/Modules/MainTab/View/MainTabView.swift (new)
- /nkust-contest/nkust-contest/Modules/WalkMode/** (redesigned)
- /nkust-contest/nkust-contest/Modules/RecognitionMode/** (redesigned)
- /nkust-contest/nkust-contest/Modules/LTCMode/** (redesigned)
- /nkust-contest/nkust-contest/Modules/Dashboard/** (redesigned + LocationMapView)

**State Changes**
- AppState migrated from ObservableObject to @Observable
- Added: userRole, isVoiceEnabled, deviceConnected, deviceBattery, phoneBattery, isLocationSharing
- All ViewModels migrated to @Observable
- All Views use @State for viewModel, @Binding for voice toggle, @Environment for AppState
- Added ContactInfo, ObstacleInfo, DirectionInfo, TrafficLightInfo models

**Test Coverage**
- Full xcodebuild compile: generic/platform=iOS (unsandboxed)
- Result: PASS

**Notes**
- All external services remain stubs (AI, Stream, Feedback)
- Camera preview uses placeholder Rectangle — TODO: integrate AVFoundation
- Map uses MapKit with static coordinates — TODO: integrate real location
- Health data in Dashboard is mock — TODO: integrate HealthKit

---

### [2026-03-19 16:40]

**Feature**
- Add README.md + .gitignore
- Cyclic page-swipe (last→first, first→last) for mode switching
- Caregiver profile sheet with device info + logout button
- Back button on all visually-impaired screens (DeviceInfo, Walk, Recognition, LTC)
- Fix DeviceInfoView back button wiring (was empty closure, now returns to ChooseUser)

**Modules Affected**
- /README.md (new)
- /.gitignore (new)
- /nkust-contest/nkust-contest/App/AppRouter.swift (pass onBack closures)
- /nkust-contest/nkust-contest/Modules/DeviceInfo/View/DeviceInfoView.swift (add onBack param + wire button)
- /nkust-contest/nkust-contest/Modules/MainTab/View/MainTabView.swift (cyclic scroll logic + onBack)
- /nkust-contest/nkust-contest/Modules/WalkMode/View/WalkModeView.swift (add onBack param)
- /nkust-contest/nkust-contest/Modules/RecognitionMode/View/RecognitionModeView.swift (add onBack param)
- /nkust-contest/nkust-contest/Modules/LTCMode/View/LTCModeView.swift (add onBack param)
- /nkust-contest/nkust-contest/Modules/Dashboard/View/DashboardView.swift (add ProfileSheetView + logout)

**State Changes**
- Navigation flow now fully bidirectional: back buttons set appState.userRole = nil or showMainFlow = false
- Cyclic scroll implemented via sentinel pages (tag 0 and 4) that bounce to real pages (3 and 1)
- ProfileSheetView reads AppState for device info; logout clears userRole

**Test Coverage**
- xcodebuild compile: generic/platform=iOS (unsandboxed)
- Result: PASS

**Notes**
- Cyclic scroll uses DispatchQueue.main.asyncAfter(0.3s) to allow animation completion before jump
- Profile email is placeholder — TODO: integrate authentication

---

### [2026-03-19 17:00]

**Feature**
- Detailed health data views: each health card (steps, distance, standing) now navigates to HealthDetailView with period filter (week/month/3-month), sort order (ascending/descending), and daily records list
- AllHealthDataView: calendar-based view with month navigation, date tap for daily detail, period averages, sort controls, and full daily record list
- DashboardViewModel now sources today's values from weekly mock records
- HealthModels.swift: DailyHealthRecord, HealthMetric, HealthPeriod, SortOrder

**Modules Affected**
- /nkust-contest/nkust-contest/Shared/Models/HealthModels.swift (new)
- /nkust-contest/nkust-contest/Modules/Dashboard/View/DashboardView.swift (NavigationLinks to health details + all-health)
- /nkust-contest/nkust-contest/Modules/Dashboard/View/HealthDetailView.swift (new)
- /nkust-contest/nkust-contest/Modules/Dashboard/View/AllHealthDataView.swift (new)
- /nkust-contest/nkust-contest/Modules/Dashboard/ViewModel/DashboardViewModel.swift (weekRecords + computed today values)
- /docs/handoff.md (new)

**State Changes**
- Added DailyHealthRecord model with mock generators (week/month/3-month)
- Added HealthMetric, HealthPeriod, SortOrder enums
- DashboardViewModel now holds weekRecords array; todaySteps/todayDistance/todayStanding are computed
- SummaryView health cards are now NavigationLinks to HealthDetailView
- "顯示所有健康資料" is now NavigationLink to AllHealthDataView

**Test Coverage**
- Full xcodebuild compile: generic/platform=iOS (unsandboxed)
- Result: PASS

**Notes**
- Health data remains mock — TODO: integrate HealthKit
- Calendar grid uses LazyVGrid with 7 columns, leading blanks for month alignment
- handoff.md created for next conversation handoff