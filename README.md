# 視障輔助導航系統 (Vision-Assisted Navigation System)

即時視覺輔助導航決策系統，將攝影機畫面轉換為行動指令，協助視障者安全行走。

## 功能模組

| 模組 | 說明 | 狀態 |
|---|---|---|
| 行走模式 (Walk Mode) | 即時障礙偵測 + 方向指引 + 號誌辨識 | UI 完成，引擎 Stub |
| 辨識模式 (Recognition Mode) | 物品辨識 + AI 描述 | UI 完成，AI Stub |
| 長照模式 (LTC Mode) | 位置分享 + 緊急通話 | UI 完成，通話 Stub |
| 照護者儀表板 (Dashboard) | 健康數據 + 即時定位地圖 | UI 完成，資料 Stub |

## 架構

```
MVVM + 嚴格分層
View → ViewModel → Service → Engine
```

- **View**: SwiftUI，僅負責 UI 呈現
- **ViewModel**: @Observable 狀態管理
- **Service**: 外部互動抽象（全部為 Stub）
- **Engine**: 純邏輯（DecisionEngine / FeedbackManager）

## 技術棧

- SwiftUI (iOS 26)
- @Observable (Swift Macro)
- Swift Charts
- SF Symbols
- MapKit
- MVVM 架構

## 專案結構

```
nkust-contest/nkust-contest/
├── App/            # AppEntry + AppRouter
├── State/          # AppState (@Observable)
├── Shared/
│   ├── Models/     # AppMode, DecisionModels
│   └── Components/ # VoiceToggle, ModeHeader, OverlayCard, SwipeHint, HealthChart
├── Modules/
│   ├── ChooseUser/ # 身份選擇
│   ├── DeviceInfo/ # 裝置資訊
│   ├── MainTab/    # 頁面滑動容器
│   ├── WalkMode/   # 行走模式 (View/ViewModel/Service/Engine)
│   ├── RecognitionMode/ # 辨識模式
│   ├── LTCMode/    # 長照模式
│   └── Dashboard/  # 照護者儀表板 + 地圖
├── Services/       # AI / Stream / Feedback (Stub)
└── Core/Engine/    # DecisionEngine / FeedbackManager
```

## 開發狀態

> 最後更新：2026-03-19

- [x] MVVM 骨架建立
- [x] 全畫面 UI 實作（依照設計稿）
- [x] @Observable 遷移
- [x] SF Symbols 全面採用
- [x] 頁面循環滑動
- [x] 照護者個人資訊頁面 + 登出
- [x] 健康數據詳細頁面（步數/距離/站立分鐘 + 期間篩選 + 排序）
- [x] 月曆式全部健康資料頁面（日期點擊詳細 + 期間平均）
- [x] 交接文件 (handoff.md)
- [x] 一鍵取得即時位置 + 最近醫院按鈕
- [x] 照護者個人資料可編輯（姓名/關係/緊急電話）
- [x] 健康圖表（長條圖/折線圖/圓餅圖切換）
- [x] 版本號更新至 v1.1.0
- [x] 圖表顯示開關 toggle + 圖表樣式移至設定偏好
- [x] 日期格式統一為 M/d (e.g. 3/15)
- [x] 設定偏好（日間/夜間模式、圖表樣式選擇含預覽）
- [x] 匯出 CSV 按鈕（stub，可選擇時間範圍）
- [x] 版本號更新至 v1.2.0
- [ ] DecisionEngine 實作
- [ ] FeedbackManager 實作（CoreHaptics + AVSpeechSynthesizer）
- [ ] AI Service 接入（CoreML / Gemini）
- [ ] MJPEG Stream 接入
- [ ] 真實定位整合
