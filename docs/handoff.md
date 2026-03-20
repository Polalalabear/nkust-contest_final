# 交接文件 (Handoff Document)

> 最後更新：2026-03-20

本文件旨在讓下一位開發者/AI 快速理解專案全貌、目前進度與待辦事項。

---

## 0. 開發流程與使用者要求（每次對話／任務結束前檢查）

以下為本專案與使用者約定之工作方式，**下一任 AI 或開發者請務必遵守**：

| 項目 | 要求 |
|---|---|
| **閱讀文件** | 實作前必讀：`architecture.md`、`tech-state.md`、`ui-spec.md`、`prd.md`、`state-schema.md`；涉及相機/ESP32 串流時必讀 **`device-connection.md`** |
| **架構限制** | 嚴守 MVVM 分層；Engine 純邏輯；相機輸入僅能經 `StreamService`；現階段串流用 **Mock**（見 device-connection） |
| **技術限制** | 不可自行引入未列入 `tech-state.md` 的技術；本專案已核准 **Firebase + SwiftData**，以 README 契約為準 |
| **疑慮處理** | 若需求與文件定義、資料範圍、Firestore 路徑等有歧義，**先向使用者確認**再改程式 |
| **狀態日誌** | 每次可驗證的實作完成後 **append** `docs/state-schema.md`（禁止覆寫歷史） |
| **README** | 資料契約、技術棧、流程有變時同步更新 `README.md` |
| **本交接文件** | 架構/流程/待辦變動時更新 `docs/handoff.md` |
| **版本號** | 依使用者要求，重大功能迭代時更新 `AppState.appVersion` |
| **Git** | 小步提交、訊息建議 `core:` / `ui:` / `model:` / `infra:`；完成後 **`git push`** 至約定遠端（若使用者有要求） |

---

## 1. 專案簡介

**視障輔助導航系統** — 即時視覺輔助導航決策系統，將攝影機畫面轉換為行動指令（停止 / 左移 / 右移 / 安全），協助視障者安全行走。

核心理念：**這不是一個 App，而是一個附有 UI 的即時決策系統。**

### 使用者角色

| 角色 | 說明 |
|---|---|
| 視障者 | 主要使用者，使用行走/辨識/長照三種模式 |
| 照護者 | 監控健康數據、即時定位、緊急通話 |

---

## 2. 必讀文件（開始前務必閱讀）

| 文件 | 位置 | 內容 |
|---|---|---|
| 產品需求 | `/docs/prd.md` | 產品概念、功能、非目標 |
| 架構規範 | `/docs/architecture.md` | MVVM 分層、嚴格規則、資料流 |
| UI 規格 | `/docs/ui-spec.md` | 畫面設計、互動規格 |
| 技術棧 | `/docs/tech-state.md` | 允許使用的技術；**本專案含 Firebase + SwiftData 例外註記** |
| 裝置與串流 | `/docs/device-connection.md` | ESP32 MJPEG、URLSession、現階段 Mock 規則 |
| 狀態日誌 | `/docs/state-schema.md` | 機器可讀開發日誌（每次改動需 append） |
| 模型角色 | `/.cursor/rules/model-roles.md` | AI 模型的角色限制 |
| UI 角色 | `/.cursor/rules/ui-roles.md` | UI 開發的角色限制 |
| 設計稿 | `/ui/*.png` | 所有畫面的參考圖片 |

---

## 3. 架構概覽

```
MVVM + 嚴格分層（單向資料流）
Camera → AI → DecisionEngine → Feedback → User
```

### 分層結構

| 層級 | 職責 | 規則 |
|---|---|---|
| **View** | 純 UI 呈現 | 不含邏輯、不呼叫 API |
| **ViewModel** | 狀態管理 (@Observable) | 轉換資料給 UI，呼叫 Service/Engine |
| **Service** | 外部互動抽象 | 目前全部為 Stub，TODO 接入真實服務 |
| **Engine** | 純邏輯 | 無框架依賴，完全可測試 |

### 全域狀態

