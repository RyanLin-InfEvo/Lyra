# Lyra Design Document

> 一個為「長期可信、可重現、工程潔癖」而生的個人音樂資產系統
Lyra 管的是「聲音主體」，並指定一個可被信任的 Master，其他格式全部是衍生物。
---

## 0. 專案定位

Lyra 是一個由**個人需求**出發的**開源音樂資產管理系統**，管理一個**全面的音樂庫**將不再是一件令人頭疼的事。

Lyra 的宗旨：
* 內容定址儲存：**依據**資料「內容」而非「實體位址」來存取資料。
* 不可變性：一旦寫入 `/objects/`，音訊物件視為唯讀。

---

## 1. 核心哲學

### 1.1 音訊內容優先（Content over Container）

* 音樂的本質是「聲音」，不是檔名、不是標籤、不是容器格式。
* Lyra 以 **解碼後音訊內容** 作為識別與驗證基礎。

---

### 1.2 內容定址儲存（Content-Addressable Storage, CAS）

* 每一個音訊物件都由其內容雜湊值唯一識別。
* 相同聲音只會儲存一次。

---

### 1.3 資料庫是唯一真理（Database as Source of Truth）

* 匯入後，所有顯示資訊以資料庫為準。
* Lyra **不回寫音檔 metadata**，避免污染原始資料。

---

### 1.4 不可變性（Immutability）

* 一旦寫入 `/objects/`，音訊物件視為唯讀。
* 所有修改都以「新增新物件」的方式進行。
* 不可變性 ≠ 不可刪除；允許標記損毀並重建。

---

## 2. Hash 定義

### 2.1 Hash 的意義

Lyra 的 hash 用來回答：

> 「在**明確定義的技術條件下**，這段聲音是否與另一段聲音相同？」

* 例如：`ffmpeg -f md5`
---

### 2.2 Hash 規格

* 工具：`ffmpeg` 
* 版本：固定版本（記錄於資料庫）
* 輸入：任意支援的音訊檔案
* 流程：

  1. 解碼為 PCM
  2. 不進行 resample
  3. 固定輸出格式（例如 `s32le`）
  4. 對 PCM 串流計算雜湊（預設 md5）

---

### 2.3 關於一致性

* hash 僅保證在 **相同環境與定義** 下可重現。
* 不保證跨 ffmpeg 版本、不同 decoder、不同 compile flags 完全一致。

---

## 3. 專案分層與目錄結構

設計目標是：

* 哪一層可以常改
* 哪一層改了會牽一髮動全身
* 哪一層是對外承諾（API / 資料結構）

```
lyra/
├── .git/                   # Git 版本控制目錄
├── .gitignore              # Git 忽略規則
├── README.md               # 專案介紹、建置與使用方式
├── LICENSE                 # 開源授權條款
├── vcpkg.json              # C++ 相依套件清單（Core）
│
├── docs/                   # [文檔層] 設計
│   ├── Lyra_Design_Document.md
│   ├── Lyra_Project_Master_Plan.md
│   ├── schema.sql          # 資料庫結構備份
│   └── images/
│
├── core/                   # [核心層] C++ Backend（liblyra）
│   ├── CMakeLists.txt
│   ├── include/            # 對外穩定 API（extern "C"）
│   │   └── lyra_c_api.h
│   ├── src/                # 內部實作
│   │   ├── database.cpp
│   │   ├── hash.cpp
│   │   ├── importer.cpp
│   │   └── internal.h
│   └── tests/              # 單元測試
│       └── test_hash.cpp
│
├── ui/                     # [介面層] Flutter Frontend（lyra_desktop）
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart
│   │   ├── ffi_bridge.dart # FFI 橋接層（高風險，需謹慎修改）
│   │   └── screens/
│   ├── linux/
│   ├── windows/
│   └── android/            # 未來擴充
│
└── scripts/                # [工具層] 開發輔助腳本
    ├── setup_env.sh
    └── build_all.py
```

### 分層原則說明

