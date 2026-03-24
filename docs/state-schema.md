# State Schema (AUTO-UPDATED BY AGENT)

## Purpose

This file is the **single source of truth for system state evolution**.

It MUST be updated automatically by the agent AFTER:
- a feature is implemented
- tests pass successfully

---

### [2026-03-24 22:40]

**Feature**
- Surface live model inference results directly in UI and add voice prompts when recognition result text changes

**Modules Affected**
- /nkust-contest/nkust-contest/Modules/WalkMode/ViewModel/WalkModeViewModel.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/View/WalkModeView.swift
- /nkust-contest/nkust-contest/Modules/RecognitionMode/ViewModel/RecognitionModeViewModel.swift
- /nkust-contest/nkust-contest/Modules/RecognitionMode/View/RecognitionModeView.swift
- /README.md

**State Changes**
- Walk mode now publishes `modelDetectionText` and renders it on-screen as an "即時判斷" card
- Recognition mode now tracks voice-enable state and only announces updated recognition text when content changes
- Recognition voice announcements are routed through `VoiceAnnouncementCenter` with navigation priority

**Test Coverage**
- xcodebuild: `-project nkust-contest/nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- Duplicate MJPEG connection logs can still appear when multiple stream consumers are active in the flow; this entry only covers model-result UI/voice behavior

---

### [2026-03-24 22:25]

**Feature**
- Fix CoreML live inference output compatibility by supporting `VNCoreMLFeatureValueObservation` mapping with graceful empty-result fallback
- Stabilize real-mode camera background layout by enforcing fixed full-screen frame rendering with clipping
- Sync `AppState.phoneBattery` from actual iOS device battery instead of cloud snapshot override

**Modules Affected**
- /nkust-contest/nkust-contest/Services/AI/AIService.swift
- /nkust-contest/nkust-contest/Shared/Components/CameraPreviewPlaceholder.swift
- /nkust-contest/nkust-contest/Services/System/PhoneBatteryService.swift (new)
- /nkust-contest/nkust-contest/App/AppRouter.swift
- /nkust-contest/nkust-contest/Modules/Dashboard/ViewModel/DashboardViewModel.swift
- /README.md

**State Changes**
- CoreML runtime now handles feature-value style Vision outputs and treats unmapped outputs as no detection for the current frame
- Camera preview rendering is constrained to container geometry and clipped to prevent stream frame aspect changes from shifting overlay UI
- Added runtime phone battery monitor service (`UIDevice.batteryLevel`) that updates `AppState.phoneBattery` on level/state changes
- Firestore live snapshot no longer writes `phoneBattery` into app state

**Test Coverage**
- xcodebuild: `-project nkust-contest/nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- Device battery (`deviceBattery`) behavior remains unchanged and still follows existing snapshot path
- `UIDevice.batteryLevel` can be `-1` before monitoring is ready; service keeps previous value until a valid reading is available

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

---

### [2026-03-19 17:15]

**Feature**
- Remove device status bar from Dashboard summary (kept in profile sheet only)
- Add "一鍵取得即時位置" button (disabled when location sharing off)
- Add "最近醫院" button (show nearest hospital to visually impaired user)
- Editable caregiver profile (name, relationship, emergency contact phone) with edit/done toggle
- Add interactive charts (bar/line/pie via Swift Charts) above health data in Dashboard cards, HealthDetailView, and AllHealthDataView
- AllHealthDataView now has metric picker (steps/distance/standing) for chart
- Version bumped to 1.1.0, stored as static on AppState

**Modules Affected**
- /nkust-contest/nkust-contest/State/AppState.swift (added caregiverName, caregiverRelationship, caregiverEmergencyPhone, visUserLatitude/Longitude, appVersion/buildDate)
- /nkust-contest/nkust-contest/Shared/Models/HealthModels.swift (added ChartStyle enum)
- /nkust-contest/nkust-contest/Shared/Components/HealthChartView.swift (new — reusable bar/line/pie chart)
- /nkust-contest/nkust-contest/Modules/Dashboard/View/DashboardView.swift (removed statusBar, added actionButtons, charts on healthCards, editable ProfileSheetView)
- /nkust-contest/nkust-contest/Modules/Dashboard/View/HealthDetailView.swift (added chart section)
- /nkust-contest/nkust-contest/Modules/Dashboard/View/AllHealthDataView.swift (added chart section with metric picker)
- /nkust-contest/nkust-contest/Modules/Dashboard/ViewModel/DashboardViewModel.swift (added fetchVisUserLocation, showNearestHospital)

**State Changes**
- AppState: added caregiverName, caregiverRelationship, caregiverEmergencyPhone (String), visUserLatitude/visUserLongitude (Double), appVersion/buildDate (static)
- Added ChartStyle enum (.bar, .line, .pie) to HealthModels
- ProfileSheetView now has isEditing toggle; binds to AppState caregiver fields
- SummaryView no longer shows device status bar
- HealthChartView uses Swift Charts (BarMark, LineMark, AreaMark, SectorMark)

