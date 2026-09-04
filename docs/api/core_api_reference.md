<!--
SPDX-FileCopyrightText: 2026 Tzu-Ting Lin

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Lyra Core API 參考手冊 (API Reference)

版本：`v1.0.0`  
適用核心：`Lyra Core Engine`  
最後更新時間：2026-09-04

---

## 目錄 (Table of Contents)

- [1. 協議總覽 (Protocol Overview)](#1-協議總覽-protocol-overview)
  - [1.1 C-ABI 進入點與記憶體契約](#11-c-abi-進入點與記憶體契約)
  - [1.2 通訊信封格式 (Envelope Schema)](#12-通訊信封格式-envelope-schema)
  - [1.3 全域錯誤代碼表 (Error Types)](#13-全域錯誤代碼表-error-types)
  - [1.4 通用分頁參數 (Pagination)](#14-通用分頁參數-pagination)
- [2. 指令索引 (Command Index)](#2-指令索引-command-index)
- [3. 領域指令規格 (Domain Commands)](#3-領域指令規格-domain-commands)
  - [3.1 Track 曲目領域](#31-track-曲目領域)
  - [3.2 Artist & Album 演出者與專輯領域](#32-artist--album-演出者與專輯領域)
  - [3.3 Work 音樂作品領域](#33-work-音樂作品領域)
  - [3.4 Playlist & Playlist-Track 播放清單領域](#34-playlist--playlist-track-播放清單領域)
  - [3.5 Asset & CAS 檔案資產領域](#35-asset--cas-檔案資產領域)
  - [3.6 Audio 聲學實體領域](#36-audio-聲學實體領域)
  - [3.7 Track-Artist 演出關聯領域](#37-track-artist-演出關聯領域)
  - [3.8 Cover Art 封面圖像領域](#38-cover-art-封面圖像領域)
- [4. 音訊播放引擎指令 (Audio Engine Controls)](#4-音訊播放引擎指令-audio-engine-controls)
- [5. 事件推送規格 (Event Callbacks)](#5-事件推送規格-event-callbacks)

---

## 1. 協議總覽 (Protocol Overview)

### 1.1 C-ABI 進入點與記憶體契約

Lyra 核心以 C 語言符號界面（C-ABI）對外暴露進入點，標頭檔定義於 [core/include/lyra_c_api.h](file:///home/ryan/Documents/Lyra/core/include/lyra_c_api.h)。

```c
#ifdef __cplusplus
extern "C" {
#endif

int lyra_init(const char *storage_root);
char *lyra_dispatch(const char *json_request);
void lyra_free_string(char *str);

typedef void (*LyraEventCallback)(const char *json_event, void *user_data);
void lyra_register_event_callback(LyraEventCallback callback, void *user_data);

#ifdef __cplusplus
}
#endif
```

#### 介面語意與記憶體管理契約

| 函式 | 輸入參數 | 回傳值 | 記憶體責任說明 |
| :--- | :--- | :--- | :--- |
| `lyra_init` | `storage_root`: 儲存庫根目錄路徑 | `0` (成功) / `-1` (失敗) | 呼叫端持有輸入字串指標，函式返回後核心不保留引用。 |
| `lyra_dispatch` | `json_request`: JSON 格式請求字串 | UTF-8 JSON 回應字串指標 | 核心分配回傳字串記憶體。**呼叫端讀取完成後，必須調用 `lyra_free_string` 釋放該指標**。 |
| `lyra_free_string` | `str`: 欲釋放的字串指標 | `void` | 專責釋放 `lyra_dispatch` 產生的記憶體。傳入 `NULL` 為安全無操作。 |
| `lyra_register_event_callback` | `callback`: 事件回調函式<br>`user_data`: 自訂使用者指標 | `void` | 回調函式傳入的 `json_event` 指標僅在當次呼叫訊框內有效；若需非同步處理，呼叫端必須自行複製字串。 |

---

### 1.2 通訊信封格式 (Envelope Schema)

所有透過 `lyra_dispatch` 傳輸的資料均封裝於 JSON 信封中。

#### 請求信封 (Request Envelope)

```json
{
  "command": "GetTrack",
  "params": {
    "id": "e8d4a1b0-4f92-4d2a-9e1b-3c4d5e6f7a8b"
  }
}
```

- `command` (`string`, 必填)：目標執行的指令名稱。
- `params` (`object`, 選填)：指令所需的參數物件。若無參數可帶 `{}` 或省略。

#### 成功回應信封 (Success Envelope)

```json
{
  "code": 200,
  "data": {
    "id": "e8d4a1b0-4f92-4d2a-9e1b-3c4d5e6f7a8b",
    "title": "Winter Wind"
  },
  "message": "Get Track success."
}
```

- `code` (`integer`)：HTTP 狀態碼語意。查詢與更新為 `200`，建立資源為 `201`。
- `data` (`object` | `array`)：指令回傳的資料主體。
- `message` (`string`, 選填)：操作結果簡要說明。

#### 錯誤回應信封 (Error Envelope)

```json
{
  "code": 400,
  "error": {
    "type": "MissingParameter",
    "message": "Missing required parameter 'pcm_hash'"
  }
}
```

- `code` (`integer`)：錯誤對應的 HTTP 狀態碼（`400`, `404`, `409`, `500`）。
- `error.type` (`string`)：錯誤類型列舉代碼。
- `error.message` (`string`)：錯誤成因說明。

---

### 1.3 全域錯誤代碼表 (Error Types)

| 狀態碼 | ErrorType | 說明 |
| :---: | :--- | :--- |
| **400** | `InvalidValue` | 參數格式錯誤、型別不匹配或欄位數值無效。 |
| **400** | `MissingParameter` | 缺少執行該指令所必需的參數。 |
| **400** | `InvalidCommandFormat` | 請求信封格式錯誤，缺少 `command` 欄位或型別不為字串。 |
| **400** | `OutOfRange` | 數值超出限制區間（如分頁 limit、起訖年份順序錯誤）。 |
| **404** | `TrackNotFound` | 找不到指定 `id` 的曲目。 |
| **404** | `ArtistNotFound` | 找不到指定 `id` 的演出者。 |
| **404** | `AlbumNotFound` | 找不到指定 `id` 的專輯。 |
| **404** | `WorkNotFound` | 找不到指定 `id` 的作品。 |
| **404** | `PlaylistNotFound` | 找不到指定 `id` 的播放清單。 |
| **404** | `AssetNotFound` | 找不到指定 `file_hash` 的檔案資產。 |
| **404** | `AudioNotFound` | 找不到指定 `pcm_hash` 的聲學實體。 |
| **404** | `RelationNotFound` | 找不到指定的實體關聯（如 Track-Artist 或 Playlist-Track 關聯）。 |
| **404** | `UnknownCommand` | 核心路由器未註冊該指令名稱。 |
| **404** | `NotFound` | 通用資源未找到（如實體存在但無任何封面）。 |
| **409** | `Conflict` | 違反唯一性約束（如重複的 ISWC 代碼）。 |
| **500** | `DatabaseError` | 資料庫執行異常或系統錯誤。 |

---

### 1.4 通用分頁參數 (Pagination)

所有列表查詢指令（以 `List` 為前綴）均支援統一的分頁與過濾參數：

#### 請求參數

| 欄位 | 型別 | 必填 | 預設值 | 規範與說明 |
| :--- | :--- | :---: | :---: | :--- |
| `offset` | `integer` | 否 | `0` | 起始偏移量，需滿足 `offset >= 0`。 |
| `limit` | `integer` | 否 | `20` | 單頁筆數限制，需滿足 `1 <= limit <= 100`。 |
| `search` | `string` | 否 | `null` | 關鍵字模糊過濾字串。核心將自動修剪前後空白。 |

#### 回應結構 (`data` 物件)

```json
{
  "code": 200,
  "data": {
    "items": [
      { "id": "uuid-1" },
      { "id": "uuid-2" }
    ],
    "total": 42
  }
}
```

---

## 2. 指令索引 (Command Index)

Lyra 核心路由器支援全量 60 個指令，分類如下：

| # | 領域分類 | 指令名稱 (Command) | 說明 |
| :---: | :--- | :--- | :--- |
| 1 | Track | `CreateTrack` | 建立曲目實體並綁定 PCM Hash |
| 2 | Track | `UpdateTrack` | 更新曲目中繼資料 |
| 3 | Track | `GetTrack` | 依 UUID 取得曲目詳情 |
| 4 | Track | `ListTracks` | 分頁查詢曲目列表 |
| 5 | Track | `GetTracksByTitle` | 依標題搜尋曲目 |
| 6 | Track | `ImportTrack` | 執行音訊檔案匯入管線 |
| 7 | Artist | `CreateArtist` | 建立演出者實體 |
| 8 | Artist | `UpdateArtist` | 更新演出者中繼資料 |
| 9 | Artist | `GetArtist` | 依 UUID 取得演出者詳情 |
| 10 | Artist | `ListArtists` | 分頁查詢演出者列表 |
| 11 | Artist | `GetArtistsByName` | 依名稱搜尋演出者 |
| 12 | Album | `CreateAlbum` | 建立專輯實體 |
| 13 | Album | `UpdateAlbum` | 更新專輯發行資料 |
| 14 | Album | `GetAlbum` | 依 UUID 取得專輯詳情 |
| 15 | Album | `ListAlbums` | 分頁查詢專輯列表 |
| 16 | Album | `GetAlbumsByTitle` | 依標題搜尋專輯 |
| 17 | Work | `CreateWork` | 建立音樂作品實體 |
| 18 | Work | `UpdateWork` | 更新音樂作品中繼資料 |
| 19 | Work | `GetWork` | 依 UUID 取得作品詳情 |
| 20 | Work | `ListWorks` | 分頁查詢音樂作品列表 |
| 21 | Work | `GetWorksByTitle` | 依標題搜尋音樂作品 |
| 22 | Playlist | `CreatePlaylist` | 建立播放清單實體 |
| 23 | Playlist | `UpdatePlaylist` | 更新播放清單名稱與描述 |
| 24 | Playlist | `GetPlaylist` | 依 UUID 取得播放清單詳情 |
| 25 | Playlist | `ListPlaylists` | 分頁查詢播放清單列表 |
| 26 | Playlist | `GetPlaylistsByTitle` | 依標題搜尋播放清單 |
| 27 | Playlist-Track | `AddPlaylistTrack` | 新增曲目至播放清單 |
| 28 | Playlist-Track | `RemovePlaylistTrack` | 從播放清單中移除曲目 |
| 29 | Playlist-Track | `GetPlaylistTracks` | 取得播放清單內曲目 UUID 清單 |
| 30 | Asset | `CreateAsset` | 註冊實體檔案資產 |
| 31 | Asset | `UpdateAsset` | 更新檔案資產中繼資料 |
| 32 | Asset | `GetAsset` | 依檔案 SHA-256 取得資產詳情 |
| 33 | Asset | `ListAssets` | 分頁查詢實體資產列表 |
| 34 | Asset | `IngestAsset` | 匯入本機檔案至 CAS 儲存區 |
| 35 | Asset | `GetResourcePath` | 解析音訊資產本機絕對檔案路徑 |
| 36 | Audio | `CreateAudio` | 登記聲學特徵實體 |
| 37 | Audio | `UpdateAudio` | 更新聲學實體中繼資料 |
| 38 | Audio | `GetAudio` | 取得聲學實體詳情（含關聯檔案陣列） |
| 39 | Audio | `ListAudio` | 分頁查詢聲學實體列表 |
| 40 | Track-Artist | `AddTrackArtist` | 建立曲目與演出者之多對多關聯 |
| 41 | Track-Artist | `UpdateTrackArtist` | 更新演出者在曲目中的角色與順位 |
| 42 | Track-Artist | `RemoveTrackArtist` | 解除曲目與演出者的關聯 |
| 43 | Cover Art | `GetAlbumCover` | 解析專輯封面路徑 |
| 44 | Cover Art | `GetTrackCover` | 解析曲目封面路徑（含專輯回退機制） |
| 45 | Cover Art | `GetArtistCover` | 解析演出者頭像路徑（含專輯回退機制） |
| 46 | Cover Art | `GetPlaylistCover` | 解析播放清單封面路徑（含曲目回退機制） |
| 47 | Cover Art | `GetEntityImages` | 取得實體關聯之所有圖像資產清單 |
| 48 | Audio Engine | `audio.play` | 起播指定音訊來源 |
| 49 | Audio Engine | `audio.pause` | 暫停當前播放 |
| 50 | Audio Engine | `audio.resume` | 恢復播放 |
| 51 | Audio Engine | `audio.seek` | 跳轉播放進度 |
| 52 | Audio Engine | `audio.stop` | 停止播放並重置進度 |
| 53 | Audio Engine | `audio.set_volume` | 設定軟體輸出音量 |
| 54 | Audio Engine | `audio.get_state` | 取得播放引擎即時狀態快照 |
| 55 | Audio Engine | `audio.preload_next` | 預載下一首曲目（無縫切換） |
| 56 | Audio Engine | `audio.queue_next` | 預載下一首曲目（`preload_next` 同義別名） |
| 57 | Audio Engine | `audio.list_devices` | 列舉本機可用音訊輸出設備清單 |
| 58 | Audio Engine | `audio.set_output_device` | 切換實體音訊輸出設備 |
| 59 | Audio Engine | `audio.compare_versions` | 比對音訊版本規格並推薦母帶版本 |
| 60 | Audio Engine | `audio.get_waveform` | 取得時域波形峰值與 RMS 數據 |

---

## 3. 領域指令規格 (Domain Commands)

### 3.1 Track 曲目領域

#### `CreateTrack`
建立邏輯曲目實體並綁定聲學實體 PCM Hash。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `pcm_hash` | `string` | 是 | 64 字元長度之十六進位 SHA-256 PCM 雜湊值。 |
| `title` | `string` | 否 | 曲目標題。 |
| `work_id` | `string` | 否 | 所屬音樂作品 UUID。 |
| `recording_year` | `integer` | 否 | 錄音年份（1 ~ 9999）。 |
| `recording_month` | `integer` | 否 | 錄音月份（1 ~ 12）。 |
| `recording_day` | `integer` | 否 | 錄音日期（1 ~ 31）。 |
| `recording_location` | `string` | 否 | 錄音地點文字說明。 |
| `duration` | `integer` | 否 | 曲目長度（毫秒）。 |
| `isrc` | `string` | 否 | 國際標準錄音代碼 (ISRC)。 |
| `musicbrainz_id` | `string` | 否 | MusicBrainz Recording ID。 |
| `ytm_id` | `string` | 否 | YouTube Music 識別碼。 |
| `spotify_id` | `string` | 否 | Spotify 識別碼。 |

**Response 範例 (`code: 201`)**
```json
{
  "code": 201,
  "data": {
    "id": "e8d4a1b0-4f92-4d2a-9e1b-3c4d5e6f7a8b",
    "pcm_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "title": "Winter Wind"
  },
  "message": "Create Track success."
}
```

**常見 Error Types**：`MissingParameter`, `InvalidValue`, `DatabaseError`

---

#### `UpdateTrack`
更新現有曲目實體欄位。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `id` | `string` | 是 | 曲目 UUID。 |
| 其餘欄位 | - | 否 | 同 `CreateTrack`（至少需提供一項欲更新欄位）。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "id": "e8d4a1b0-4f92-4d2a-9e1b-3c4d5e6f7a8b"
  },
  "message": "Update Track success."
}
```

**常見 Error Types**：`TrackNotFound`, `InvalidValue`, `DatabaseError`

---

#### `GetTrack`
依 UUID 取得曲目詳細資訊。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `id` | `string` | 是 | 曲目 UUID。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "id": "e8d4a1b0-4f92-4d2a-9e1b-3c4d5e6f7a8b",
    "pcm_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "title": "Winter Wind",
    "work_id": null,
    "recording_year": 2024,
    "recording_month": 5,
    "recording_day": 12,
    "recording_location": "Berlin",
    "duration": 234000,
    "isrc": null,
    "musicbrainz_id": null,
    "ytm_id": null,
    "spotify_id": null,
    "created_at": "2026-09-01 10:00:00",
    "updated_at": "2026-09-01 10:00:00"
  }
}
```

**常見 Error Types**：`TrackNotFound`, `InvalidValue`

---

#### `ListTracks`
分頁查詢曲目清單。

**Request 參數**：通用分頁參數（`offset`, `limit`, `search`）。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "items": [
      {
        "id": "e8d4a1b0-4f92-4d2a-9e1b-3c4d5e6f7a8b",
        "pcm_hash": "e3b0c442...",
        "title": "Winter Wind"
      }
    ],
    "total": 1
  }
}
```

**常見 Error Types**：`OutOfRange`, `DatabaseError`

---

#### `GetTracksByTitle`
依標題精確搜尋曲目。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `title` | `string` | 是 | 曲目標題字串。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": [
    {
      "id": "e8d4a1b0-4f92-4d2a-9e1b-3c4d5e6f7a8b",
      "pcm_hash": "e3b0c442...",
      "title": "Winter Wind"
    }
  ]
}
```

**常見 Error Types**：`MissingParameter`, `DatabaseError`

---

#### `ImportTrack`
執行音訊檔案匯入管線，完成中繼資料抽取、CAS 儲存、聲學特徵計算與資料庫實體建立。

**匯入處理流程**
1. 讀取音訊來源檔案，抽取中繼資料標籤與內嵌封面。
2. 計算檔案 SHA-256 雜湊，將檔案寫入 CAS 物件庫目錄。
3. 解碼音訊計算 PCM SHA-256 雜湊與聲學規格（取樣率、聲道數、長度、響度）。
4. 在單一交易內建立 Asset 與 Audio 記錄、查重或建立 Artist 與 Album、建立 Track 實體並綁定關聯與封面。
5. 回傳建立結果與對應識別碼。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `source_path` | `string` | 是 | 本機音訊檔案絕對路徑。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "track_id": "7b8a1c9e-2d3f-4e5a-8b1c-9d0e1f2a3b4c",
    "pcm_hash": "a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef0",
    "title": "Nocturne in E-flat major, Op. 9, No. 2",
    "artist_id": "3a4b5c6d-7e8f-9a0b-1c2d-3e4f5a6b7c8d",
    "album_id": "f1e2d3c4-b5a6-9870-1234-56789abcdef0",
    "cover_image_hash": "b2c3d4e5f6a17890123456789abcdef0123456789abcdef0123456789abcdef1"
  }
}
```

**常見 Error Types**：`MissingParameter`, `InvalidValue`（檔案不存在或格式無法解碼）

---

### 3.2 Artist & Album 演出者與專輯領域

#### `CreateArtist`
建立演出者實體。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `name` | `string` | 是 | 演出者名稱。 |
| `musicbrainz_id` | `string` | 否 | MusicBrainz Artist ID。 |
| `ytm_id` | `string` | 否 | YouTube Music Channel ID。 |
| `spotify_id` | `string` | 否 | Spotify Artist ID。 |

**Response 範例 (`code: 201`)**
```json
{
  "code": 201,
  "data": {
    "id": "3a4b5c6d-7e8f-9a0b-1c2d-3e4f5a6b7c8d",
    "name": "Frédéric Chopin"
  },
  "message": "Create Artist success."
}
```

**常見 Error Types**：`MissingParameter`, `InvalidValue`, `DatabaseError`

---

#### `UpdateArtist`
更新演出者資訊。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `id` | `string` | 是 | 演出者 UUID。 |
| 其餘欄位 | - | 否 | 同 `CreateArtist`（至少提供一項欲更新欄位）。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "id": "3a4b5c6d-7e8f-9a0b-1c2d-3e4f5a6b7c8d"
  },
  "message": "Update Artist success."
}
```

**常見 Error Types**：`ArtistNotFound`, `InvalidValue`, `DatabaseError`

---

#### `GetArtist`
依 UUID 取得演出者詳細資訊。

**Request 參數**：`id` (`string`, 必填, UUID)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "id": "3a4b5c6d-7e8f-9a0b-1c2d-3e4f5a6b7c8d",
    "name": "Frédéric Chopin",
    "musicbrainz_id": null,
    "ytm_id": null,
    "spotify_id": null,
    "created_at": "2026-09-01 10:00:00",
    "updated_at": "2026-09-01 10:00:00"
  }
}
```

**常見 Error Types**：`ArtistNotFound`, `InvalidValue`

---

#### `ListArtists`
分頁查詢演出者清單。

**Request 參數**：通用分頁參數（`offset`, `limit`, `search`）。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "items": [
      {
        "id": "3a4b5c6d-7e8f-9a0b-1c2d-3e4f5a6b7c8d",
        "name": "Frédéric Chopin"
      }
    ],
    "total": 1
  }
}
```

**常見 Error Types**：`OutOfRange`, `DatabaseError`

---

#### `GetArtistsByName`
依名稱精確搜尋演出者。

**Request 參數**：`name` (`string`, 必填)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": [
    {
      "id": "3a4b5c6d-7e8f-9a0b-1c2d-3e4f5a6b7c8d",
      "name": "Frédéric Chopin"
    }
  ]
}
```

**常見 Error Types**：`MissingParameter`, `DatabaseError`

---

#### `CreateAlbum`
建立專輯實體。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `title` | `string` | 是 | 專輯標題。 |
| `release_year` | `integer` | 否 | 發行年份（1 ~ 9999）。 |
| `release_month` | `integer` | 否 | 發行月份（1 ~ 12）。 |
| `release_day` | `integer` | 否 | 發行日期（1 ~ 31）。 |

**Response 範例 (`code: 201`)**
```json
{
  "code": 201,
  "data": {
    "id": "f1e2d3c4-b5a6-9870-1234-56789abcdef0",
    "title": "Chopin: Complete Nocturnes"
  },
  "message": "Create Album success."
}
```

**常見 Error Types**：`MissingParameter`, `InvalidValue`, `DatabaseError`

---

#### `UpdateAlbum`
更新專輯資料。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `id` | `string` | 是 | 專輯 UUID。 |
| 其餘欄位 | - | 否 | 同 `CreateAlbum`（至少提供一項欲更新欄位）。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "id": "f1e2d3c4-b5a6-9870-1234-56789abcdef0"
  },
  "message": "Update Album success."
}
```

**常見 Error Types**：`AlbumNotFound`, `InvalidValue`, `DatabaseError`

---

#### `GetAlbum`
依 UUID 取得專輯詳細資訊。

**Request 參數**：`id` (`string`, 必填, UUID)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "id": "f1e2d3c4-b5a6-9870-1234-56789abcdef0",
    "title": "Chopin: Complete Nocturnes",
    "release_year": 2020,
    "release_month": 10,
    "release_day": 15,
    "created_at": "2026-09-01 10:00:00",
    "updated_at": "2026-09-01 10:00:00"
  }
}
```

**常見 Error Types**：`AlbumNotFound`, `InvalidValue`

---

#### `ListAlbums`
分頁查詢專輯清單。

**Request 參數**：通用分頁參數（`offset`, `limit`, `search`）。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "items": [
      {
        "id": "f1e2d3c4-b5a6-9870-1234-56789abcdef0",
        "title": "Chopin: Complete Nocturnes"
      }
    ],
    "total": 1
  }
}
```

**常見 Error Types**：`OutOfRange`, `DatabaseError`

---

#### `GetAlbumsByTitle`
依標題搜尋專輯。

**Request 參數**：`title` (`string`, 必填)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": [
    {
      "id": "f1e2d3c4-b5a6-9870-1234-56789abcdef0",
      "title": "Chopin: Complete Nocturnes"
    }
  ]
}
```

**常見 Error Types**：`MissingParameter`, `DatabaseError`

---

### 3.3 Work 音樂作品領域

Work 代表樂理層面的音樂創作（如《第五號交響曲》），可被多個錄音版本 Track 引用。

#### `CreateWork`
建立音樂作品實體。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `title` | `string` | 是 | 作品標題。 |
| `composition_start_year` | `integer` | 否 | 創作起始年（1 ~ 9999）。 |
| `composition_end_year` | `integer` | 否 | 創作結束年（1 ~ 9999）。需滿足 `start_year <= end_year`。 |
| `composition_date_text` | `string` | 否 | 創作日期備註文字。 |
| `iswc` | `string` | 否 | 國際標準音樂作品代碼 (ISWC)，具唯一性約束。 |
| `musicbrainz_id` | `string` | 否 | MusicBrainz Work ID。 |

**Response 範例 (`code: 201`)**
```json
{
  "code": 201,
  "data": {
    "id": "9b1c2d3e-4f5a-6b7c-8d9e-0f1a2b3c4d5e",
    "title": "Nocturne in E-flat major, Op. 9, No. 2",
    "composition_start_year": 1830,
    "composition_end_year": 1832,
    "composition_date_text": "1830–1832",
    "iswc": "T-043.208.544-7",
    "musicbrainz_id": null
  },
  "message": "Create Work success."
}
```

**常見 Error Types**：`MissingParameter`, `OutOfRange`（起訖年順序錯誤）, `Conflict`（ISWC 已存在）, `DatabaseError`

---

#### `UpdateWork`
更新音樂作品資訊。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `id` | `string` | 是 | 作品 UUID。 |
| 其餘欄位 | - | 否 | 同 `CreateWork`（若僅更新單一年份，將與現存年份校驗起訖順序）。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "id": "9b1c2d3e-4f5a-6b7c-8d9e-0f1a2b3c4d5e"
  },
  "message": "Update Work success."
}
```

**常見 Error Types**：`WorkNotFound`, `OutOfRange`, `Conflict`, `DatabaseError`

---

#### `GetWork`
依 UUID 取得作品詳細資訊。

**Request 參數**：`id` (`string`, 必填, UUID)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "id": "9b1c2d3e-4f5a-6b7c-8d9e-0f1a2b3c4d5e",
    "title": "Nocturne in E-flat major, Op. 9, No. 2",
    "composition_start_year": 1830,
    "composition_end_year": 1832,
    "composition_date_text": "1830–1832",
    "iswc": "T-043.208.544-7",
    "musicbrainz_id": null,
    "created_at": "2026-09-01 10:00:00",
    "updated_at": "2026-09-01 10:00:00"
  }
}
```

**常見 Error Types**：`WorkNotFound`, `InvalidValue`

---

#### `ListWorks`
分頁查詢音樂作品清單。

**Request 參數**：通用分頁參數（`offset`, `limit`, `search`）。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "items": [
      {
        "id": "9b1c2d3e-4f5a-6b7c-8d9e-0f1a2b3c4d5e",
        "title": "Nocturne in E-flat major, Op. 9, No. 2"
      }
    ],
    "total": 1
  }
}
```

**常見 Error Types**：`OutOfRange`, `DatabaseError`

---

#### `GetWorksByTitle`
依標題搜尋音樂作品。

**Request 參數**：`title` (`string`, 必填)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": [
    {
      "id": "9b1c2d3e-4f5a-6b7c-8d9e-0f1a2b3c4d5e",
      "title": "Nocturne in E-flat major, Op. 9, No. 2"
    }
  ]
}
```

**常見 Error Types**：`MissingParameter`, `DatabaseError`

---

### 3.4 Playlist & Playlist-Track 播放清單領域

#### `CreatePlaylist`
建立播放清單實體。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `title` | `string` | 是 | 播放清單標題。 |
| `description` | `string` | 否 | 播放清單說明文字。 |

**Response 範例 (`code: 201`)**
```json
{
  "code": 201,
  "data": {
    "id": "1c2d3e4f-5a6b-7c8d-9e0f-1a2b3c4d5e6f",
    "title": "Piano Classics",
    "description": "Essential classical piano recordings"
  },
  "message": "Create Playlist success."
}
```

**常見 Error Types**：`MissingParameter`, `DatabaseError`

---

#### `UpdatePlaylist`
更新播放清單標題或說明。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `id` | `string` | 是 | 播放清單 UUID。 |
| `title` | `string` | 否 | 新標題。 |
| `description` | `string` | 否 | 新說明文字。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "id": "1c2d3e4f-5a6b-7c8d-9e0f-1a2b3c4d5e6f"
  },
  "message": "Update Playlist success."
}
```

