# 安全決策策略：最近優先（Nearest-First）

> 建立日期：2026-03-27  
> 適用範圍：視障模式即時導航（Walk / Recognition）

---

## 1. 背景與問題

目前系統採用多模型融合（YOLO + MiDaS + PIDNet）後輸出導航指令。  
實測觀察到以下風險：

1. 距離估計偏差（例如實際約 1m，系統可能回報 6m）
2. 目前主目標選取偏向「偵測信心最高」，不一定是「最近物體」

在安全導向系統中，決策優先序應為：

**先找最近威脅，再判斷風險等級，再決定導航動作。**

---

## 2. 目標原則（Safety First）

1. **Nearest First**：先處理最近物體，而非最高 confidence 物體
2. **Conservative by Default**：不確定時保守（傾向減速/停止）
3. **Temporal Stability**：以連續多幀穩定結果，避免單幀抖動誤導
4. **Explainable Rules**：規則可讀、可測、可調參

---

## 3. 建議決策流程

## Step 0. 候選物過濾（Candidate Filtering）

- 只保留前方主要通行區域中的物件（例如畫面中央 60%~70%）
- 移除過小 bbox 或極低 confidence 物件（噪聲）
- 保留 `N` 個候選（例如前 5 個）供後續風險評估

## Step 1. 最近目標優先（Nearest Selection）

- 對每個候選 bbox 取 ROI 深度估計
- 以「距離最短」作為 primary 目標
- 若深度失敗，才退回 bbox 尺寸 fallback

> 主目標選取順序：
> 1) 有效深度且最近  
> 2) 無深度時以 bbox 面積近似最近  
> 3) 仍無法判定時標記 unknown，採保守策略

## Step 2. 風險評分（Risk Scoring）

對每個候選計算風險分數，建議由以下項目加權：

- 距離風險（越近越高）
- 類別風險（車、機車、行人、交通號誌、固定障礙）
- 可通行風險（PIDNet 的 walkable ratio）
- 動態風險（若可估算接近速度）

可用簡化模型：

`risk = w_d * distanceRisk + w_c * classRisk + w_w * walkableRisk + w_v * velocityRisk`

若無速度資訊，可先令 `w_v = 0`。

## Step 3. 動作映射（Action Mapping）

先看最近目標，再看風險分級：

- **Critical**（高風險）：`STOP`
- **Warning**（中風險）：`MOVE_LEFT` / `MOVE_RIGHT`（依可通行方向）
- **Low**（低風險）：`SAFE`

若分割結果顯示前方不可通行（walkable ratio 過低），即使最近距離中等，也可直接升級為 `STOP`。

## Step 4. 時序穩定（Temporal Smoothing）

- 距離與風險採 3~5 幀平滑（EMA 或中位數）
- 異常跳點（例如單幀 1m -> 8m -> 1m）應抑制
- 停止指令可快速觸發；解除停止可稍延後（hysteresis）

---

## 4. 距離偏差處理（MiDaS Calibration）

MiDaS 輸出屬相對深度，非直接公尺值。  
現況若直接線性映射到固定公尺範圍，容易造成絕對距離誤差。

建議做法：

1. 蒐集校正樣本（例如 1m / 2m / 3m / 5m）
2. 每個距離拍多張，取 ROI 深度統計值
3. 擬合轉換函式（可先用分段線性）
4. 以場域/鏡頭設定儲存校正參數
5. 定期驗證 MAE（Mean Absolute Error）

短期可行方案：

- 保留「相對遠近」判定，弱化精準公尺顯示
- UI 提示可先用區間語意（近距離/中距離/遠距離）

---

## 5. 安全閾值建議（初版）

以下為可起步的保守閾值，需依場域再調整：

- `STOP <= 1.5m`
- `SLOW/AVOID <= 3.0m`
- `CAUTION <= 5.0m`
- `SAFE > 5.0m`

補充：

- 若 `walkableRatio < threshold`，可直接升級一級風險
- 若分類為高風險類別（如車、機車），可提高風險權重

---

## 6. 最小改動落地方案（不改架構）

在既有 MVVM + Service + Engine 下，建議以最小範圍調整：

1. 將主目標選取從 `max confidence` 改為 `min estimated distance`
2. 在融合層加入 per-candidate 深度比較邏輯
3. 保留現有 fallback（bbox area）作為深度失敗時備援
4. 在 ViewModel 端沿用既有語音與 UI 更新流程
5. 增加 debug 輸出：最近候選、距離、風險、最終動作

---

## 7. 驗證與測試建議

## 測試場景

- 單一障礙、固定距離（1m/2m/3m）
- 多目標同時存在（近小物 vs 遠大物）
- 低光、背光、反光地面
- 可行走區突然縮小（路口、障礙密集）

## 指標

- 最近目標命中率（是否真的選到最近物）
- 停止觸發漏報率（False Negative）
- 停止誤報率（False Positive）
- 距離誤差（MAE）
- 指令抖動頻率（每分鐘指令切換次數）

---

