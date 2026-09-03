# Lyra 音訊模組 (Audio Domain) 完整 API 規範與實現計劃書 (v1.1)

本計劃書針對 Lyra 核心系統中的 **Audio（聲學實體與音訊引擎）** 模組進行規劃。根據架構決策，本版次已將波形快取策略定案為 **「方案 B (檔案快取)」**，確認 `GetAudio` 支援 **多 Asset 陣列回傳**，並將硬體設備枚舉與 Gapless 播放移至後期路線圖，第一階段聚焦於 **波形提取、版本比對與播放控制增強**。

---

## 1. 系統架構定位與實體層次

Lyra 採用嚴格的 **三層分立（Three-Tier Entity Hierarchy）** 與 **內容定址（Content-Addressed）** 架構：

```
+-------------------------------------------------------------------------------+
|  Level 3: 邏輯曲目層 (Track)                                                  |
|  • track_id (UUID), title, artists, album, work_id, pcm_hash                  |
+---------------------------------------+---------------------------------------+
                                        | (關聯 pcm_hash)
                                        v
+-------------------------------------------------------------------------------+
|  Level 2: 聲學實體層 (Audio - 本計劃核心範疇)                                    |
|  • pcm_hash (SHA-256 of S32LE Raw PCM)                                        |
|  • bit_depth, sample_rate, channels, duration, loudness (LUFS), true_peak      |
|  • parent_hash (指向母盤/高品質版本), quality_score (音質評分)                   |
|  • Waveform Cache (基於檔案系統 .cache/waveforms/{pcm_hash}.bin)               |
+---------------------------------------+---------------------------------------+
                                        | (多對多關聯 Audio_Asset)
                                        v
+-------------------------------------------------------------------------------+
|  Level 1: 實體資產層 (Asset)                                                  |
|  • file_hash (SHA-256 of Container File), mime_type, file_size, CAS Path      |
+-------------------------------------------------------------------------------+
```

---

## 2. API 規範規格手冊

### 📌 命名空間與路由風格規則
- **實體層 CRUD (Repository Operations)**：使用 `PascalCase`（例如 `GetAudio`, `UpdateAudio`, `ListAudio`）。
- **即時控制與聲學引擎 (Realtime & Engine Operations)**：使用 `audio.<action>`（例如 `audio.play`, `audio.get_waveform`, `audio.compare_versions`）。

---

### 維度 1：聲學實體與多版本管理 (Acoustic Entity & Versioning)

#### 1.1 `GetAudio`（支援多 Asset 回傳）
* **說明**：依據 `pcm_hash` 查詢特定聲學實體。由於一個 Audio 可能對應多個不同封裝（如 FLAC、WAV 或帶有不同標籤的檔案），`assets` 欄位**必須以陣列（Array）形式回傳所有關聯的實體資產**。
* **請求參數**：
  | 參數名稱 | 類型 | 必填 | 說明 |
  | :--- | :--- | :---: | :--- |
  | `pcm_hash` | `string` | 是 | PCM S32LE SHA-256 雜湊值 (Hex) |
* **成功回應 (`code: 200`)**：
  ```json
  {
    "code": 200,
    "data": {
      "pcm_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
      "parent_hash": null,
      "quality_score": 96,
      "bit_depth": 24,
      "sample_rate": 96000,
      "channels": 2,
      "duration": 248.52,
      "integrated_loudness": -14.2,
      "true_peak": -0.8,
      "assets": [
        {
          "file_hash": "a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef0",
          "mime_type": "audio/flac",
          "asset_type": "audio",
          "file_size": 52428800,
          "created_at": "2026-08-24 12:00:00"
        },
        {
          "file_hash": "b2c3d4e5f6a17890123456789abcdef0123456789abcdef0123456789abcdef1",
          "mime_type": "audio/x-wav",
          "asset_type": "audio",
          "file_size": 143165560,
          "created_at": "2026-08-25 10:30:00"
        }
      ]
    }
  }
  ```

