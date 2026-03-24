# 視障輔助導航系統 (Vision-Assisted Navigation System)

即時視覺輔助導航決策系統，將攝影機畫面轉換為行動指令，協助視障者安全行走。

## 功能模組

| 模組 | 說明 | 狀態 |
|---|---|---|
| 行走模式 (Walk Mode) | 即時障礙偵測 + 方向指引 + 號誌辨識 | UI 完成；DefaultDecisionEngine + LiveFeedbackManager 已接 |
| 辨識模式 (Recognition Mode) | 物品辨識 + AI 描述 | UI 完成，AI Stub |
| 長照模式 (LTC Mode) | 位置分享 + 緊急通話 | UI 完成，通話 Stub |
| 照護者儀表板 (Dashboard) | 健康數據 + 裝置狀態 + 測試/真實資料切換 + 地圖 | SwiftData + Firestore 快照已接 |

## 架構

```
MVVM + 嚴格分層
View → ViewModel → Service → Engine
```

- **View**: SwiftUI，僅負責 UI 呈現  
- **ViewModel**: @Observable 狀態管理  
- **Service**: 外部互動（部分已接 Firebase / 本地持久化）  
- **Engine**: 純邏輯（DecisionEngine 等）

## 技術棧

- SwiftUI (iOS 26)、@Observable、Swift Charts、SF Symbols、MapKit  
- **SwiftData**（本地設定 + 健康日資料快取）  
- **Firebase**（SPM：`FirebaseCore`、Firestore、Auth、Analytics、AI 等 — 以專案已連結為準）  
- MVVM  

詳見 `/docs/tech-state.md`（含 Firebase 專案例外與 MJPEG 限制）。

## 資料結構契約

### SwiftData（`Shared/Persistence/LocalSwiftDataModels.swift`）

| 模型 | 說明 | 主要欄位 |
|---|---|---|
| `PersistedAppSettings` | 全 app 單例設定列（`singletonId == "app_settings_singleton"`） | `dataSourceModeRaw`（`mock` / `live`）、`mockDeviceConnected`、`showCharts`、`isDarkMode`、`preferredChartStyleRaw`（對應 `ChartStyle.rawValue`）、`caregiverName`、`caregiverRelationship`、`caregiverEmergencyPhone` |
| `PersistedHealthDayRecordEntity` | 每日健康一筆（本地快取／真實模式合併） | `dayStart`（當日 00:00，**unique**）、`steps`、`distanceKm`、`standingMinutes` |

**持久化輔助**：`AppSettingsPersistence`、`HealthRecordsPersistence`（`seedIfEmpty` 首次寫入 mock 三個月列）。

### Firebase Firestore（照護者「真實資料」）

**文件路徑**（常數：`FirestoreDashboardPaths.caregiverPrimaryDocument`）：

`dashboard/caregiver_primary`

| 欄位 | 型別（概念） | 說明 |
|---|---|---|
| `connected` | bool | `true` 時主控台顯示「已連線」 |
| `deviceBattery` | int | 0–100 |
| `phoneBattery` | int（可選） | 同步至 `AppState.phoneBattery` |
| `isLocationSharing` | bool（可選） | 同步至 `AppState.isLocationSharing` |
| `steps` | int（可選） | 當日步數；寫入 SwiftData「今日」列並刷新圖表 |
| `distanceKm` | double（可選） | 當日距離（公里） |
| `standingMinutes` | int（可選） | 當日站立分鐘 |

監聽實作：`FirestoreDashboardSnapshotService`（失敗或無文件時不 crash，`liveFirestoreSnapshot` 為 `nil` → UI 顯示「尚未連線」）。

### 照護者資料來源模式（`DataSourceMode`）

| 模式 | 行為 |
|---|---|
| `mock`（測試資料） | 健康曲線為記憶體假資料；可開關「模擬裝置已連線」 |
| `live`（真實資料） | Firestore 監聽 + SwiftData 讀寫合併；未連上或 `connected == false` → **尚未連線** |