**常見 Error Types**：`PlaylistNotFound`, `InvalidValue`, `DatabaseError`

---

#### `GetPlaylist`
依 UUID 取得播放清單中繼資料。

**Request 參數**：`id` (`string`, 必填, UUID)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "id": "1c2d3e4f-5a6b-7c8d-9e0f-1a2b3c4d5e6f",
    "title": "Piano Classics",
    "description": "Essential classical piano recordings",
    "created_at": "2026-09-01 10:00:00",
    "updated_at": "2026-09-01 10:00:00"
  }
}
```

**常見 Error Types**：`PlaylistNotFound`, `InvalidValue`

---

#### `ListPlaylists`
分頁查詢播放清單列表。

**Request 參數**：通用分頁參數（`offset`, `limit`, `search`）。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "items": [
      {
        "id": "1c2d3e4f-5a6b-7c8d-9e0f-1a2b3c4d5e6f",
        "title": "Piano Classics"
      }
    ],
    "total": 1
  }
}
```

**常見 Error Types**：`OutOfRange`, `DatabaseError`

---

#### `GetPlaylistsByTitle`
依標題搜尋播放清單。

**Request 參數**：`title` (`string`, 必填)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": [
    {
      "id": "1c2d3e4f-5a6b-7c8d-9e0f-1a2b3c4d5e6f",
      "title": "Piano Classics"
    }
  ]
}
```

**常見 Error Types**：`MissingParameter`, `DatabaseError`

---

#### `AddPlaylistTrack`
新增曲目至播放清單。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `playlist_id` | `string` | 是 | 播放清單 UUID。 |
| `track_id` | `string` | 是 | 曲目 UUID。 |
| `position` | `integer` | 否 | 插入位置序號（從 0 起算）。若未提供則附加於清單末端。 |

**Response 範例 (`code: 201`)**
```json
{
  "code": 201,
  "message": "Add PlaylistTrack success."
}
```

**常見 Error Types**：`PlaylistNotFound`, `TrackNotFound`, `DatabaseError`

---

#### `RemovePlaylistTrack`
從播放清單移除指定曲目。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `playlist_id` | `string` | 是 | 播放清單 UUID。 |
| `track_id` | `string` | 是 | 曲目 UUID。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "message": "Remove PlaylistTrack success."
}
```