`AppState` (`@Observable`) 位於 `/State/AppState.swift`，包含：
- `userRole` — 使用者身份（視障者/照護者/nil）
- `currentMode` — 當前模式（行走/辨識/長照）
- `isVoiceEnabled` / `isMuted` — 語音控制
- `deviceConnected` / `deviceBattery` / `phoneBattery` — 裝置狀態
- `isLocationSharing` — 定位分享

---

## 4. 專案結構

```
nkust-contest/nkust-contest/
├── App/
│   ├── AppEntry.swift          # @main 入口
│   └── AppRouter.swift         # 根據 userRole 路由
├── State/
│   └── AppState.swift          # 全域狀態 (@Observable)
├── Shared/
│   ├── Models/
│   │   ├── AppMode.swift       # UserRole + AppMode 列舉
│   │   ├── DataSourceMode.swift # mock / live（照護者資料來源）
│   │   ├── DecisionModels.swift # 障礙物/方向/號誌/聯絡人模型
│   │   └── HealthModels.swift  # 健康紀錄 + 指標 + 期間 + 排序 + ChartStyle
│   ├── Persistence/
│   │   ├── LocalSwiftDataModels.swift # PersistedAppSettings, PersistedHealthDayRecordEntity
│   │   ├── AppSettingsPersistence.swift
│   │   └── HealthRecordsPersistence.swift
│   └── Components/
│       ├── CameraPreviewPlaceholder.swift
│       ├── HealthChartView.swift   # 可切換長條圖/折線圖/圓餅圖（Swift Charts）
│       ├── ModeHeaderBar.swift
│       ├── OverlayCard.swift
│       ├── SwipeHintBar.swift
│       └── VoiceToggleButton.swift
├── Modules/
│   ├── ChooseUser/View/        # 身份選擇畫面
│   ├── DeviceInfo/View/        # 裝置資訊畫面（含返回按鈕）
│   ├── MainTab/View/           # 頁面滑動容器（循環滑動）
│   ├── WalkMode/               # 行走模式 (View/ViewModel/Service/Engine)
│   ├── RecognitionMode/        # 辨識模式 (View/ViewModel/Service/Engine)
│   ├── LTCMode/                # 長照模式 (View/ViewModel/Service/Engine)
│   └── Dashboard/              # 照護者儀表板
│       ├── View/
│       │   ├── DashboardView.swift      # 主容器 (TabView: 摘要 + 地圖)
│       │   ├── HealthDetailView.swift   # 單項健康指標詳細 (期間/排序/每日紀錄)
│       │   ├── AllHealthDataView.swift  # 月曆式全部健康資料
│       │   └── LocationMapView.swift    # 即時定位地圖
│       ├── ViewModel/DashboardViewModel.swift
│       ├── Service/DashboardService.swift
│       └── Engine/DashboardEngine.swift
├── Services/
│   ├── Firebase/
│   │   ├── FirestoreDashboardSnapshot.swift
│   │   └── FirestoreDashboardSnapshotService.swift
│   ├── AI/AIService.swift              # Stub — TODO: CoreML / Gemini
│   ├── Stream/StreamService.swift      # Stub — TODO: MJPEG（須遵守 device-connection.md）
│   ├── Feedback/FeedbackService.swift
│   └── Feedback/LiveFeedbackManager.swift
└── Core/Engine/
    ├── DecisionEngine.swift    # 核心決策引擎 (Stub — TODO: 實作)
    └── FeedbackManager.swift   # 回饋管理器 (Stub — TODO: 實作)
```

---

## 5. 導航流程

```
ChooseUserView
├── 選擇「視障者」→ DeviceInfoView → [開始] → MainTabView (循環滑動)
│   ├── WalkModeView (tag 1)
│   ├── RecognitionModeView (tag 2)
│   └── LTCModeView (tag 3)
│   (tag 0 / 4 = 哨兵頁，實現循環)
│
└── 選擇「照護者」→ DashboardView
    ├── Tab 1: SummaryView
    │   ├── 圖表顯示 toggle
    │   ├── 健康卡片 → NavigationLink → HealthDetailView
    │   ├── 顯示所有健康資料 → NavigationLink → AllHealthDataView (底部含匯出 CSV)
    │   └── 個人資訊按鈕 → Sheet → ProfileSheetView
    │       ├── 個人資料（可編輯）
    │       ├── 設定偏好 → PreferencesView（圖表樣式+預覽、日夜模式、圖表開關）
    │       └── 登出
    └── Tab 2: LocationMapView
```