---

#### 1.2 `ListAudio`
* **說明**：分頁查詢聲學實體列表。
* **請求參數**：`offset` (int, 預設 0), `limit` (int, 預設 20), `search` (string, 選填)。
* **成功回應 (`code: 200`)**：包含 `items` 陣列與 `total` 筆數。

---

#### 1.3 `UpdateAudio`
* **說明**：增量更新 Audio 實體元數據（例如手動指定 `parent_hash`、調整 `quality_score`）。
* **請求參數**：`pcm_hash` (必填)，`parent_hash`, `quality_score`, `integrated_loudness`, `true_peak` (選填)。

---

#### 1.4 `audio.compare_versions` (多版本音質比對)
* **調用者與業務情境 (Who calls this?)**：
  1. **UI 層（歌曲詳情 / 版本切換抽屜）**：當使用者在前端查看一首 Track 時，若音樂庫內存在多種壓制或錄音版本（如 24bit/96kHz Hi-Res、16bit/44.1kHz CD 版、MP3 320k），UI 透過此 API 渲染「音質版本比對面板」，供使用者手動指定 Master 母帶版本。
  2. **匯入管線（Ingestion Service / 智慧去重）**：當匯入新歌曲時，後端呼叫此邏輯自動判定新檔案音質是否超越既有版本，自動推薦升級。
  3. **資料庫維護 CLI 工具**：執行音樂庫健康檢查時，批次揪出低品質重複音訊。
* **請求參數**：
  | 參數名稱 | 類型 | 必填 | 說明 |
  | :--- | :--- | :---: | :--- |
  | `track_id` | `string` | 條件必填 | 查詢此 Track 關聯的所有同曲錄音版本（擇一） |
  | `pcm_hashes`| `array<string>` | 條件必填 | 手動傳入要比對的 PCM 雜湊陣列（擇一） |
* **成功回應 (`code: 200`)**：
  ```json
  {
    "code": 200,
    "data": {
      "recommended_master": "pcm_hash_hi_res_flac",
      "versions": [
        {
          "pcm_hash": "pcm_hash_hi_res_flac",
          "format": "FLAC 24-bit / 96kHz",
          "quality_score": 98,
          "is_lossless": true,
          "file_size": 52428800,
          "is_master": true
        },
        {
          "pcm_hash": "pcm_hash_mp3_320",
          "format": "MP3 16-bit / 44.1kHz",
          "quality_score": 75,
          "is_lossless": false,
          "file_size": 8420000,
          "is_master": false
        }
      ]
    }
  }
  ```

---

### 維度 2：即時播放與傳輸控制 (Playback Engine)

#### 2.1 `audio.play` (多態起播)
* **請求參數**：
  - `track_id` / `pcm_hash` / `asset_id` / `file_path`（四選一必填）
  - `start_position` (float, 選填，預設 0.0)：起播秒數（支援精確斷點續播）
  - `fade_in_ms` (int, 選填，預設 0)：淡入毫秒數（平滑起播）
  - `apply_replaygain` (bool, 選填，預設 true)：是否套用響度補償增益
* **成功回應 (`code: 200`)**：最新引擎狀態 JSON。

#### 2.2 `audio.pause` / `audio.resume` / `audio.stop`
* **請求參數**：`{}`。
* **成功回應 (`code: 200`)**：傳回當前最新狀態 (`state: "PAUSED"` 或 `"STOPPED"`)。

#### 2.3 `audio.seek`
* **請求參數**：
  - `position` (float, 必填)：目標秒數
  - `relative` (bool, 選填，預設 false)：是否為相對偏移量（如 `+5.0` 或 `-5.0`）
* **成功回應 (`code: 200`)**：包含跳轉後實際時間戳的狀態 JSON。

#### 2.4 `audio.set_volume` & `audio.get_state`
* 標準音量控制與狀態輪詢。

---

### 維度 3：聲學特徵分析與視覺化 (Visualization & Analysis)