**常見 Error Types**：`RelationNotFound`, `DatabaseError`

---

#### `GetPlaylistTracks`
取得播放清單中所有曲目的 UUID 陣列。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `playlist_id` 或 `id` | `string` | 是 | 播放清單 UUID（支援 `playlist_id` 或 `id`）。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": [
    "e8d4a1b0-4f92-4d2a-9e1b-3c4d5e6f7a8b",
    "7b8a1c9e-2d3f-4e5a-8b1c-9d0e1f2a3b4c"
  ]
}
```

**常見 Error Types**：`MissingParameter`, `PlaylistNotFound`

---

### 3.5 Asset & CAS 檔案資產領域

Asset 代表實體二進位檔案（如 `.flac`, `.mp3`, `.jpg`）。CAS 存放路徑結構為：  
`<storage_root>/objects/{hash[0..1]}/{hash[2..3]}/{hash[4..]}.{ext}`

#### `CreateAsset`
登記實體檔案資產。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `file_hash` | `string` | 是 | 64 字元 SHA-256 檔案雜湊值。 |
| `pcm_hash` | `string` | 否 | 聲學實體 PCM 雜湊值。若提供，系統將於同一筆交易中建立 `Audio_Asset` 關聯。 |
| `mime_type` | `string` | 否 | MIME 類型（例如 `"audio/flac"`, `"image/jpeg"`）。 |
| `asset_type` | `string` | 否 | 資產類別（例如 `"audio"`, `"image"`）。 |
| `file_size` | `integer` | 否 | 檔案大小（位元組）。 |

**Response 範例 (`code: 201`)**
```json
{
  "code": 201,
  "data": {
    "file_hash": "a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef0"
  },
  "message": "Create Asset success."
}
```

**常見 Error Types**：`MissingParameter`, `DatabaseError`

---

#### `UpdateAsset`
更新檔案資產中繼資料。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `file_hash` | `string` | 是 | 檔案雜湊值。 |
| `mime_type` | `string` | 否 | 新 MIME 類型。 |
| `asset_type` | `string` | 否 | 新資產類別。 |
| `file_size` | `integer` | 否 | 新檔案大小。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "file_hash": "a1b2c3d4e5f6..."
  },
  "message": "Update Asset success."
}
```