---

## 6. 目前進度

### ✅ 已完成

- [x] MVVM 骨架建立 + 全模組資料夾結構
- [x] `@Observable` 全面遷移（AppState + 所有 ViewModel）
- [x] SF Symbols 全面採用
- [x] 全畫面 UI 實作（依照 `/ui/` 設計稿）
- [x] 角色選擇流程（ChooseUserView → DeviceInfoView → MainTabView / DashboardView）
- [x] 頁面循環滑動（末頁→首頁，首頁→末頁）
- [x] 所有返回按鈕正確接線
- [x] 照護者個人資訊頁面 + 登出功能
- [x] 健康數據卡片（步數、距離、站立分鐘）含每日/週/月/三月資料
- [x] 單項健康指標詳細頁面（HealthDetailView）— 平均值 + 期間篩選 + 排序 + 每日紀錄
- [x] 月曆式全部健康資料頁面（AllHealthDataView）— 日曆 + 日期點擊詳細 + 期間平均 + 排序
- [x] 健康圖表（HealthChartView）— 長條圖/折線圖/圓餅圖切換（Swift Charts）
- [x] 一鍵取得視障者即時位置 + 顯示最近醫院按鈕
- [x] 照護者個人資料可編輯（姓名、關係、緊急聯絡電話）
- [x] Dashboard 移除裝置狀態列（僅保留於個人資訊）
- [x] 版本號管理（v1.1.0 → v1.2.0）
- [x] 圖表顯示 toggle（Dashboard / HealthDetail / AllHealthData）
- [x] 圖表樣式選擇移至「設定偏好」（含即時預覽）
- [x] 日間/夜間模式切換（PreferencesView → .preferredColorScheme）
- [x] 日期格式統一 M/d（e.g. 3/15）
- [x] 匯出 CSV 按鈕（AllHealthDataView 底部，stub，可選時間範圍）
- [x] DefaultDecisionEngine + LiveFeedbackManager + DefaultWalkModeService 行走模式串接
- [x] 版本 v1.3.0 → **v1.4.0**（SwiftData + Firestore 照護者資料模式）
- [x] Firebase（`FirebaseApp.configure()` + SPM 套件）+ `GoogleService-Info.plist`
- [x] SwiftData：`PersistedAppSettings`、`PersistedHealthDayRecordEntity` + 啟動載入/儲存
- [x] 照護者主控台：裝置狀態（已連線／**尚未連線**）、測試資料／真實資料切換
- [x] `FirestoreDashboardSnapshotService` 監聽 `dashboard/caregiver_primary`
- [x] `#Preview` 加入所有 View 檔案
- [x] README.md + .gitignore
- [x] CoreHaptics 自訂節奏（強停／短-短／短-長）已接入 `LiveFeedbackManager`（含 UIKit fallback）
- [x] 視障者 UI（DeviceInfo + ModeHeader）吃 `mock/live` 同步連線狀態，未連線時語音告知使用者
- [x] `MJPEGStreamService`（URLSession + 手動 JPEG 解析）已完成，預設仍依階段規則使用 Mock
- [x] 視障者未連線時僅可停留連線處理畫面；不可進入 Walk/Recognition/LTC
- [x] 連線警示語音改為「進入先播一次，播報結束後每 5 秒重播」
- [x] 照護者「一鍵取得附近醫院」會開啟 Google Maps 並選取最近醫院
- [x] 偏好設定新增語音範例按鈕（僅 mock 模式可觸發）

### ❌ 待完成（依優先順序）