> `AppState.effectiveDeviceConnected` 已同時提供給照護者與視障者 UI（如 DeviceInfo / Walk / Recognition / LTC 狀態列）使用；在 `live` 模式下，狀態改由 MJPEG 串流健康度推導（僅 `connected` 視為已連線）。

### 與 ESP32 相機串流（必讀）

`/docs/device-connection.md`：目前 `StreamDevelopmentPhase.current` 已允許 `MJPEGStreamService`，並由 `StreamHealthCoordinator` 監測串流健康度（`disconnected` / `connecting` / `connected` / `stale`）；上層仍以 `DataSourceMode.live && effectiveDeviceConnected` 決定是否啟用實際串流畫面。`mock` 模式仍只走 Mock 行為。Firestore 與 MJPEG 為不同資料路徑。

---

## 疑慮與建議由產品／使用者確認事項

1. **Firestore 文件路徑**是否長期固定為 `dashboard/caregiver_primary`，或需改為每使用者／每配對一文件？若變更請同步改 `FirestoreDashboardPaths` 與本 README。  
2. **安全規則**：目前假設客戶端可讀該文件；正式環境是否改為 Auth uid 綁定 collection？  
3. **「真實資料」健康歷史**：目前以 SwiftData 快取 + Firestore 當日欄位為主；若需「僅雲端、不落地」或「完整 90 天全在 Firestore」請另定契約。  

---

## 專案結構（精簡）

```
nkust-contest/nkust-contest/
├── App/
├── State/                 # AppState
├── Shared/
│   ├── Models/
│   ├── Components/
│   └── Persistence/       # SwiftData 模型 + Persistence helpers
├── Modules/               # Walk / Recognition / LTC / Dashboard …
├── Services/
│   ├── Firebase/          # FirestoreDashboardSnapshotService
│   ├── AI / Stream / Feedback …
└── Core/Engine/
```

## 開發狀態

> 最後更新：2026-03-24 · App 版本見 `AppState.appVersion`（目前 **v1.4.0**）

- [x] Firebase 初始化（`AppDelegate` + `GoogleService-Info.plist`）  
- [x] SwiftData 容器 + 設定／健康日模型  
- [x] 照護者：裝置狀態列、測試/真實資料切換、Firestore 監聯  
- [x] DecisionEngine / LiveFeedbackManager / WalkMode 串接  
- [x] CoreHaptics 自訂節奏（LiveFeedbackManager：強停 / 短短 / 短長）  
- [x] MJPEG 真實串流服務（`MJPEGStreamService`，URLSession + 手動 JPEG 解析）  
- [x] `live` 模式主線打通（Stream frame → CoreML/Vision → DecisionEngine → Feedback）  
- [x] MJPEG parser 強化：支援 `multipart/x-mixed-replace` boundary 解析，並保留 JPEG marker fallback  
- [x] 視障者三模式（Walk / Recognition / LTC）在 `live` + 已連線時皆可顯示最新 ESP32 frame  
- [x] SwiftData/CoreData 初始化安全：啟動前先確保 `Application Support` 目錄存在，避免 default.store 建檔失敗  
- [x] 啟動效能：`StreamHealthCoordinator` 延遲初始化（Optional + `ensureCoordinator()`），避免 View init 路徑分配 MJPEGStreamService  
- [x] ATS 例外：`NSAllowsLocalNetworking` + `NSLocalNetworkUsageDescription` 允許 ESP32 HTTP 本地連線  
- [x] 連線韌性：初始連線寬限 8s、URLSession 強制 WiFi、coordinator 自動重試（最多 5 次指數退避）  
- [ ] CSV 實際匯出  
- [ ] Firebase Auth 與欄位級安全規則落地  

## 實際模式（Live）最新確認

- `mock` 模式維持原行為（測試資料 + 可切換模擬連線）。
- `live` 模式目前會嘗試：
  1) 連 ESP32 MJPEG（`http://192.168.4.1/stream`）  
  2) 每幀送入 `LiveAIService`（CoreML + Vision）  
  3) 生成導航上下文後交給 `DefaultDecisionEngine`  
  4) 經 `LiveFeedbackManager` 輸出語音／震動  