#### 3.1 `audio.get_waveform` vs `audio.get_spectrum` 核心差異

| 比較維度 | `audio.get_waveform` (波形數據) | `audio.get_spectrum` (即時頻譜) |
| :--- | :--- | :--- |
| **領域 (Domain)** | **時域 (Time Domain)** | **頻域 (Frequency Domain)** |
| **物理意義** | 隨時間變化的**振幅能量全貌**（Amplitude vs Time） | 當前播放瞬間的**各頻率能量分佈**（Frequency vs Energy） |
| **計算時機** | **靜態 / 離線預算**（播放前或匯入時即生成並快取） | **即時 / 動態計算**（播放進行中每 20~50ms 即時 FFT） |
| **UI 呈現元件** | **波形進度條（Waveform Scrubber）**<br>靜態展示整首歌哪裡高潮、哪裡安靜，點擊直接精確定位 | **動態跳動頻譜條 / 發燒 VU 表針**<br>隨著音樂節奏與重低音跳動的視覺動畫效果 |

---

#### 3.2 `audio.get_waveform` (波形數據提取 - 採納方案 B 檔案快取)
* **快取設計**：
  - 快取路徑：`.cache/waveforms/{pcm_hash}.bin`（二進位 Float32 Min/Max Array，容量僅約 2.4 KB/首）。
  - 命中流程：若快取檔案存在則直接 `fread` 回傳；若不存在則透過 `AudioDecoder` 快速遍歷計算後寫入快取檔案。
* **請求參數**：
  | 參數名稱 | 類型 | 必填 | 預設值 | 說明 |
  | :--- | :--- | :---: | :---: | :--- |
  | `pcm_hash` | `string` | 條件必填 | 聲學實體雜湊 |
  | `track_id` | `string` | 條件必填 | 曲目 ID（擇一必填） |
  | `points` | `int` | 否 | `300` | 點數（範圍 50~1000，適配 UI 像素寬度） |
* **成功回應 (`code: 200`)**：
  ```json
  {
    "code": 200,
    "data": {
      "pcm_hash": "e3b0c442...",
      "points": 300,
      "peaks": [
        [-0.05, 0.08],
        [-0.32, 0.41],
        [-0.78, 0.82],
        [-0.95, 0.98]
      ],
      "rms": [0.04, 0.25, 0.61, 0.85]
    }
  }
  ```

---

#### 3.3 `audio.get_spectrum` (即時頻譜 FFT / VU 表)
* **說明**：從正在播放的 `AudioEngine` PCM RingBuffer 提取當前 1024 影格做 FFT 分析。
* **請求參數**：`bands` (int, 預設 32)。
* **成功回應 (`code: 200`)**：包含左/右聲道 VU (dB) 與頻率柱振幅陣列。

---

## 3. 波形快取策略方案對比分析 (Waveform Caching Comparison)

針對波形峰值資料的儲存策略，三種方案的優缺點分析如下：

| 方案 | 運作機制 | 優點 (Pros) | 缺點 (Cons) | 適用場景 |
| :--- | :--- | :--- | :--- | :--- |
| **方案 A<br>(資料庫 BLOB)** | 在 SQLite 新增 `Audio_Waveform` 資料表，以 BLOB 儲存 300 點 peaks。 | 1. 單一 SQLite 檔案封裝，備份最方便。<br>2. 交易安全性強，隨 `Audio` 刪除透過 CASCADE 自動清理。 | 1. 導致 SQLite 體積顯著膨脹（萬首歌曲約增加 30~50MB）。<br>2. 頻繁讀取大型 BLOB 佔用 DB 連線與記憶體 Page Cache。 | 小型專案、重視單一檔案可攜性者。 |
| **方案 B<br>(檔案快取 ⭐️ 定案)** | 以 `.cache/waveforms/{pcm_hash}.bin` 存放二進位浮點數陣列。 | 1. **零 DB 負擔**：保持 SQLite 核心純粹與輕量。<br>2. **極致 I/O 速度**：可透過 mmap 或直接二進位讀取，不佔 DB 連線 Pool。<br>3. **容錯率極高**：即使手動刪除快取目錄，系統可無痛透明重建。 | 1. 需在檔案系統管理快取目錄。<br>2. 刪除音訊時若未實作清理可能殘留孤立檔案（但單檔僅 ~2KB，影響可忽略）。 | **專業 DAW / 音樂系統（如 Logic, Ableton, Spotify）之標準做法**。 |
| **方案 C<br>(隨選即時計算)** | 不儲存任何檔案，每次請求時透過 FFmpeg 掃描解碼音訊計算 peaks。 | 1. 零磁碟空間佔用。<br>2. 架構最簡單，無快取失效與同步問題。 | 1. 運算開銷大：一首 5 分鐘無損需 50~200ms CPU，列表快速滑動時會嚴重卡頓。<br>2. 無法支援大型播放清單的波形預覽。 | 僅臨時播放單一檔案之輕量播放器。 |

