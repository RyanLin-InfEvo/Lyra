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
  3. 固定輸出格式（例如 `s16le` 或 `f32le`）
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
``` 
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
``` 
  {
    "protocol": "lyra-core",
    "version": 0,
    "command": "FindDB",
    "params":{
      "text":[ "会开花的云","周深深" ],
      "Search_DB":{
        "Track":[ "uuid" ]
      },
      "Return_DB":{
        "Track":[ "title","uuid","artist","cover","year" ]
      },
      "Sort":{ "Track":{ "title":"asc" } },
      "Limit":10
    }
  } 
``` 

* 列出 `Work、Track、File、Source`內項目，Json Request 範例：
``` 
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
``` 
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
``` 
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
``` 
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
``` 
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
``` 
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "AddTrackToPlaylist",
  "params":{
    "playlist_uuid":[ "playlist_id", "playlist_id", "playlist_id" ],
    "track_uuid": "track_id"
  }
} 
``` 
``` 
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

## 6. 資產結構(DB)




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