**Test Coverage**
- Full xcodebuild compile: generic/platform=iOS (unsandboxed)
- Result: PASS

**Notes**
- Location fetch and hospital search are stubs — TODO: integrate CoreLocation + MapKit MKLocalSearch
- Caregiver profile data is in-memory only — TODO: persist with SwiftData
- Charts use Swift Charts framework (native Apple, allowed by tech-stack.md)
- Version is now 1.1.0

---

### [2026-03-19 17:45]

**Feature**
- Chart show/hide toggle on Dashboard + HealthDetail + AllHealthData (reads appState.showCharts)
- Chart style picker moved from inline views to "設定偏好" (PreferencesView) in profile sheet; includes live preview
- Day/night mode toggle in PreferencesView (appState.isDarkMode → .preferredColorScheme)
- Date format changed from localized to "M/d" (e.g. 3/15) across all health views
- CSV export button at bottom of AllHealthDataView with time range selection dialog (stub)
- ExportRange enum (.week, .month, .threeMonths, .all) for export scope
- Version bumped to 1.2.0

**Modules Affected**
- /nkust-contest/nkust-contest/State/AppState.swift (added showCharts, preferredChartStyle, isDarkMode; version → 1.2.0)
- /nkust-contest/nkust-contest/Shared/Models/HealthModels.swift (added Date.shortMD extension, ExportRange enum)
- /nkust-contest/nkust-contest/Shared/Components/HealthChartView.swift (removed picker, accepts plain ChartStyle, uses shortMD)
- /nkust-contest/nkust-contest/Modules/Dashboard/View/DashboardView.swift (chart toggle, removed per-card chart pickers, added PreferencesView, .preferredColorScheme)
- /nkust-contest/nkust-contest/Modules/Dashboard/View/HealthDetailView.swift (removed local chartStyle, reads appState, shortMD dates)
- /nkust-contest/nkust-contest/Modules/Dashboard/View/AllHealthDataView.swift (removed local chartStyle, reads appState, shortMD dates, added CSV export section)

**State Changes**
- AppState: added showCharts (Bool), preferredChartStyle (ChartStyle), isDarkMode (Bool)
- HealthChartView: chartStyle parameter changed from Binding to plain value
- Chart style picker removed from SummaryView, HealthDetailView, AllHealthDataView
- PreferencesView: new view with dark mode toggle, chart style inline picker + live preview, show charts toggle
- DashboardView: applies .preferredColorScheme based on isDarkMode
- AllHealthDataView: confirmationDialog for CSV export range selection

**Test Coverage**
- Full xcodebuild compile: generic/platform=iOS (unsandboxed)
- Result: PASS

**Notes**
- CSV export is stub only — TODO: implement actual CSV generation via ShareLink / UIActivityViewController
- Dark mode uses .preferredColorScheme on DashboardView; only affects caregiver flow currently
- Preferences are in-memory — TODO: persist with SwiftData / UserDefaults
- Version is now 1.2.0

---

### [2026-03-19 18:30]

**Feature**
- Real `DefaultDecisionEngine`: rules from traffic red, obstacle distance bands → STOP / MOVE_LEFT / MOVE_RIGHT / SAFE
- Real `LiveFeedbackManager`: AVSpeechSynthesizer (zh-TW) + UIKit haptics mapped to actions; replay / mute / SOS
- `DefaultWalkModeService`: composes engine + feedback; `evaluateNavigation(context:voiceEnabled:)`
- `WalkModeViewModel` @MainActor: builds `DecisionContext` from obstacle/traffic UI state; `refreshNavigation` on appear + voice toggle
- `DecisionContext` expanded: obstacleDistanceMeters, trafficLightRed
- `FeedbackManager` protocol: added `deliverNavigationFeedback`
- Stub types retained for tests / alternate wiring
- Version 1.3.0

**Modules Affected**
- /nkust-contest/nkust-contest/Shared/Models/DecisionModels.swift
- /nkust-contest/nkust-contest/Core/Engine/DecisionEngine.swift
- /nkust-contest/nkust-contest/Core/Engine/FeedbackManager.swift
- /nkust-contest/nkust-contest/Services/Feedback/LiveFeedbackManager.swift (new)
- /nkust-contest/nkust-contest/Modules/WalkMode/Service/WalkModeService.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/ViewModel/WalkModeViewModel.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/View/WalkModeView.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/Engine/WalkModeEngine.swift
- /nkust-contest/nkust-contest/State/AppState.swift (appVersion)

**State Changes**
- DecisionContext is now a struct with obstacleDetected, obstacleDistanceMeters, trafficLightRed
- ObstacleInfo.mock distance 8m to align with MOVE_RIGHT band in DefaultDecisionEngine
- WalkMode default service path: DefaultWalkModeService + DefaultDecisionEngine + LiveFeedbackManager