**常見 Error Types**：`InvalidValue`, `DatabaseError`

---

#### `GetAsset`
依檔案雜湊取得資產詳細資訊。

**Request 參數**：`file_hash` (`string`, 必填)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "file_hash": "a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef0",
    "mime_type": "audio/flac",
    "asset_type": "audio",
    "file_size": 52428800,
    "created_at": "2026-09-01 10:00:00",
    "updated_at": "2026-09-01 10:00:00"
  }
}
```

**常見 Error Types**：`AssetNotFound`, `InvalidValue`

---

#### `ListAssets`
分頁查詢實體資產列表。

**Request 參數**：通用分頁參數（`offset`, `limit`, `search`）。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "items": [
      {
        "file_hash": "a1b2c3d4...",
        "mime_type": "audio/flac",
        "file_size": 52428800
      }
    ],
    "total": 1
  }
}
```

**常見 Error Types**：`OutOfRange`, `DatabaseError`

---

#### `IngestAsset`
將本機檔案直接匯入 CAS 儲存庫並解析中繼資料。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `source_path` | `string` | 是 | 本機檔案絕對路徑。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "asset": {
      "file_hash": "a1b2c3d4e5f6...",
      "mime_type": "audio/flac",
      "asset_type": "audio",
      "file_size": 52428800
    },
    "audio": {
      "pcm_hash": "e3b0c442...",
      "duration": 248.52,
      "sample_rate": 96000,
      "channels": 2
    },
    "cover_file_hash": "b2c3d4e5...",
    "cover_image_hash": "c3d4e5f6..."
  }
}
```

**常見 Error Types**：`MissingParameter`, `InvalidValue`

---

#### `GetResourcePath`
解析音訊資產在本機儲存庫中的絕對檔案路徑。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `track_id` | `string` | 條件必填 | 曲目 UUID（與 `pcm_hash`、`file_hash` 三選一）。 |
| `pcm_hash` | `string` | 條件必填 | 聲學實體 PCM 雜湊值。 |
| `file_hash` | `string` | 條件必填 | 實體檔案 SHA-256 雜湊值。 |
| `preferred_format` | `string` | 否 | 偏好副檔名/格式（例如 `"FLAC"`, `"MP3"`，支援別名 `format`）。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "path": "/home/ryan/Music/Storage/objects/a1/b2/c3d4e5f67890.flac",
    "mime_type": "audio/flac"
  }
}
```