| 優先級 | 任務 | 說明 |
|---|---|---|
| 🟡 P1 | AI Service 接入 | CoreML 或 Gemini API 整合 |
| 🟡 P1 | MJPEG 真機啟用切換 | `MJPEGStreamService` 已完成；待專案進入下一階段時將 `StreamDevelopmentPhase` 改為 `realDeviceAllowed` |
| 🟡 P1 | 真實攝影機整合 | AVFoundation 替換 CameraPreviewPlaceholder |
| 🟡 P1 | 真實定位整合 | CoreLocation 替換靜態座標 |
| 🟡 P1 | CSV 匯出實作 | ShareLink / UIActivityViewController 實際匯出 |
| 🟢 P2 | HealthKit 整合 | 替換 mock 健康數據 |
| 🟢 P2 | 使用者認證 | 替換 placeholder email/name |
| 🟢 P2 | SwiftData 本地儲存 | 持久化設定（偏好、暗色模式）與歷史紀錄 |
| 🟢 P2 | 無障礙優化 | VoiceOver 完整測試與修正 |
| ⚪ P3 | 單元測試 | Engine 層 + ViewModel 測試 |
| ⚪ P3 | UI 測試 | 關鍵導航流程自動化測試 |

---

## 7. 技術重點

### 使用的技術（不可自行新增其他）

- SwiftUI (iOS 26) + `@Observable` macro
- SF Symbols
- MapKit
- async/await
- 原則：原生 Apple 框架優先，最少依賴

### 禁止使用

Firebase、Realm、WebSockets、第三方 UI 框架、任何未列於 `tech-state.md` 的 SDK

### Git 規範

- 小步提交，每次一個功能
- Commit message 格式：`core:` / `ui:` / `model:` / `infra:`
- 每次成功實作後 **必須** append `/docs/state-schema.md`

---

## 8. 快速開始

```bash
# 1. Clone
git clone https://github.com/Polalalabear/nkust-contest_final.git

# 2. 用 Xcode 開啟
open nkust-contest/nkust-contest.xcodeproj

# 3. 選擇 iOS Simulator (iPhone 16 Pro 建議)

# 4. Build & Run (Cmd+R)
```

### CLI 編譯

```bash
cd nkust-contest
xcodebuild -project nkust-contest.xcodeproj \
  -scheme nkust-contest \
  -destination 'generic/platform=iOS' \
  -derivedDataPath ./DerivedData \
  build
```

> ⚠️ `#Preview` 在 CLI sandbox 環境下可能出現 macro plugin 錯誤，但在 Xcode 中正常編譯。

---

## 9. 已知限制

- 所有 Service 都是 Stub（回傳假資料）
- 攝影機畫面為灰色方塊 placeholder
- 地圖使用靜態座標（高雄科技大學）
- 健康數據為隨機 mock 資料
- 循環滑動使用 `DispatchQueue.main.asyncAfter(0.3s)` 延遲跳轉
- Profile email/name 為硬編碼 placeholder

---

## 10. 關鍵決策紀錄

| 日期 | 決策 | 原因 |
|---|---|---|
| 2026-03-19 | 從 `ObservableObject` 遷移至 `@Observable` | 使用者要求 iOS 26 最新語法 |
| 2026-03-19 | 循環滑動用 sentinel page 方案 | SwiftUI TabView 不原生支援循環 |
| 2026-03-19 | 導航用 closure (`onBack`) 而非 NavigationStack path | 視障者流程為線性，不需要複雜路由 |
| 2026-03-19 | 健康資料用 mock 而非 HealthKit | 架構規範要求外部服務必須 Stub |
| 2026-03-19 | 使用 Swift Charts 而非第三方圖表庫 | 原生 Apple 框架，符合 tech-stack.md |
| 2026-03-19 | 照護者資料存於 AppState (in-memory) | TODO: 未來用 SwiftData 持久化 |

---

## 11. 對下一個 AI 助手的提醒

1. **開始前必讀**：`prd.md` → `architecture.md` → `tech-state.md` → `ui-spec.md` → 本文件
2. **不可跳過 state-schema.md 更新** — 每次改動成功後必須 append
3. **不可引入新技術** — 除非使用者明確要求且符合 tech-state.md
4. **優先順序**：architecture.md > tech-state.md > roles > prompt
5. **編譯驗證**：每次改動後用 `xcodebuild` 驗證，使用 `required_permissions: ["all"]` 避免 sandbox 問題
6. **Git**：小步提交，格式 `core:` / `ui:` / `model:` / `infra:`
7. **前次對話 ID**：`8558c625-5f6b-4ef5-b045-645cbc35aa78`（可查閱完整歷史）