**Test Coverage**
- xcodebuild: generic/platform=iOS (unsandboxed)
- Result: PASS

**Notes**
- CoreHaptics custom patterns not yet implemented — TODO in LiveFeedbackManager
- AI / Stream remain stubs; engine input still from mock UI state until camera+model wired
- MainActor default isolation: DefaultWalkModeService uses convenience init to construct dependencies

---

### [2026-03-19 19:30]

**Feature**
- SwiftData: `PersistedAppSettings` (singleton), `PersistedHealthDayRecordEntity` (daily health); `AppSettingsPersistence` + `HealthRecordsPersistence`
- AppEntry: `.modelContainer(for: [PersistedAppSettings.self, PersistedHealthDayRecordEntity.self], inMemory: false)`
- AppRouter: bootstrap seed + load settings into AppState on launch
- Firebase: `FirestoreDashboardSnapshotService` listens to `dashboard/caregiver_primary`; maps to `FirestoreDashboardSnapshot`
- AppState: `dataSourceMode`, `mockDeviceConnected`, `liveFirestoreSnapshot`, `caregiverDeviceShowsConnected`
- Dashboard SummaryView: data source segmented control (測試/真實), device status card (已連線/尚未連線), mock connection toggle
- DashboardViewModel: `syncDataSource`, `chartDetailRecords`, Firestore + SwiftData merge for live mode
- Profile device section uses caregiver effective connection; Preferences/Profile save to SwiftData
- AllHealthDataView + HealthDetailView navigation use `viewModel.chartDetailRecords`
- docs/tech-state.md: Firebase allowed (project-specific); device-connection cross-ref to Firestore
- docs/device-connection.md: caregiver cloud vs MJPEG boundary
- README: full SwiftData + Firestore schema tables; workflow + ambiguity notes for user confirmation
- docs/handoff.md: section 0 (reading docs, restrictions, state-schema, git push, ask user on ambiguity)
- Version 1.4.0