- Walk / Recognition / LTC 背景可顯示最新 frame（無畫面時回退 placeholder）。
- 串流資料解析在背景 queue 進行，`onFrame` 回主執行緒更新 UI（避免主執行緒阻塞）。

## ESP32 MJPEG 切幀技術細節

- 入口：`Services/Stream/StreamService.swift` 的 `MJPEGStreamService`（`URLSessionDataDelegate`）。
- 連線建立：`start()` 對 `http://192.168.4.1/stream` 建立長連線，`didReceive response` 時檢查 `Content-Type`。
- 解析策略（兩段式）：
  1) **Boundary parser 優先**：若 header 含 `multipart/x-mixed-replace; boundary=...`，先用 boundary 切每個 part，再從 part 的 body 抽 JPEG。  
  2) **JPEG marker fallback**：若 boundary 缺失或異常，改用 `FFD8`/`FFD9`（SOI/EOI）掃描切幀。
- 記憶體保護：`maxBufferBytes`（2MB）避免異常流導致 buffer 無限增長。
- 執行緒模型：解析在 `mjpeg.stream.processing` 背景 queue；`emit(frame:)` 回主執行緒更新 UI。
- 失敗策略：`didCompleteWithError` 僅送 `nil frame`，不 crash、不激進重試（符合 `/docs/device-connection.md`）。
- Console 偵錯重點（可在 Xcode Console 觀察）：
  - `[MJPEGStream] start stream request ...`
  - `[MJPEGStream] first frame received`
  - `[MJPEGStream] timeout stale ...`
  - `[MJPEGStream] stop stream request`
  - `[MJPEGStream] connected status=...`
  - `[MJPEGStream] boundary parser enabled=true/false`
  - `[ConnectionState] ...`（健康狀態轉移）
  - `[ConnectionState] coordinator retry #N in Xs`（自動重連排程）
  - `[ConnectionState] coordinator retry #N executing`（重連執行）
  - `[ConnectionState] coordinator max retries (5) reached, giving up`（最終放棄）
  - `[WalkMode] ...` / `[RecognitionMode] ...` / `[LTCMode] ...`（模式層串流同步）
  - `[WalkDebugGrid] ...`（九宮格開關與 bbox 對應 cell）
  - `[MainTab] ...`（模式切換與循環跳轉）

## ESP32 連線韌性（Connection Resilience）

- **ATS 例外**：`Info.plist` 設定 `NSAllowsLocalNetworking = YES`，允許 `http://192.168.4.1/stream` 的明文 HTTP 連線（ESP32 AP 無 HTTPS）。
- **強制 WiFi 路由**：URLSession 設 `allowsCellularAccess = false` + `waitsForConnectivity = false`，確保走 ESP32 AP 的 WiFi 而非行動網路。
- **初始連線寬限**：首次連線允許 8 秒（`initialConnectGrace`）才標記為 `stale`；收到首幀後切回 2.5 秒短逾時。
- **自動重試**：`StreamHealthCoordinator` 偵測到 `disconnected`（URLSession 失敗）後自動重連，間隔 2s → 4s → 6s → 8s（最多 5 次），收到 `connected` 後重置計數。
- **iOS 本地網路提示**：首次嘗試連線時 iOS 會顯示「允許存取本地網路」彈窗（`NSLocalNetworkUsageDescription`）。

## Walk 九宮格 Debug Overlay

- 位置：`WalkModeView` 相機畫面上方（3x3 半透明細線）。
- 開關：`AppState.showWalkDebugGrid`（目前預設 `false`），Walk 畫面內可直接切換「顯示九宮格偵錯」。
- bbox 對應：若模型回傳 bounding box 中心點，會高亮命中格並輸出 `[WalkDebugGrid] mapped bbox center ... row=... col=...`。
- 無障礙：九宮格 overlay 設為 `accessibilityHidden(true)` 且不接收觸控事件，不會被 VoiceOver 當成互動元件。