**常見 Error Types**：`MissingParameter`, `TrackNotFound`, `AudioNotFound`, `AssetNotFound`

---

### 3.6 Audio 聲學實體領域

Audio 代表解碼後的 Raw PCM 聲學特徵。多版本管理採用單層星狀拓撲（Single-Level Star Topology）：所有次要錄音版本的 `parent_hash` 均直接指向 Master 版本。若 Master 記錄被刪除，次要版本的 `parent_hash` 自動設為 `NULL`。

#### `CreateAudio`
建立聲學實體記錄。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `pcm_hash` | `string` | 是 | 64 字元 SHA-256 PCM 雜湊值。 |
| `parent_hash` | `string` | 否 | 指向 Master 版本之 PCM 雜湊值。 |
| `quality_score` | `integer` | 否 | 音質評分（0 ~ 100）。 |
| `bit_depth` | `integer` | 否 | 位元深度（如 16, 24）。 |
| `sample_rate` | `integer` | 否 | 取樣頻率（Hz，如 44100, 96000）。 |
| `channels` | `integer` | 否 | 聲道數（如 1, 2）。 |
| `duration` | `number` | 否 | 長度（秒，浮點數）。 |
| `integrated_loudness` | `number` | 否 | 綜合響度（LUFS，浮點數）。 |
| `true_peak` | `number` | 否 | 真峰值（dBTP，浮點數）。 |