## 8. 結論

對安全型導航系統而言，**「最近優先」是比「信心優先」更安全的基準策略**。  
本文件建議在不破壞現有架構前提下，將決策核心調整為：

**Nearest First + Risk Scoring + Temporal Smoothing + Calibration**。

這可明顯降低「近距離風險被忽略」與「距離錯估導致錯誤導航」的風險。

---

## 9. 多模型長寬比不一致處理（實作決議）

### 問題

三模型輸入尺寸不同（例如 YOLO 640x640、MiDaS 256x256、PIDNet 2048x1024），若直接縮放會造成幾何變形，進而導致：

- 偵測框位置偏移
- ROI 深度採樣錯位
- 分割結果與偵測結果在融合時座標不一致

### 決議策略

採用 **統一座標系 + 各模型保比例 letterbox**：

1. 以原始影像 normalized 座標（0...1）作為唯一 canonical 座標系
2. 各模型輸入一律用 aspect-fit letterbox（保比例 + padding），禁止直接拉伸
3. 每次前處理保存 transform metadata（scale、padding、valid rect）
4. 模型輸出在融合前先反投影回 canonical 座標
5. MiDaS ROI 與 PIDNet histogram 只在 valid 區域內計算，排除 padding 干擾

### 實作階段（本次先做 Phase 1）

- Phase 1（已完成）：完成三模型 letterbox 與座標映射基礎
- Phase 2（已完成）：主目標邏輯改為中列九宮格優先 + 最近優先 + 風險分數 tie-break
- Phase 3：加入場域距離校正與風險分級參數化

### Phase 2 實作備註（已落地）

1. 候選物先過濾中列（`x in [1/3, 2/3)`），中列無物件才 fallback 全畫面
2. 使用每個偵測框對應的 MiDaS ROI 深度估計距離（失敗時 fallback bbox 面積距離）
3. 排序規則：先比最近距離，再比風險分數，再比 confidence
4. 風險分數包含：距離風險 + 類別風險 + 可通行性風險

### 安全補強（已落地）

1. **防撞頭機制（Head-Collision Guard）**
   - 定義前上方危險區：中列 + 上方區域（normalized `x in [1/3, 2/3)`, `y <= 0.42`）
   - 若該區域偵測到近距離障礙（<= 2m）則直接 `STOP`
   - 在上方中列偵測到物件但缺乏可靠深度時，採保守策略（`STOP`）

2. **左右修正改為方位導向**
   - 障礙偏左 -> 建議向右修正
   - 障礙偏右 -> 建議向左修正
   - 障礙位於中列 -> 預設先向左（避免單側偏移累積）

3. **YOLO 漏檢補救**
   - 無主物件時不再直接 `SAFE`
   - 若可通行比低於 `walkableStopThreshold`（0.25）或深度顯示近距離，改判 `STOP`

4. **Anti-loop（連續同向修正防護）**
   - 若連續同方向修正達閾值（8 幀）且距離未改善，強制輸出 `STOP`
   - 目的：避免現場測試出現持續向右（或向左）貼牆的行為

---

## 10. 目前模型判斷流程（程式實作版）

以下是目前 live 模式的實際資料流（由程式碼落地）：

1. `MJPEGStreamService` 接收 ESP32 影像，解析 JPEG frame 後回傳 `UIImage`
2. `WalkModeViewModel` / `RecognitionModeViewModel` 接收 frame
3. `LiveAIService.analyzeLocal` 啟動本地推論管線
4. 管線順序：`YOLO -> MiDaS -> PIDNet -> FusionAggregator`
5. `FusionAggregator` 輸出：
   - `primaryObject`
   - `distanceMeters`
   - `isWalkable`
   - `command`
   - `summary`
6. ViewModel 依照警示距離門檻更新 UI；Walk 模式再經 `DecisionEngine` 觸發語音/震動回饋

### 10.1 目前主目標選取規則

1. 對所有候選計算距離與風險分數
2. 先取中列（`x in [1/3, 2/3)`）候選；若中列為空才退回全畫面
3. 排序優先序：
   - 最近距離優先
   - 風險分數較高優先
   - confidence 較高優先

### 10.2 目前方向輸出規則

- 前上方危險區（防撞頭）成立 -> `STOP`
- 無偵測但不可通行比過低 / 深度顯示近距離 -> `STOP`（漏檢補救）
- 一般避障時採方位導向：
  - 障礙偏左 -> `MOVE_RIGHT`
  - 障礙偏右 -> `MOVE_LEFT`
  - 障礙在中列 -> 預設 `MOVE_LEFT`
- 若連續同向修正且距離未改善（anti-loop）-> 強制 `STOP`

### 10.3 目前已知限制

1. MiDaS 距離仍屬相對深度映射，尚未完成場域校正
2. 中列預設方向目前為固定策略（中列預設先左），尚未依左右可通行差做動態選邊
3. YOLO 類別覆蓋仍受模型 label 限制，未知障礙主要靠分割/深度保守補救

---

