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
- [ ] CSV 實際匯出  
- [ ] Firebase Auth 與欄位級安全規則落地  

## 開發流程提醒（給 AI／新進開發者）

1. 開工前閱讀：`docs/architecture.md`、`docs/tech-state.md`、`docs/ui-spec.md`、`docs/device-connection.md`（與串流相關時）。  
2. **不可**在未更新 `docs/tech-state.md` / README 的情況下新增技術依賴。  
3. 每次可交付改動後：**append** `docs/state-schema.md`、更新 README 重點（若適用）、**git commit** 並依團隊流程 **push**。  
4. 若需求與架構／技術清單衝突：**先向使用者確認**再實作。  

---

GitHub: `Polalalabear/nkust-contest_final`