**Response 範例 (`code: 201`)**
```json
{
  "code": 201,
  "data": {
    "pcm_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  },
  "message": "Create Audio success."
}
```

**常見 Error Types**：`MissingParameter`, `DatabaseError`

---

#### `UpdateAudio`
更新聲學實體屬性。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `pcm_hash` | `string` | 是 | 聲學實體 PCM 雜湊值。 |
| 其餘欄位 | - | 否 | 同 `CreateAudio`（至少提供一項欲更新欄位）。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "pcm_hash": "e3b0c442..."
  },
  "message": "Update Audio success."
}
```

**常見 Error Types**：`InvalidValue`, `DatabaseError`

---

#### `GetAudio`
取得聲學實體詳細資訊，回應包含所有關聯檔案的 `assets` 陣列。

**Request 參數**：`pcm_hash` (`string`, 必填)。

**Response 範例 (`code: 200`)**
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
        "created_at": "2026-09-01 10:00:00"
      }
    ]
  }
}
```

**常見 Error Types**：`AudioNotFound`, `InvalidValue`

---

#### `ListAudio`
分頁查詢聲學實體清單。

**Request 參數**：通用分頁參數（`offset`, `limit`, `search`）。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "items": [
      {
        "pcm_hash": "e3b0c442...",
        "sample_rate": 96000,
        "quality_score": 96
      }
    ],
    "total": 1
  }
}
```

**常見 Error Types**：`OutOfRange`, `DatabaseError`

---

### 3.7 Track-Artist 演出關聯領域

管理曲目與演出者之間的多對多關聯關係。

#### `AddTrackArtist`
建立曲目與演出者之關聯。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `track_id` | `string` | 是 | 曲目 UUID。 |
| `artist_id` | `string` | 是 | 演出者 UUID。 |
| `role` | `string` | 是 | 角色列舉值：`main`, `featured`, `remixer`, `producer`, `conductor`, `performer`, `engineer`。 |
| `position` | `integer` | 否 | 演出名單排序序號（1, 2, ...）。 |

**Response 範例 (`code: 201`)**
```json
{
  "code": 201,
  "data": {
    "track_id": "e8d4a1b0-4f92-4d2a-9e1b-3c4d5e6f7a8b",
    "artist_id": "3a4b5c6d-7e8f-9a0b-1c2d-3e4f5a6b7c8d",
    "role": "main",
    "position": 1
  },
  "message": "Add Track_Artist success."
}
```

**常見 Error Types**：`TrackNotFound`, `ArtistNotFound`, `InvalidValue`, `DatabaseError`

---

#### `UpdateTrackArtist`
更新曲目中演出者的角色或排序序號。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `track_id` | `string` | 是 | 曲目 UUID。 |
| `artist_id` | `string` | 是 | 演出者 UUID。 |
| `role` | `string` | 否 | 新角色列舉值（同 `AddTrackArtist`）。 |
| `position` | `integer` | 否 | 新排序序號。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "track_id": "e8d4a1b0-4f92-4d2a-9e1b-3c4d5e6f7a8b",
    "artist_id": "3a4b5c6d-7e8f-9a0b-1c2d-3e4f5a6b7c8d",
    "role": "featured",
    "position": 2
  },
  "message": "Update Track_Artist success."
}
```

**常見 Error Types**：`RelationNotFound`, `InvalidValue`, `DatabaseError`

---

#### `RemoveTrackArtist`
解除曲目與演出者的關聯。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `track_id` | `string` | 是 | 曲目 UUID。 |
| `artist_id` | `string` | 是 | 演出者 UUID。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "message": "Remove Track_Artist success."
}
```

**常見 Error Types**：`RelationNotFound`, `DatabaseError`

---

### 3.8 Cover Art 封面圖像領域

#### 封面解析回退邏輯 (Fallback Hierarchy)
- **`GetTrackCover`**：優先查詢曲目專屬封面；若無，自動回退查詢所屬專輯的封面；若仍無則回傳 `404 NotFound`。
- **`GetArtistCover`**：優先查詢角色為 `artist_avatar` 的頭像圖片；若無，自動回退查詢該演出者最新發行專輯的封面；若仍無則回傳 `404 NotFound`。
- **`GetPlaylistCover`**：優先查詢播放清單自訂封面；若無，自動回退查詢清單中第一首曲目的封面（適用 Track 回退規則）；若清單為空或曲目均無封面則回傳 `404 NotFound`。
- **`GetAlbumCover`**：查詢專輯所屬封面。

---

#### `GetAlbumCover`
解析專輯最佳封面檔案路徑。

**Request 參數**：`album_id` (`string`, 必填, UUID)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "image_hash": "c1d2e3f4a5b6...",
    "file_hash": "f5e4d3c2b1a0...",
    "path": "/home/ryan/Music/Storage/objects/f5/e4/d3c2b1a0.jpg",
    "mime_type": "image/jpeg",
    "width": 1400,
    "height": 1400
  },
  "status": "success"
}
```

