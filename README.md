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

> `AppState.effectiveDeviceConnected` 已同時提供給照護者與視障者 UI（如 DeviceInfo / Walk / Recognition / LTC 狀態列）使用。

### 與 ESP32 相機串流（必讀）

`/docs/device-connection.md`：**開發階段仍使用 MockStreamService**，不可直接連 `http://192.168.4.1/stream`，直到專案進入下一階段。Firestore 與 MJPEG 為不同資料路徑。

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

> 最後更新：2026-03-20 · App 版本見 `AppState.appVersion`（目前 **v1.4.0**）

- [x] Firebase 初始化（`AppDelegate` + `GoogleService-Info.plist`）  
- [x] SwiftData 容器 + 設定／健康日模型  
- [x] 照護者：裝置狀態列、測試/真實資料切換、Firestore 監聽  
- [x] DecisionEngine / LiveFeedbackManager / WalkMode 串接  
- [x] CoreHaptics 自訂節奏（LiveFeedbackManager：強停 / 短短 / 短長）  
- [x] MJPEG 真實串流服務（`MJPEGStreamService`，URLSession + 手動 JPEG 解析；預設仍遵守階段規則使用 Mock）  
- [x] `live` 模式主線打通（Stream frame → CoreML/Vision → DecisionEngine → Feedback）  
- [x] MJPEG parser 強化：支援 `multipart/x-mixed-replace` boundary 解析，並保留 JPEG marker fallback  
- [x] SwiftData/CoreData 初始化安全：啟動前先確保 `Application Support` 目錄存在，避免 default.store 建檔失敗  
- [ ] CSV 實際匯出  
- [ ] Firebase Auth 與欄位級安全規則落地  

## 實際模式（Live）最新確認

- `mock` 模式維持原行為（測試資料 + 可切換模擬連線）。
- `live` 模式目前會嘗試：
  1) 連 ESP32 MJPEG（`http://192.168.4.1/stream`）  
  2) 每幀送入 `LiveAIService`（CoreML + Vision）  
  3) 生成導航上下文後交給 `DefaultDecisionEngine`  
  4) 經 `LiveFeedbackManager` 輸出語音／震動  
- Walk / Recognition 背景可顯示最新 frame（無畫面時回退 placeholder）。
- 串流資料解析在背景 queue 進行，`onFrame` 回主執行緒更新 UI（避免主執行緒阻塞）。

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
3. 進入視障者 `Walk` 或 `Recognition`，確認狀態有進入串流流程（`連線中` → `串流已連線` / `等待影像中`）。
4. 若切回「測試資料」模式（`mock`），串流應立即停止（只走 Mock）。

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