**Modules Affected**
- /nkust-contest/nkust-contest/App/AppEntry.swift
- /nkust-contest/nkust-contest/App/AppRouter.swift
- /nkust-contest/nkust-contest/State/AppState.swift
- /nkust-contest/nkust-contest/Shared/Models/DataSourceMode.swift (new)
- /nkust-contest/nkust-contest/Shared/Persistence/* (new)
- /nkust-contest/nkust-contest/Services/Firebase/* (new)
- /nkust-contest/nkust-contest/Modules/Dashboard/View/DashboardView.swift
- /nkust-contest/nkust-contest/Modules/Dashboard/View/AllHealthDataView.swift
- /nkust-contest/nkust-contest/Modules/Dashboard/ViewModel/DashboardViewModel.swift
- /README.md, /docs/tech-state.md, /docs/device-connection.md, /docs/handoff.md

**State Changes**
- SwiftData persists caregiver preferences + optional seeded health days
- Live mode: Firestore snapshot drives `connected` and optional health fields; upserts today into SwiftData
- Mock mode: in-memory mock week/three-month charts; `mockDeviceConnected` toggles UI 尚未連線

**Test Coverage**
- xcodebuild: generic/platform=iOS (unsandboxed)
- Result: PASS

**Notes**
- Firestore security rules and document path per pairing are TBD — README lists confirmation questions for product owner
- MJPEG real device connection still disallowed in current phase per device-connection.md
- Firebase packages were user-added; this entry documents integration layer only

---

### [2026-03-20 11:35]

**Feature**
- Extend visually impaired UI to follow unified data-source connection state (`mock` / `live`) via `AppState.effectiveDeviceConnected`
- Add spoken warning when device status is shown as disconnected (DeviceInfo and mode headers)
- Replace UIKit haptic combos with CoreHaptics custom patterns in `LiveFeedbackManager` (strong stop, short-short left, short-long right)
- Implement real MJPEG stream path (`MJPEGStreamService`) with URLSession + manual JPEG extraction while keeping current phase default on `MockStreamService`
- Update `.gitignore` for local tooling/build artifacts/secrets and sync README status

**Modules Affected**
- /.gitignore
- /README.md
- /nkust-contest/nkust-contest/State/AppState.swift
- /nkust-contest/nkust-contest/Shared/Components/ModeHeaderBar.swift
- /nkust-contest/nkust-contest/Modules/DeviceInfo/View/DeviceInfoView.swift
- /nkust-contest/nkust-contest/Services/Feedback/LiveFeedbackManager.swift
- /nkust-contest/nkust-contest/Services/Feedback/ConnectionStatusAnnouncer.swift (new)
- /nkust-contest/nkust-contest/Services/Stream/StreamService.swift

**State Changes**
- Added app-wide computed connection state (`effectiveDeviceConnected`) shared by caregiver and visually impaired flows
- Added connection status voice announcement service to avoid repeated disconnected prompts
- Added CoreHaptics engine-based playback path with UIKit fallback for unsupported/failure cases
- Added stream phase gate (`StreamDevelopmentPhase`) and default factory to enforce mock-only behavior in current stage

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- `MJPEGStreamService` is implemented but not default-enabled until phase changes to `realDeviceAllowed`
- Stream failure follows doc rule: emit `nil` frame, no crash, no aggressive retries

---

### [2026-03-20 12:05]

**Feature**
- Resolve strict-concurrency warnings (MainActor init call, actor-isolated static access, immutable fetch descriptors)
- Wire Walk/Recognition stream lifecycle and make stream enable/disable controlled by caregiver data mode (`mock/live`)
- Keep phase constraint intact: even in live mode, actual stream implementation still respects `StreamDevelopmentPhase.current`

**Modules Affected**
- /nkust-contest/nkust-contest/Modules/Dashboard/View/DashboardView.swift
- /nkust-contest/nkust-contest/Modules/Dashboard/ViewModel/DashboardViewModel.swift
- /nkust-contest/nkust-contest/Services/Firebase/FirestoreDashboardSnapshotService.swift
- /nkust-contest/nkust-contest/Services/Firebase/FirestoreDashboardSnapshot.swift
- /nkust-contest/nkust-contest/Shared/Persistence/HealthRecordsPersistence.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/View/WalkModeView.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/ViewModel/WalkModeViewModel.swift
- /nkust-contest/nkust-contest/Modules/RecognitionMode/View/RecognitionModeView.swift
- /nkust-contest/nkust-contest/Modules/RecognitionMode/ViewModel/RecognitionModeViewModel.swift

**State Changes**
- `SummaryView` pinned to MainActor to avoid nonisolated init warning
- Firestore listener API now requires explicit path parameter; path constant marked nonisolated
- Walk/Recognition ViewModel now manage `StreamService` start/stop by `DataSourceMode`
- Live mode triggers stream start; mock mode forces stream stop

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- Current phase remains mock-first through `StreamServiceFactory` (document rule preserved)

---

### [2026-03-20 12:35]

**Feature**
- Fix preview/strict-concurrency warnings by isolating `AppRouter` and screen construction on MainActor-safe paths
- Add `SystemIncidentCenter` for immediate runtime incident reporting (CoreML/Gemini-related failures)
- Integrate CoreML runtime entry (`LiveAIService`) and wire walk/recognition inference path to run only in `DataSourceMode.live`
- Update README with explicit testing checklist for ESP32 stream, CoreML usage, and Gemini integration status

**Modules Affected**
- /nkust-contest/nkust-contest/App/AppRouter.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/View/WalkModeView.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/ViewModel/WalkModeViewModel.swift
- /nkust-contest/nkust-contest/Modules/RecognitionMode/View/RecognitionModeView.swift
- /nkust-contest/nkust-contest/Modules/RecognitionMode/ViewModel/RecognitionModeViewModel.swift
- /nkust-contest/nkust-contest/Services/AI/AIService.swift
- /nkust-contest/nkust-contest/Services/System/SystemIncidentCenter.swift (new)
- /README.md

**State Changes**
- `WalkModeViewModel` and `RecognitionModeViewModel` now switch stream/AI behavior by `mock/live` mode
- Live mode attempts real model runtime and reports incidents on missing model/inference failure
- Gemini cloud path remains stub but now explicitly reports a non-critical incident for observability

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- `Sources/CoreEngine/*.mlpackage` currently appear incomplete (manifest-only) and will trigger model incident fallback until fixed

---

### [2026-03-20 12:55]

**Feature**
- Fix remaining `DashboardViewModel` main-actor default-argument warning
- Update CoreML runtime locator to prioritize `Sources/CoreEngine/Data` model directory as requested
- Keep strict incident reporting when model directory/package structure is invalid

**Modules Affected**
- /nkust-contest/nkust-contest/Modules/Dashboard/ViewModel/DashboardViewModel.swift
- /nkust-contest/nkust-contest/Services/AI/AIService.swift

**State Changes**
- `DashboardViewModel.init` now uses optional injection + in-body default construction to avoid nonisolated default-arg warning
- `CoreMLModelRuntime` now validates `Sources/CoreEngine/Data` path and reports explicit directory-missing errors

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- Current workspace still does not contain `/Sources/CoreEngine/Data`; app will report incident until model assets are added there

---

### [2026-03-20 13:10]

**Feature**
- Align CoreML package validation path with user-confirmed structure: `Sources/CoreEngine/<model>.mlpackage/Data/com.apple.CoreML/weights` (model name variable in middle)

**Modules Affected**
- /nkust-contest/nkust-contest/Services/AI/AIService.swift

**State Changes**
- CoreML runtime now validates package internals under `Data/com.apple.CoreML/*` instead of old layout assumptions
- Missing package incident now reports full expected package path under `Sources/CoreEngine/<model>.mlpackage`

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- Current workspace listing still does not expose `Data/com.apple.CoreML/*` files, so runtime will continue incident fallback until assets are available in app bundle/resources

---

### [2026-03-20 13:35]

**Feature**
- Fix caregiver map tab profile action (top-right avatar now opens `ProfileSheetView`)
- Make day/night mode changes immediately reflected in active sheet flows (`ProfileSheetView` and `PreferencesView`)
- Prevent disconnected device state from blocking visually-impaired mode navigation by gating live stream start on both `live` mode and effective connection
- Introduce centralized voice arbitration (`VoiceAnnouncementCenter`) and apply priority-based speech handling across navigation/SOS/connection alerts
- Update README with explicit voice priority rules and sample utterance content

**Modules Affected**
- /nkust-contest/nkust-contest/Modules/Dashboard/View/LocationMapView.swift
- /nkust-contest/nkust-contest/Modules/Dashboard/View/DashboardView.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/View/WalkModeView.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/ViewModel/WalkModeViewModel.swift
- /nkust-contest/nkust-contest/Modules/RecognitionMode/View/RecognitionModeView.swift
- /nkust-contest/nkust-contest/Modules/RecognitionMode/ViewModel/RecognitionModeViewModel.swift
- /nkust-contest/nkust-contest/Services/Feedback/LiveFeedbackManager.swift
- /nkust-contest/nkust-contest/Services/Feedback/ConnectionStatusAnnouncer.swift
- /nkust-contest/nkust-contest/Services/Feedback/VoiceAnnouncementCenter.swift (new)
- /README.md

**State Changes**
- LocationMapView now has `showProfile` state and interactive toolbar button
- Active sheets now bind to app-level color scheme preference in real time
- Walk/Recognition streaming switch condition expanded to `(dataSourceMode == .live && effectiveDeviceConnected == true)`
- Voice output now shares one announcer with explicit priorities: `sos > connectionAlert > navigation > low`

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- User requested “track all files then upload”; pending untracked `Sources/` and workspace `xcuserstate` are left for final staging in this task

---

### [2026-03-20 14:05]

**Feature**
- Enforce visually-impaired mode restriction when device is disconnected (block switching to other pages)
- Add live map integration for caregiver map tab in real-data mode using CoreLocation updates
- Add dashboard back button on both Summary and Map tabs

**Modules Affected**
- /nkust-contest/nkust-contest/Modules/MainTab/View/MainTabView.swift
- /nkust-contest/nkust-contest/Modules/Dashboard/View/LocationMapView.swift
- /nkust-contest/nkust-contest/Modules/Dashboard/View/DashboardView.swift
- /nkust-contest/nkust-contest/App/AppRouter.swift
- /nkust-contest/nkust-contest.xcodeproj/project.pbxproj

**State Changes**
- MainTab now forces page back to Walk when `effectiveDeviceConnected == false`
- Location map now switches behavior by data mode: mock uses fixed coordinate, live requests real location and follows updates
- Dashboard now supports explicit back navigation to role selector

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- Live location requires user authorization and the new `NSLocationWhenInUseUsageDescription` Info.plist key

---

### [2026-03-20 14:35]

**Feature**
- Strengthen disconnected-mode lock: visually-impaired users cannot switch away from Walk while device is disconnected
- Implement disconnected voice reminders with repeat cycle (immediate once on entry, then every 5 seconds counted after speech finishes)
- Integrate nearest-hospital action to open Google Maps with auto-selected nearest hospital destination
- Reduce repeated Firestore error spam by stopping listener and reporting incident on stream errors

**Modules Affected**
- /nkust-contest/nkust-contest/Modules/MainTab/View/MainTabView.swift
- /nkust-contest/nkust-contest/Services/Feedback/VoiceAnnouncementCenter.swift
- /nkust-contest/nkust-contest/Services/Feedback/ConnectionStatusAnnouncer.swift
- /nkust-contest/nkust-contest/Shared/Components/ModeHeaderBar.swift
- /nkust-contest/nkust-contest/Modules/DeviceInfo/View/DeviceInfoView.swift
- /nkust-contest/nkust-contest/Modules/Dashboard/ViewModel/DashboardViewModel.swift
- /nkust-contest/nkust-contest/Modules/Dashboard/View/DashboardView.swift
- /nkust-contest/nkust-contest/Services/Firebase/FirestoreDashboardSnapshotService.swift

**State Changes**
- MainTab selection binding now blocks non-Walk target pages when `effectiveDeviceConnected == false`
- Connection announcer now owns per-screen reminder tasks and can start/stop loops by screen lifecycle
- Voice center now supports awaited speech completion and completion-aware interruption logic
- Nearest-hospital button now performs MKLocalSearch and launches Google Maps app/web URL directly

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- Firestore “API not enabled / permission denied” still requires Firebase Console configuration; app now degrades gracefully and reports incident once per listener start

---

### [2026-03-20 15:05]

**Feature**
- Fix Swift 6 actor-safety warning by moving `AVSpeechSynthesizerDelegate` conformance to a non-actor proxy and forwarding completion events safely to `VoiceAnnouncementCenter`
- Tighten visually-impaired flow gating: when disconnected, user is kept in DeviceInfo (connection handling) and cannot enter other modes
- Add caregiver preferences voice-sample buttons (available in `mock` mode only)

**Modules Affected**
- /nkust-contest/nkust-contest/Services/Feedback/VoiceAnnouncementCenter.swift
- /nkust-contest/nkust-contest/App/AppRouter.swift
- /nkust-contest/nkust-contest/Modules/DeviceInfo/View/DeviceInfoView.swift
- /nkust-contest/nkust-contest/Modules/Dashboard/View/DashboardView.swift
- /README.md
- /docs/handoff.md

**State Changes**
- Voice completion callbacks are now routed through `VoiceSynthDelegateProxy` and resumed on MainActor
- `AppRouter` now rejects start when disconnected and auto-returns to DeviceInfo on disconnection
- Preferences now include actionable voice examples (connection alert, navigation actions, SOS) guarded by data mode

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- Existing dashboard nearest-hospital Google Maps jump and 5-second disconnected reminders remain active and documented

---

### [2026-03-24 14:42]

**Feature**
- Enable real-device stream path for `live` mode while keeping `mock` mode behavior unchanged
- Implement CoreML + Vision local inference pipeline from incoming stream frames (with model loading/cache and failure fallback)
- Wire per-frame walk flow: frame → AI result → DecisionEngine → feedback output, with action-rate limiting
- Render latest incoming frame as camera background in Walk/Recognition views for real stream validation

**Modules Affected**
- /nkust-contest/nkust-contest/Services/Stream/StreamService.swift
- /nkust-contest/nkust-contest/Services/AI/AIService.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/Service/WalkModeService.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/ViewModel/WalkModeViewModel.swift
- /nkust-contest/nkust-contest/Modules/RecognitionMode/ViewModel/RecognitionModeViewModel.swift
- /nkust-contest/nkust-contest/Shared/Components/CameraPreviewPlaceholder.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/View/WalkModeView.swift
- /nkust-contest/nkust-contest/Modules/RecognitionMode/View/RecognitionModeView.swift

**State Changes**
- `StreamDevelopmentPhase.current` now permits real MJPEG implementation (actual start/stop remains controlled by `DataSourceMode` and connection state)
- `LocalResult` now carries confidence + estimated obstacle distance to support decision input
- Walk mode now performs decision + feedback on each analyzed frame and updates direction card from latest action
- Shared camera component now displays actual frame when available, falls back to placeholder when unavailable

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- `analyzeCloud` (Gemini) remains stub (no real API call)
- Distance is currently estimated from detection bbox area for early real-time routing; can be replaced by true depth/distance model output later

---

### [2026-03-24 16:10]

**Feature**
- Harden MJPEG stream parsing by adding `multipart/x-mixed-replace` boundary handling with JPEG marker fallback
- Ensure SwiftData/CoreData store safety by creating Application Support directory before persistent store initialization

**Modules Affected**
- /nkust-contest/nkust-contest/Services/Stream/StreamService.swift
- /nkust-contest/nkust-contest/App/AppEntry.swift
- /README.md

**State Changes**
- Stream parser now tries boundary-part extraction first, then falls back to SOI/EOI marker extraction when boundary is missing
- Stream parsing remains on background utility queue; frame callback remains on main thread
- App startup now pre-creates `.applicationSupportDirectory` when missing to prevent store file creation failures

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- Change scope is initialization and parser safety only; no architecture/layer refactor

---

### [2026-03-24 17:25]

**Feature**
- Add console debug logs for mode switching and streaming lifecycle in visually impaired flow
- Fix cyclic mode switching instability by replacing uncancelled delayed wrap-jumps with cancellable task-based scheduling
- Enable LTC mode to display ESP32 stream frames in `live` + connected state, aligned with Walk/Recognition behavior
- Expand README with concrete ESP32 MJPEG frame-splitting technical details and updated live-mode/testing notes

**Modules Affected**
- /nkust-contest/nkust-contest/Modules/MainTab/View/MainTabView.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/ViewModel/WalkModeViewModel.swift
- /nkust-contest/nkust-contest/Modules/RecognitionMode/ViewModel/RecognitionModeViewModel.swift
- /nkust-contest/nkust-contest/Modules/LTCMode/View/LTCModeView.swift
- /nkust-contest/nkust-contest/Modules/LTCMode/ViewModel/LTCModeViewModel.swift
- /nkust-contest/nkust-contest/Services/Stream/StreamService.swift
- /README.md

**State Changes**
- MainTab wrap-jump now cancels stale pending tasks and validates sentinel state before applying page reset
- Added stream/status debug output prefixes: `[MainTab]`, `[WalkMode]`, `[RecognitionMode]`, `[LTCMode]`, `[MJPEGStream]`
- LTC view model now owns stream lifecycle and latest-frame state; LTC screen now renders live frame background under the same gating condition as other visually impaired modes (`DataSourceMode.live && effectiveDeviceConnected`)
- README now documents MJPEG parser internals (boundary-first + marker-fallback), buffer guard, thread model, and console verification points

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- This change keeps existing architecture boundaries (View/ViewModel/Service) and does not introduce new dependencies

---

### [2026-03-24 17:45]

**Feature**
- Replace live connection fallback flag with MJPEG stream health state machine (`disconnected` / `connecting` / `connected` / `stale`) and route `effectiveDeviceConnected` to health-derived status
- Add centralized `StreamHealthCoordinator` for visually-impaired live flow preflight monitoring (DeviceInfo/Main flow gating now follows real stream health)
- Add Walk mode debug 3x3 grid overlay toggle (`AppState.showWalkDebugGrid`) with optional bbox-to-cell highlight and debug logs

**Modules Affected**
- /nkust-contest/nkust-contest/Services/Stream/StreamService.swift
- /nkust-contest/nkust-contest/State/AppState.swift
- /nkust-contest/nkust-contest/App/AppRouter.swift
- /nkust-contest/nkust-contest/Modules/Dashboard/ViewModel/DashboardViewModel.swift
- /nkust-contest/nkust-contest/Services/AI/AIService.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/ViewModel/WalkModeViewModel.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/View/WalkModeView.swift
- /README.md

**State Changes**
- Added global stream health enum and service callback (`onHealthChange`) with transition logs
- `AppState.effectiveDeviceConnected` in `live` now returns true only when `liveStreamHealthState == .connected`
- Added `showWalkDebugGrid` app-level debug flag and Walk overlay cell-highlight state derived from model bbox center

**Test Coverage**
- xcodebuild: `-project nkust-contest/nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- Build required elevated permissions due SPM checkout/git-hooks writes in this environment
- Walk cell highlight appears only when model output includes bounding-box center; otherwise overlay shows static 3x3 grid

---

### [2026-03-24 19:00]

**Feature**
- Diagnose and fix AppRouter first-frame render bottleneck by deferring `StreamHealthCoordinator` initialization from `@State` view init to `.onAppear`

**Modules Affected**
- /nkust-contest/nkust-contest/App/AppRouter.swift
- /README.md

**State Changes**
- `streamHealthCoordinator` changed from `StreamHealthCoordinator` (eager) to `StreamHealthCoordinator?` (Optional, deferred)
- New `ensureCoordinator()` method creates coordinator + wires `onStateChange` callback on first `.onAppear`
- All coordinator call sites now use optional chaining (`streamHealthCoordinator?.startMonitoring()` / `?.stopMonitoring()`)
- README: added 啟動效能優化 section with component-level bottleneck analysis table

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- `AppState.init()`: confirmed clean (no I/O, no UserDefaults, no network)
- SwiftData `.modelContainer`: confirmed not on root view; only in `CaregiverRootContainer` (caregiver role gate)
- `LiveFeedbackManager.init()` calls `CHHapticEngine() + start()` synchronously but is only constructed on Walk mode entry — not on launch path
- `VoiceAnnouncementCenter.shared` is `static let` (lazy); first access is `DeviceInfoView.onAppear` — not on launch path

---

### [2026-03-24 19:30]

**Feature**
- Fix ESP32 live-mode connection detection: add ATS local networking exception, harden URLSession for WiFi-only routing, extend initial connect grace period, and add auto-retry with backoff in StreamHealthCoordinator

**Modules Affected**
- /nkust-contest/nkust-contest/Info.plist (new)
- /nkust-contest/nkust-contest.xcodeproj/project.pbxproj (INFOPLIST_FILE added)
- /nkust-contest/nkust-contest/Services/Stream/StreamService.swift
- /README.md

**State Changes**
- Added `Info.plist` with `NSAllowsLocalNetworking = YES` and `NSLocalNetworkUsageDescription` — removes ATS block on `http://192.168.4.1/stream`
- `MJPEGStreamService`: URLSession now sets `allowsCellularAccess = false`, `waitsForConnectivity = false` to force WiFi routing
- `MJPEGStreamService`: added `initialConnectGrace` (8s) — first connection attempt gets longer timeout before marking `stale`; subsequent frame gaps still use 2.5s `staleTimeout`
- `StreamHealthCoordinator`: added auto-retry with linear backoff (2s, 4s, 6s, 8s; max 5 attempts); resets on successful `connected`; cancels on `stopMonitoring()`

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- Root cause: no ATS exception → iOS silently blocked plain HTTP to `192.168.4.1`; compounded by no retry logic and aggressive 2.5s stale timeout for initial connection
- `NSAllowsLocalNetworking` covers local IP ranges (192.168.x.x); no need for `NSAllowsArbitraryLoads`
- iOS may show a one-time "allow local network access" prompt on first connection attempt

---

### [2026-03-24 20:15]

**Feature**
- Fix connect-disconnect loop when entering visually impaired main flow in live mode
- Add manual reconnect button and live connection status display to DeviceInfoView

**Modules Affected**
- /nkust-contest/nkust-contest/Services/Stream/StreamService.swift
- /nkust-contest/nkust-contest/App/AppRouter.swift
- /nkust-contest/nkust-contest/Modules/DeviceInfo/View/DeviceInfoView.swift
- /README.md

**State Changes**
- `StreamHealthCoordinator.stopMonitoring(preserveHealthState:)`: new parameter; when `true`, sets `ignoreHealthUpdates` flag so the async `.disconnected` callback from the stopped stream doesn't propagate to AppState
- `StreamHealthCoordinator.forceReconnect()`: new method; stops current stream, resets retry count, immediately starts fresh connection attempt
- `AppRouter.syncLiveMonitoring()`: when stopping because `showMainFlow == true` (user entered main flow after successful preflight), passes `preserveHealthState: true` to keep `liveStreamHealthState` as `.connected`
- `DeviceInfoView`: added `onReconnect` callback; shows "重新連線" button when disconnected in live mode; connection status text now shows 4 states (連線中.../已連接/訊號不穩/未連接) with color-coded display

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- Root cause of loop: `canStartLiveMonitoring` requires `!showMainFlow`; coordinator detected `connected` → user enters main flow → coordinator stops → health resets to `disconnected` → user kicked out → coordinator restarts → loop
- Fix preserves health state when the stop reason is "user is entering main flow" (not "user changed mode/role")
- `ignoreHealthUpdates` flag blocks the async `onHealthChange` callback that arrives after `monitorService.stop()` returns

---

### [2026-03-24 21:05]

**Feature**
- Reduce main-thread persistence pressure by introducing debounced SwiftData saves for caregiver dashboard preference changes
- Delay caregiver settings hydration slightly after dashboard presentation to keep first interaction responsive

**Modules Affected**
- /nkust-contest/nkust-contest/Shared/Persistence/AppSettingsPersistence.swift
- /nkust-contest/nkust-contest/Modules/Dashboard/View/DashboardView.swift
- /nkust-contest/nkust-contest/App/AppRouter.swift
- /README.md

**State Changes**
- `AppSettingsPersistence` adds `scheduleSave(...)` and `cancelScheduledSave()` to coalesce rapid preference changes into one delayed save
- Dashboard `onChange` handlers now call debounced persistence instead of immediate `context.save()` per change
- Profile/Preferences close paths cancel pending debounce before explicit save to avoid duplicate writes
- `CaregiverDashboardHost` persistence load changed to async task with short delay (`250ms`) before `loadOrCreateSettings`

**Test Coverage**
- xcodebuild: `-project nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- This change is designed to mitigate UI stutter and "forced sync" pressure from bursty SwiftData writes during interactive toggles

---

### [2026-03-24 23:04]

**Feature**
- Integrate full live-mode multi-model inference pipeline with YOLO (detection), MiDaS (depth), PIDNet (segmentation), and fusion-based navigation output
- Replace bbox-area-only distance dependency with MiDaS ROI depth as primary distance source (bbox fallback retained)
- Update Walk/Recognition live UI text and voice trigger path to reflect fusion output (object + distance + semantic walkability)

**Modules Affected**
- /nkust-contest/nkust-contest/Services/AI/AIService.swift
- /nkust-contest/nkust-contest/Modules/WalkMode/ViewModel/WalkModeViewModel.swift
- /nkust-contest/nkust-contest/Modules/RecognitionMode/ViewModel/RecognitionModeViewModel.swift
- /README.md

**State Changes**
- Added structured model outputs: `DetectedObject`, `DepthResult`, `SegmentationResult`, `FusionDecision`
- Added live runners: `YOLORunner`, `MiDaSRunner`, `PIDNetRunner` with model spec logging from `modelDescription` (no hardcoded feature names)
- Added per-frame fusion debug logs and decision logs (`[AIFusion][Frame]`, `[AIFusion][Decision]`) with runtime toggle key `ai.debug.logs.enabled`
- Recognition mode now uses local fusion summary in live stream loop, avoiding per-frame cloud stub incident noise

**Test Coverage**
- xcodebuild: `-project nkust-contest/nkust-contest.xcodeproj -scheme nkust-contest -destination 'generic/platform=iOS' -derivedDataPath ./DerivedData build`
- Result: PASS

**Notes**
- PIDNet semantic labels currently use Cityscapes 19-class mapping
- If any model fails in a frame, system reports incident and degrades gracefully without crash