## 啟動效能優化（Launch Performance）

已排查並解決 AppRouter 首幀渲染瓶頸。分析結論：

| 組件 | 是否阻塞首幀？ | 處理方式 |
|------|---------------|---------|
| `StreamHealthCoordinator` | **是** — `@State` 在 view init 時同步建立 `MJPEGStreamService`（NSObject + DispatchQueue + Data buffer） | 改為 `Optional`，延遲到 `.onAppear` 的 `ensureCoordinator()` 建立 |
| `AppState` | 否 — 純值型別預設值指定，無 I/O | 不變 |
| SwiftData `.modelContainer` | 否 — 僅在 `CaregiverRootContainer` 使用，不影響初始路徑 | 不變 |
| `LiveFeedbackManager` (CHHapticEngine) | 否（首幀） — 僅在進入 Walk 模式時才建立 | 不變（日後可考慮 lazy init） |
| `VoiceAnnouncementCenter` (AVSpeechSynthesizer) | 否 — `static let shared` lazy 初始化，首次存取在 DeviceInfoView | 不變 |

Console 驗證：啟動時應依序看到：
- `[AppStartup] AppRouter onAppear`
- `[AppStartup] StreamHealthCoordinator deferred init begin`
- `[AppStartup] StreamHealthCoordinator deferred init end`

## 持久化初始化安全（CoreData/SwiftData）

- `AppEntry` 啟動時會先檢查並建立 `.applicationSupportDirectory`（若不存在）。
- 目標是避免 `default.store` 建立前發生：
  - `Failed to stat path`
  - `Failed to create file; code = 2`

## Sources/CoreEngine 檢查（2026-03-24）

已再次確認 `Sources/CoreEngine` 三個模型包目前皆包含完整基本結構：

- `PIDNet_S_Cityscapes_val.mlpackage/Data/com.apple.CoreML/model.mlmodel`
- `PIDNet_S_Cityscapes_val.mlpackage/Data/com.apple.CoreML/weights/weight.bin`
- `midas_v21_small_256.mlpackage/Data/com.apple.CoreML/model.mlmodel`
- `midas_v21_small_256.mlpackage/Data/com.apple.CoreML/weights/weight.bin`
- `yolo26n.mlpackage/Data/com.apple.CoreML/model.mlmodel`
- `yolo26n.mlpackage/Data/com.apple.CoreML/weights/weight.bin`

若後續模型包再發生缺失，系統會 fallback 並回報 incident（不 crash）。

## API Key 放置與資安規範（務必遵守）

### 1) Key 要放哪裡

- **Firebase key**：由本機 `GoogleService-Info.plist` 提供（此檔已在 `.gitignore`，不可提交）。
- **Gemini/其他雲端 key**：請放在本機私有設定檔（建議 `nkust-contest/Secrets.xcconfig`），透過 Build Settings 注入，不可硬編碼在 `.swift`。

### 2) 禁止事項（避免外洩）

- 不可把 key 寫進 `README.md`、程式碼常數、截圖、commit message。
- 不可把 `GoogleService-Info.plist` 或私有 `Secrets.xcconfig` 提交到 GitHub。
- 不可在公開 issue / PR 直接貼完整 token。

### 3) 最低資安要求

- key 一律使用最小權限與環境隔離（dev/staging/prod 分離）。
- 發現疑似外洩時：**立即撤銷（revoke）並輪替（rotate）**，同時檢查存取紀錄。
- 雲端規則（Firestore / API）必須限制來源與身分，不可只靠 App 端隱藏 key。

## 測試指引（ESP32 / CoreML / Gemini）

### 1) ESP32 串流是否正確連線

1. iPhone 先手動連上 `XIAO-S3-CAM`（密碼 `password123`）。
2. 進入照護者主控台，切到「真實資料」模式（`DataSourceMode.live`）。
3. 進入視障者 `Walk` / `Recognition` / `LTC`，確認畫面背景會更新為 ESP32 frame；若來源暫時中斷，應顯示 placeholder 並可在 Console 看到 `received nil frame` log。
4. 若切回「測試資料」模式（`mock`），串流應立即停止（只走 Mock）。
5. 在 `live` 模式觀察 `ConnectionState`：應有 `connecting -> connected`，若中斷超過約 2.5 秒應轉為 `stale`，停止監測時轉 `disconnected`。