**常見 Error Types**：`AlbumNotFound`, `NotFound`

---

#### `GetTrackCover`
解析曲目封面檔案路徑（支援回退至所屬專輯封面）。

**Request 參數**：`track_id` (`string`, 必填, UUID)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "image_hash": "c1d2e3f4a5b6...",
    "file_hash": "f5e4d3c2b1a0...",
    "path": "/home/ryan/Music/Storage/objects/f5/e4/d3c2b1a0.jpg",
    "mime_type": "image/jpeg",
    "width": 1400,
    "height": 1400
  },
  "status": "success"
}
```

**常見 Error Types**：`TrackNotFound`, `NotFound`

---

#### `GetArtistCover`
解析演出者頭像/封面路徑（支援回退至最新專輯封面）。

**Request 參數**：`artist_id` (`string`, 必填, UUID)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "image_hash": "a2b3c4d5e6f7...",
    "file_hash": "1a2b3c4d5e6f...",
    "path": "/home/ryan/Music/Storage/objects/1a/2b/3c4d5e6f.png",
    "mime_type": "image/png",
    "width": 800,
    "height": 800
  },
  "status": "success"
}
```

**常見 Error Types**：`ArtistNotFound`, `NotFound`

---

#### `GetPlaylistCover`
解析播放清單封面路徑（支援回退至第一首曲目封面）。

**Request 參數**：`playlist_id` (`string`, 必填, UUID)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "image_hash": "c1d2e3f4a5b6...",
    "file_hash": "f5e4d3c2b1a0...",
    "path": "/home/ryan/Music/Storage/objects/f5/e4/d3c2b1a0.jpg",
    "mime_type": "image/jpeg",
    "width": 1400,
    "height": 1400
  },
  "status": "success"
}
```

**常見 Error Types**：`PlaylistNotFound`, `NotFound`

---

#### `GetEntityImages`
取得特定實體關聯之所有圖像清單。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `entity_id` | `string` | 是 | 實體 UUID（Track, Album, Artist, Playlist）。 |
| `role` | `string` | 否 | 圖像角色篩選（如 `"front"`, `"back"`, `"artist_avatar"`）。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": [
    {
      "image_hash": "c1d2e3f4a5b6...",
      "file_hash": "f5e4d3c2b1a0...",
      "path": "/home/ryan/Music/Storage/objects/f5/e4/d3c2b1a0.jpg",
      "mime_type": "image/jpeg",
      "width": 1400,
      "height": 1400,
      "dominant_color": "#2A3B4C",
      "role": "front"
    }
  ],
  "status": "success"
}
```

**常見 Error Types**：`NotFound`, `DatabaseError`

---

## 4. 音訊播放引擎指令 (Audio Engine Controls)

音訊控制指令提供本機音訊解碼、輸出播放、無縫預載與設備切換能力。

### `audio.play`
起播音訊檔案或實體，支援斷點時間起播。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `file_path` | `string` | 條件必填 | 本機音訊檔案絕對路徑（與下列識別碼四選一）。 |
| `track_id` | `string` | 條件必填 | 曲目 UUID（支援別名 `id`）。 |
| `pcm_hash` | `string` | 條件必填 | 聲學實體 PCM 雜湊值（支援別名 `audio_id`）。 |
| `file_hash` | `string` | 條件必填 | 檔案資產 SHA-256 雜湊值（支援別名 `asset_id`）。 |
| `start_position` | `number` | 否 | 起播秒數（浮點數，預設 `0.0`，支援別名 `start_position_seconds`）。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "state": "PLAYING",
    "file_path": "/home/ryan/Music/Storage/objects/ab/cd/ef01.flac",
    "next_file_path": "",
    "device_id": "default",
    "position": 0.0,
    "duration": 248.52,
    "volume": 1.0
  }
}
```

**常見 Error Types**：`MissingParameter`, `NotFound`, `InvalidValue`

---

### `audio.pause`
暫停當前音訊播放。

**Request 參數**：無參數 (`{}`)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "state": "PAUSED",
    "file_path": "/home/ryan/Music/Storage/objects/ab/cd/ef01.flac",
    "next_file_path": "",
    "device_id": "default",
    "position": 42.18,
    "duration": 248.52,
    "volume": 1.0
  }
}
```

**常見 Error Types**：無

---

### `audio.resume`
自暫停狀態恢復播放。

**Request 參數**：無參數 (`{}`)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "state": "PLAYING",
    "file_path": "/home/ryan/Music/Storage/objects/ab/cd/ef01.flac",
    "next_file_path": "",
    "device_id": "default",
    "position": 42.18,
    "duration": 248.52,
    "volume": 1.0
  }
}
```

**常見 Error Types**：無

---

### `audio.seek`
跳轉至指定播放時間。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `position` | `number` | 是 | 目標秒數（浮點數，支援別名 `position_seconds`）。 |
| `relative` | `boolean` | 否 | 是否為相對當前位置位移（預設 `false`。若為 `true`，正數快轉、負數倒退）。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "state": "PLAYING",
    "file_path": "/home/ryan/Music/Storage/objects/ab/cd/ef01.flac",
    "next_file_path": "",
    "device_id": "default",
    "position": 120.0,
    "duration": 248.52,
    "volume": 1.0
  }
}
```

**常見 Error Types**：`MissingParameter`, `InvalidValue`

---

### `audio.stop`
停止播放並清空解碼與緩衝狀態。

**Request 參數**：無參數 (`{}`)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "state": "STOPPED",
    "file_path": "",
    "next_file_path": "",
    "device_id": "default",
    "position": 0.0,
    "duration": 0.0,
    "volume": 1.0
  }
}
```

**常見 Error Types**：無

---

### `audio.set_volume`
調整軟體輸出音量。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `volume` | `number` | 是 | 浮點數音量數值，範圍限制為 `0.0` 至 `1.0`。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "state": "PLAYING",
    "file_path": "/home/ryan/Music/Storage/objects/ab/cd/ef01.flac",
    "next_file_path": "",
    "device_id": "default",
    "position": 42.18,
    "duration": 248.52,
    "volume": 0.75
  }
}
```

**常見 Error Types**：`MissingParameter`, `InvalidValue`

---