## 11. 詳細判斷流程與技術細節（實作對照）

本章對應目前 `AIService.swift` 的實作，描述每一幀從輸入到輸出的決策細節。

### 11.1 Frame-Level Pipeline（每幀流程）

1. **Stream In**
   - `MJPEGStreamService` 從 URLSession 累積 bytes
   - 優先以 multipart boundary 解析；無 boundary 時 fallback JPEG marker（FF D8 ~ FF D9）
2. **Preprocess**
   - YOLO：Vision `scaleFit`
   - MiDaS/PIDNet：letterbox（保比例 + padding）
   - 產生 `LetterboxTransform(scale, padX, padY, validRect)`
3. **Model Inference**
   - YOLO -> `detections`
   - MiDaS -> `roiDepth`, `normalizedDistance`, `perObjectNormalizedDistances`
   - PIDNet -> `classHistogram`, `walkableRatio`, `dominantClass`
4. **Fusion**
   - 候選排序（中列優先 + 最近優先 + 風險 tie-break）
   - 防撞頭判定
   - 漏檢補救判定
   - anti-loop 修正
5. **Output**
   - `FusionDecision(primaryObject, distanceMeters, isWalkable, command, summary)`
   - ViewModel 根據警示距離與語音設定渲染卡片/播報

### 11.2 座標系與幾何映射

- Canonical 座標：影像 normalized（`x,y in [0,1]`）
- YOLO 框先在模型輸出座標，再經 `modelRectToImageRect()` 回到 canonical
- MiDaS ROI 採樣先做 `imageRectToModelRect()`，避免 ROI 取樣錯位
- PIDNet histogram 僅統計 `validRectInModelNormalized`，排除 letterbox padding 對語意比例污染

### 11.3 距離估計與映射

- MiDaS 原始值為相對 inverse-depth，先做 frame 內標準化：
  - `normalizedDepth = (depth - minDepth) / (maxDepth - minDepth)`
  - `normalizedDistance = clamp(1 - normalizedDepth, 0, 1)`
- 目前公尺映射（暫定）：
  - `meters = 0.8 + normalizedDistance * 11.2`
  - 最終 `Int(round(meters))`，並限制在 `[1, 12]`
- 若 per-object depth 失效：
  - fallback 用 bbox area 估距（1/3/6/10m 分段）

### 11.4 候選選取與排序（Phase 2）

候選池建立：

1. 對每個 detection 建立 `Candidate(index, object, distanceMeters, riskScore)`
2. 中列 gate：`bbox.midX in [1/3, 2/3)` 優先
3. 若中列無候選，退回全畫面候選

排序 comparator：

1. `distanceMeters` 小者優先（最近優先）
2. `riskScore` 大者優先
3. `confidence` 大者優先

### 11.5 風險分數（目前版本）

目前融合層使用簡化線性權重：

- `distanceRisk`: 越近越高
- `classRisk`: 高風險類別（車、人、機車等）權重較高
- `walkableRisk`: `walkableRatio` 低於 0.45 時增加

公式：

`risk = 0.6 * distanceRisk + 0.3 * classRisk + 0.1 * walkableRisk`

### 11.6 指令決策優先序（Decision Ladder）

每幀指令輸出按以下優先序判定（前者命中即返回）：

1. **Head-Collision Guard**
   - 危險區：中列 + 上方（`x in [1/3, 2/3)`, `y <= 0.42`）
   - 近距離（<= 2m）或缺乏可靠深度 -> `STOP`
2. **No-Detection Fallback**
   - `primary == nil` 且 `walkableRatio < 0.25` -> `STOP`
   - 或 `depth.normalizedDistance` 映射近距離（<= 2m）-> `STOP`
3. **General Safety**
   - `!isWalkable` -> `STOP`
   - `distance <= 2m` -> `STOP`
4. **Lateral Avoidance**
   - 障礙偏左 -> `MOVE_RIGHT`
   - 障礙偏右 -> `MOVE_LEFT`
   - 障礙置中 -> `MOVE_LEFT`（暫定策略）
5. **Anti-loop Override**
   - 同向連續修正 >= 8 幀且距離未改善 -> 強制 `STOP`
6. **Default**
   - 其餘 -> `SAFE`

### 11.7 失敗降級策略（Graceful Degradation）

- YOLO 失敗：回空 detections，仍允許 PIDNet/MiDaS 驅動保守停下
- MiDaS 失敗：距離改用 bbox fallback，不中斷整體流程
- PIDNet 失敗：`walkableRatio` 使用預設值（0.5），仍可由 YOLO+距離運作
- 任一模型錯誤：記錄 incident，不 crash，維持逐幀運行

### 11.8 目前建議觀測指標（測試/調參）

1. `moveRight` / `moveLeft` 連續幀長度分佈（觀察 anti-loop 是否生效）
2. Head zone 命中率與誤停率（防撞頭品質）
3. YOLO 漏檢時 `STOP` 觸發率（漏檢補救有效性）
4. 近距離（<=2m）場景漏報率（核心安全指標）