### 1-1) Walk 九宮格 Overlay 驗證

1. 進入 Walk 模式後開啟「顯示九宮格偵錯」。
2. 確認畫面出現半透明 3x3 格線，且不遮擋主要方向/提示卡片。
3. 若模型有 bbox 中心點，確認 Console 輸出 `[WalkDebugGrid] mapped bbox center ...` 與對應格子高亮。
4. 關閉開關後，Console 需輸出 `[WalkDebugGrid] overlay disabled` 且格線消失。

### 2) CoreML 模型是否真的被使用

1. 僅在 `live` 模式下，`Walk` / `Recognition` 會嘗試走 `LiveAIService`。
2. 若模型載入成功，`Recognition` 會持續更新模型判斷文字；`Walk` 會用模型結果更新障礙狀態。
3. 若模型缺失或推論失敗，系統會立即上報 `SystemIncidentCenter`（通知名：`systemIncidentReported`，並寫入系統 log）。
4. 目前 repo 的 `Sources/CoreEngine/*.mlpackage` 若只有 `Manifest.json`（缺 `com.apple.CoreML/model.mlmodel` 與 `weights`），即視為模型包不完整，會觸發上報並 fallback。

### 3) Gemini API 是否真的串上去

1. 現階段 `analyzeCloud` 仍為 stub（尚未發送實際 Gemini 請求）。
2. 每次呼叫會回報 `Gemini 尚未接入` 事件到 `SystemIncidentCenter`，可用於驗證目前仍是 stub 行為。
3. 後續若接入真 API，請以封包/伺服器 log 驗證有實際外部請求，並將此段更新為正式驗證步驟。

### 4) 語音優先級與內容（Voice Priority）

目前語音統一走 `VoiceAnnouncementCenter`，優先級由高到低如下：

1. `sos`（最高）  
   - 內容範例：`緊急求助，已通知照護者`
2. `connectionAlert`  
   - 內容範例：`裝置目前尚未連線，請檢查 Wi-Fi 連線狀態`
3. `navigation`  
   - 內容範例：`紅燈，請在原地停留` / `前方約 X 公尺有障礙，請停止` / `請向左修正路徑` / `請向右修正路徑`
4. `low`（保留）

規則：
- 高優先級可中斷低優先級語音。
- 低優先級不會覆蓋正在播報的高優先級語音。
- 當使用者靜音時，會立即停止當前播報。
- 連線提醒在未連線畫面進入時先播一次，之後每次播報結束再延遲 5 秒重播。

### 5) 視障者未連線限制

- 視障者裝置未連線時，只能停留在連線處理畫面（`DeviceInfoView`），不可進入 Walk / Recognition / LTC。
- 若已進入主流程後中途斷線，路由會自動退回連線處理畫面。
- 重新連線後，才可再次進入主流程。

### 6) 照護者偏好：語音範例

- 位置：照護者 → 個人資訊 → 設定偏好。
- 提供連線警示、導航指令與 SOS 語音範例按鈕。
- **僅在測試資料模式（`mock`）可觸發**；真實模式下按鈕會停用並顯示提示。

## 開發流程提醒（給 AI／新進開發者）

1. 開工前閱讀：`docs/architecture.md`、`docs/tech-state.md`、`docs/ui-spec.md`、`docs/device-connection.md`（與串流相關時）。  
2. **不可**在未更新 `docs/tech-state.md` / README 的情況下新增技術依賴。  
3. 每次可交付改動後：**append** `docs/state-schema.md`、更新 README 重點（若適用）、**git commit** 並依團隊流程 **push**。  
4. 若需求與架構／技術清單衝突：**先向使用者確認**再實作。  

---

GitHub: `Polalalabear/nkust-contest_final`