### `audio.get_state`
輪詢取得音訊引擎即時狀態快照。

**Request 參數**：無參數 (`{}`)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "state": "PLAYING",
    "file_path": "/home/ryan/Music/Storage/objects/ab/cd/ef01.flac",
    "next_file_path": "/home/ryan/Music/Storage/objects/12/34/5678.flac",
    "device_id": "default",
    "position": 42.18,
    "duration": 248.52,
    "volume": 0.75
  }
}
```

**常見 Error Types**：無

---

### `audio.preload_next`
預先載入下一首曲目，使當前曲目播畢時能零延遲無縫銜接。`audio.queue_next` 為此命令的同義別名。傳入空字串或空參數可取消預載。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `file_path` | `string` | 條件選填 | 本機音訊檔案路徑。 |
| `track_id` | `string` | 條件選填 | 曲目 UUID（支援別名 `id`）。 |
| `pcm_hash` | `string` | 條件選填 | 聲學實體 PCM 雜湊值（支援別名 `audio_id`）。 |
| `file_hash` | `string` | 條件選填 | 檔案資產 SHA-256 雜湊值（支援別名 `asset_id`）。 |

*註：若未帶入上述任何欄位，或傳入空字串，將清空已排程的預載曲目。*

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "next_file_path": "/home/ryan/Music/Storage/objects/12/34/5678.flac",
    "queued": true
  }
}
```

**常見 Error Types**：`NotFound`, `InvalidValue`

---

### `audio.list_devices`
列舉本機可用之實體音訊輸出設備。

**Request 參數**：無參數 (`{}`)。

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "current_device_id": "default",
    "devices": [
      {
        "id": "default",
        "name": "Default Audio Device",
        "is_default": true
      },
      {
        "id": "alsa_hw_DAC_0",
        "name": "External USB DAC",
        "is_default": false
      }
    ]
  }
}
```

**常見 Error Types**：無

---

### `audio.set_output_device`
切換實體音訊輸出設備。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `device_id` | `string` | 是 | 目標設備識別碼（來自 `audio.list_devices`）。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "device_id": "alsa_hw_DAC_0",
    "success": true
  },
  "message": "Output device updated successfully."
}
```

**常見 Error Types**：`MissingParameter`, `InvalidValue`

---

### `audio.compare_versions`
比對多版本錄音之聲學規格與品質指標，並推薦最佳母帶版本。

**評估排序維度**
1. **品質總分 (`quality_score`)**：依解析度（取樣率、位元深度）、格式無損性與聲道數綜合計算。
2. **無損優先**：分數相同時，無損格式優先於有損格式。
3. **檔案容量**：若依舊相同，檔案容量較大者優先。
4. **雜湊字典序**：平手時採 PCM Hash 字典序確保結果確定性。
排名第一者標記為 `is_master: true` 並設為 `recommended_master`。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `track_id` | `string` | 條件必填 | 曲目 UUID（自動查詢該曲目所屬版本家族）。 |
| `pcm_hashes` | `array` | 條件必填 | 明確傳入欲比對的 PCM Hash 字串陣列（與 `track_id` 二選一）。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "recommended_master": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "versions": [
      {
        "pcm_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "format": "FLAC",
        "quality_score": 96,
        "is_lossless": true,
        "file_size": 52428800,
        "is_master": true
      },
      {
        "pcm_hash": "a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef0",
        "format": "MP3",
        "quality_score": 68,
        "is_lossless": false,
        "file_size": 8388608,
        "is_master": false
      }
    ]
  }
}
```

**常見 Error Types**：`MissingParameter`, `TrackNotFound`, `AudioNotFound`, `InvalidValue`

---

### `audio.get_waveform`
取得音訊的時域波形峰值與均方根（RMS）振幅數據。波形計算結果由核心本機二進位檔案自動快取。

**Request 參數**

| 欄位 | 型別 | 必填 | 邊界與說明 |
| :--- | :--- | :---: | :--- |
| `track_id` | `string` | 條件必填 | 曲目 UUID（與 `pcm_hash` 二選一）。 |
| `pcm_hash` | `string` | 條件必填 | 聲學實體 PCM 雜湊值。 |
| `points` | `integer` | 否 | 取樣點數，範圍限制在 `50` 至 `1000` 之間（預設 `300`）。 |
| `preferred_format` | `string` | 否 | 偏好檔案格式（支援別名 `format`）。 |

**Response 範例 (`code: 200`)**
```json
{
  "code": 200,
  "data": {
    "pcm_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "points": 300,
    "peaks": [
      [-0.05, 0.08],
      [-0.32, 0.41],
      [-0.78, 0.82]
    ],
    "rms": [0.04, 0.25, 0.61]
  }
}
```

**常見 Error Types**：`MissingParameter`, `TrackNotFound`, `AudioNotFound`, `OutOfRange`, `NotFound`

---

## 5. 事件推送規格 (Event Callbacks)

透過 `lyra_register_event_callback` 註冊回調後，引擎在播放狀態轉換時將主動推送 JSON 事件。

### 事件清單

| 事件名稱 (`event`) | 觸發情境說明 |
| :--- | :--- |
| `audio_state_changed` | 播放狀態躍遷時觸發（起播、暫停、恢復或停止）。 |
| `audio_seek` | 執行進度跳轉完成時觸發。 |
| `audio_volume_changed` | 軟體輸出音量改變時觸發。 |
| `audio_track_changed` | 當前曲目播畢，自動無縫接續下一首預載曲目時觸發。 |
| `audio_ended` | 曲目播放完畢且無後續預載曲目，引擎自動進入停止狀態時觸發。 |

### 事件資料結構

所有事件均帶有包含引擎當前完整狀態的 `data` 負載：

```json
{
  "event": "audio_state_changed",
  "data": {
    "state": "PLAYING",
    "file_path": "/home/ryan/Music/Storage/objects/ab/cd/ef01.flac",
    "next_file_path": "/home/ryan/Music/Storage/objects/12/34/5678.flac",
    "device_id": "default",
    "position": 42.18,
    "duration": 248.52,
    "volume": 0.85
  }
}
```

#### `data` 負載欄位說明

| 欄位 | 型別 | 說明 |
| :--- | :--- | :--- |
| `state` | `string` | 當前引擎狀態，枚舉值為 `"PLAYING"`, `"PAUSED"`, `"STOPPED"`。 |
| `file_path` | `string` | 當前播放音訊檔案之本機路徑（停止時為空字串）。 |
| `next_file_path` | `string` | 目前已預載之下一首音訊路徑（無預載時為空字串）。 |
| `device_id` | `string` | 當前使用中之輸出設備識別碼。 |
| `position` | `number` | 當前播放進度（秒，浮點數）。 |
| `duration` | `number` | 音訊總長度（秒，浮點數）。 |
| `volume` | `number` | 當前音量數值（`0.0` ~ `1.0`）。 |