* **docs/**：

  * 可隨時修改，不影響執行結果
  * 用來避免未來「不知道自己當初為什麼這樣設計」

* **core/include/**：

  * 對外 API 契約
  * 一旦修改，UI 與其他語言綁定都會受影響

* **core/src/**：

  * 允許重構與實驗
  * 不應被 UI 或外部程式直接依賴

* **ui/**：

  * 快速變動層
  * 嚴禁直接假設 core 的內部實作

* **scripts/**：

  * 方便比「優雅」重要
  * 可重寫、可刪除，不算技術債

---

## 4.前後端交互分式

### v0.1 單機 MVP
目標：
* 暫時不考慮 Server
* 先完成 Core，用 Json 與外界交互

Core 功能：
* 計算 Hash
* 用 hash 值歸檔到 /objects
* 與外界使用 Json 交互
* 調用 yt-dlp 取得歌曲資訊、下載
* DB 的 MVP

Core 對外功能：
* 查詢 `Work、Track、File、Source`內項目，Json Request 範例：
``` json
  {
    "protocol": "lyra-core",
    "version": 0,
    "command": "FindDB",
    "params":{
      "text":[ "会开花的云","周深深" ],
      "Search_DB":{
        "Work":[ "title","artist","year" ],
        "Track":[ "title","artist" ]
      },
      "Return_DB":{
        "Work":[ "title","artist","uuid","cover","year" ],
        "Track":[ "title","artist","uuid","cover","year" ]
      },
      "Sort":{ "Track":{ "title":"asc" } },
      "Limit":10
    }
  } 
``` 


* 列出 `Work、Track、File、Source`內項目，Json Request 範例：
``` json
  {
    "protocol": "lyra-core",
    "version": 0,
    "command": "ListDB",
    "params":{
      "Return_DB":{
        "Track":[ "title","artist","cover","year","album" ]
      },
      "Sort":{ "Track":{ "title":"asc" } },
      "Limit":10
    }
  } 
``` 

* 從 YTM 匯入 song 或 playlist，Json Request 範例：
``` json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "ImportYTM",
  "params":{
    "url": [
      "https://music.youtube.com/playlist?list=PLl56WN7M6o4wGU6Cdk_q1BA6akQK417FU&si=AvIBY5RsdcKdA-XN", 
    "https://music.youtube.com/playlist?list=PLl56WN7M6o4xd81bcgKRbwYFUm96jiBxp"]
  }
} 
``` 

* 匯入檔案，Json Request 範例：
``` json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "ImportFile",
  "params":{
    "path":"/home/ryan/Downloads/music.opus"
  }
} 
``` 

* 新增 Playlist，Json Request 範例：
``` json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "NewPlaylist",
  "params":{
    "title":"My Playlist",
    "description":"My Playlist Description"
  }
} 
``` 

* 刪除 Playlist，Json Request 範例：
``` json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "DeletePlaylist",
  "params":{
    "uuid":[ "playlist_id", "playlist_id"]
  }
} 
``` 

* 新增歌曲至 Playlist，Json Request 範例：
  可將 tracks們 都 加入至 playlists們。
``` json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "AddTrackToPlaylist",
  "params":{
    "playlist_uuid":[ "playlist_id", "playlist_id"],
    "track_uuid":[ "track_id", "track_id" ]
  }
} 
``` 

* 刪除歌曲自 Playlist，Json Request 範例：
``` json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "DeleteTrackFromPlaylist",
  "params":{
    "playlist_uuid":[ "playlist_id", "playlist_id"],
    "track_uuid":[ "track_id", "track_id" ]
  }
} 
``` 

* 獲取資源路徑，Json Request 範例：
``` json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "GetResourcePath",
  "params":{
    "uuid": [ "resource_id", "resource_id" ]
  }
} 
``` 
### v0.2 GUI 的開始

emm... Flutter(Dart) 的 GUI 框架

## 5. 檔案系統結構

```
LyraRepo/
├── lyra.db
└── objects/
    └── ab/
        └── cd/
            └── abcd1234....flac
```

* 路徑由 hash 前綴分層
* 檔名即 hash

---

## 6. 資料庫 Schema 設計邏輯

### Entity Layer
所有具備業務意義的物件（Artist, Work, Album, Playlist, Track）皆繼承自 `Entity` 表，共用 UUID 主鍵。
* **設計目的**：統一 ID 空間，方便圖片 (Entity_Images) 與文本 (Entity_Text) 的掛載。

#### Junction Tables
* **`Entity_Text`**Table：多對多關聯，**`entity_id`<->`Text`**。
由Gemini生成`Entity_Text.role`，現在先預留，未來再實做功能 :
``` sql
ENUM(
    -- 【歌詞類 Lyrics】
    'lyrics',                  -- 原文歌詞 (無論有無時間軸)
    'lyrics_translation',      -- 歌詞翻譯 (Translation)
    'lyrics_transliteration',  -- 歌詞讀音/羅馬拼音 (Romaji/Jyutping/Pinyin)

    -- 【描述與介紹 Information】
    'description',             -- 通用描述 (播放清單描述、作品簡介)
    'biography',               -- 藝人傳記 (Bio)
    'liner_notes',             -- 專輯內頁文案 (通常是樂評或製作人寫的長文)

    -- 【資料與信用 Data】
    'credits',                 -- 完整工作人員名單 (Credits/Staff)
    'review',                  -- 樂評/評論 (Critic Review)
    'trivia',                  -- 冷知識/趣聞 (Did you know?)

    -- 【其他】
    'other'                    -- 其他
)
```
---
* **`Entity_Image`**Table：多對多關聯，**`entity_id`<->`Image`**。
由Gemini生成`Entity_Image.role`，現在先預留，未來再實做功能 :
```sql
ENUM(
    -- 專輯/歌曲相關 (Album/Track)
    'front',          -- 封面 (最重要)
    'back',           -- 封底
    'leaflet',        -- 歌詞本/內頁 (Booklet)
    'medium',         -- 實體光碟/黑膠盤面 (CD/Vinyl Art)
    'spine',          -- 側標 (Obi/Spine)
    'matrix',         -- 其他矩陣資訊

    -- 藝人相關 (Artist)
    'artist_avatar',  -- 頭像 (圓形/方形)
    'artist_logo',    -- 樂團 Logo (去背 PNG)
    'artist_banner',  -- 橫幅 (背景圖)

    -- 其他 (Playlist/Series)
    'thumbnail',      -- 縮圖
    'other'           -- 備用
)
```
---
* **`Work_Artist.role`**：
```sql
ENUM(
    'composer',   -- 作曲 (通常是 Classical 或 Instrumental 的核心)
    'lyricist',   -- 作詞
    'arranger',   -- 編曲 (對 Work 的結構編排，非錄音混音)
    'librettist'  -- 劇本/歌詞作者 (歌劇/音樂劇專用，可視需求合併至 lyricist)
)
```
---
* **`Track_Artist.role`**：
```sql
ENUM(
    'main',       -- 主依人 (Primary Artist, 專輯列表上顯示的名字)
    'featured',   -- 客串 (Feat., Guest)
    'remixer',    -- 混音師 (對於電子音樂或 Remix 版本，此人權重等同 Main)
    'producer',   -- 製作人 (決定錄音品質與風格的人)
    'conductor',  -- 指揮 (古典樂必備)
    'performer',  -- 樂手/伴奏 (Orchestra, Band member, Session musician)
    'engineer'    -- 錄音/混音/母帶工程師 (視你的潔癖程度決定是否收錄)
)
```
---
* **`Album_Artist.role`**：
```sql
ENUM(
    'main',       -- 主要藝人 (流行樂的歌手、樂團)
    'composer',   -- 作曲家 (古典樂專輯的主要歸檔依據)
    'conductor',  -- 指揮家 (古典樂中常與作曲家並列為封面人物)
    'compiler'    -- 選曲/混音者 (適用於 Compilation 或 DJ Mix 專輯)
)
```
* **`Track_Playlist.position`**：
  * Data Type： **unsigned int**, range: $0 \sim 2^{32}-1$, about 429.4 Million integers
  * 稀疏索引：$Gap_{ideal}=2^{16}$，
    * 順序新增(Append)第n首歌，則`pos`為 $MAX(pos) + Gap_{ideal}$
    * 插入**第n首歌**與**第n+1首歌**之間，則`pos`為 $\frac{pos_n + pos_{n+1}}{2}$。插入在**第1首歌**之前，`pos` 為 $\frac{pos_{first}}{2}$。
    * 刪除第n首歌，則直接刪除
    * 重整(Rebalance)，當 $Gap < 1$，$Gap_{new}= \frac{2^{32}}{ (n_{end} + n_{end} \times 10)}$

### Asset Layer
* **Idenity**：`file_hash` SHA256, BINARY(16) in DB。
* **儲存**：對應 `/objects/` 下的實體檔案。
* **`Asset.asset_type`**：`SUBSTRING_INDEX(mime_type, '/', 1)`

### Audio Layer
* **Idenity**：`pcm_hash`(ffmpeg decoded raw stream hash), BINARY(32) in DB。
* **設計目的**：
  * 「無損 Wav Flac -> **內容(PCM)相同**」為同一概念、不同檔案
  * 「有損 Opus Mp3 etc. -> 內容(PCM)**不相同**」概念分離、不同檔案
  
* **`Audio` Table**：用於描述一段聲音的各種 metadata，
系統會根據`quality_score`來選擇**master**，而**master** 的 `pcm_hash`會是其餘`quality_score`較差的`Audio.parent_hash`，同時也是`Track.pcm_hash`的內容。

* **`Aduio_Asset` Table**：用於**關聯一段聲音<->實際檔案**，而這正是為了「PCM 相同、檔案不同的 Wav& Flac」設計，使系統能夠同時保留兩者。通常情況(沒有兩個PCM相同的聲音)下是一對一的關聯，即**`Audio`<->`Asset`**。
  > PS：
  這是因為即使 Wav 與 Flac 的 PCM 相同，可能因為各種因素造成在盲聽測試上 Wav 的表現更佳。 
  （Marantz M-CR612 + DALI OBERON 1 + Optical Fiber + CD RIP *wav vs flac*）


## 8. 技術實作決策（v0.1）

### 8.1 Hash 計算

* 使用 `ffmpeg` CLI（允許 shell out）
* 不使用 libav* library

理由：

* 降低 build 複雜度
* 專注於系統行為而非編譯問題

---

### 8.2 Core Library

* 語言：C++
* 產物：`liblyra.so` / `lyra.dll`
* 對外介面：`extern "C"`

---

### 8.3 UI 溝通方式

* Flutter 透過 FFI 呼叫
* 不回傳 struct 陣列
* 回傳 JSON string 或 opaque handle


---

## 9. 未來添加的功能

* Pending_Actions
* 同步與備份
* 伺服器模式
* 串流播放(AirPlay、HEOS)
* 網路
* CRDT
* 智慧標籤
* 推薦
* 每個 uuid 之間的關聯圖，像是Obsidian（沒有太大作用，但觀察這個應該會很有趣）



---


> *願未來的你，能看懂現在的你在想什麼。*