> 🏆 **Agent 觀點**：
> **方案 B 是最具工程潔癖與擴展性的最佳選擇**。
> 波形本質上屬於「可隨時從原始音訊無損重建的衍生性視覺快取」，不應污染儲存真理資料（Truth Data）的 SQLite 資料庫。

---

## 4. 功能實作清單與進度 (Implementation Checklist)

- [x] **Unit 1: `GetAudio` 支援多 Asset 陣列聯表回傳 (`assets: [...]`)**
  - 資料模型 `Audio` 擴充 `std::vector<Asset> assets;`
  - `SqliteAudioRepository::get` 聯表查詢 `Audio_Asset` 與 `Asset`
  - Python & C++ 整合測試完成 (Commit `f9ef513`)
- [x] **Unit 2: `audio.seek` 相對跳轉與 `audio.play` 起播位置控制**
  - `AudioEngine::seek(position, relative)` 支援相對偏移與邊界防護
  - `AudioEngine::play` / `handleAudioPlay` 支援 `start_position` (浮點秒數)
  - `Router` 路由參數解析與邊界防護
  - Python 播放整合測試完成 (Commit `a50f2a2`)
- [x] **Unit 3: `audio.compare_versions` 多版本音質比對與最佳品質推薦 API**
  - `AudioHelper::evaluate_quality` 解析度分 (0~50) + 無損/碼率分 (0~45) + 聲道分 (0~5)
  - 單層星狀拓撲（Single-Level Star Topology）版本關係檢索
  - 懸空指標（Dangling `parent_hash`）自動自癒機制（Auto-Healing）
  - 多版本排序與 `recommended_master` 自動決策
  - C++ 單元測試與 Python 整合測試完成（199 測試通過）
- [x] **Unit 4: `audio.get_waveform` 時域波形提取與檔案快取**
  - 方案 B 檔案快取：`.cache/waveforms/{pcm_hash}.bin` (Float32 Min/Max/RMS peaks)
  - 支援 `pcm_hash` 或 `track_id` 查詢、自訂 `points` 點數 (50~1000)
  - 快取命中時直接讀取，未命中時透過 `AudioDecoder` 遍歷計算並寫入快取
  - Python & C++ 單元/整合測試 (206 測試通過)
- [ ] **Unit 5: `audio.get_spectrum` 即時頻譜 FFT / VU 表分析 (後續規劃)**
  - 從 `AudioEngine` PCM RingBuffer 提取當前幀進行 FFT 與左右聲道 VU 分析
- [x] **Unit 6: 音訊輸出設備枚舉與無縫播放 (Gapless Playback)**
  - `audio.list_devices`, `audio.set_output_device` 支援 miniaudio 實體輸出設備枚舉與切換
  - 雙軌預載 (`audio.preload_next`, `audio.queue_next`) 與 EOF/Buffer Drain 無縫雙軌切換
  - Python & C++ 單元/整合測試完成 (213 測試通過)
