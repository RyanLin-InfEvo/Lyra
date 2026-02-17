# Lyra Design Document


---

## 0. 專案定位

Lyra 是一個為 「數位音樂資產的永恆性」 而設計的個人管理系統。

在串流媒體盛行與檔案易於更動的時代，Lyra 不僅僅是存放音樂的容器，它更是一座數位公證圖書館。它專門解決核心的信任問題：

    「當我十年後再次開啟這段音訊，我如何確信它依然是當初那份最純粹、未被任何軟體或傳輸過程竄改的原音？」

核心使命

  * 建立信任座標：透過「不可變性（Immutability）」設計，確保原始音訊物件一旦入庫，即成為不可撼動的歷史存證，不因軟體升級或標籤修改而產生變異。

  *  工程透明化：以解碼後的 PCM 內容作為唯一指紋（Content-Addressable），讓音樂的識別回歸聲音本質，而非脆弱的檔名或 Metadata。

  *  私有化主權：這是一個專為個人收藏家打造的長期維護系統，不依賴雲端演算法，只服從於資料庫中的唯一真實來源。

---

## 1. 核心哲學

### 1.1 專案定位：去中心化音樂資產管理系統 (Audio DAM)

Lyra 是一個為「數位音樂資產永恆性」設計的個人管理系統。與傳統播放器不同，Lyra 不以「檔案」為核心，而是以「聲學內容」與「音樂作品」為核心。它解決的是長期數位收藏中的信任與結構化問題。

### 1.2 設計哲學 (Design Philosophy)

* 內容定址 (Content-Addressable):
    系統只認得「聲音」。若兩個檔案（例如 .wav 與 .flac）解碼後的 PCM 波形一致，在 Lyra 的定義中它們就是同一個 Audio 實體。這確保了收藏的唯一性，避免重複儲存相同的聲音內容。

* 資料庫中心主義 (Database as Source of Truth):
    讀取：所有 UI 顯示的資訊（標題、演出者、封面）100% 來自 SQLite 資料庫。

    寫入：Lyra 嚴禁回寫 原始音訊檔案。我們視原始檔案為「唯讀的歷史文物」，任何修改（如更正曲名、替換封面）僅發生在資料庫層面。這確保了原始資產的純淨與可遷移性。

* 結構化分離 (Structural Decoupling):
    Lyra 將音樂資料嚴格分層，拒絕將 Metadata 直接寫入音訊檔案。

    * 作品 (Work) 與 錄音 (Track) 分離：區分「貝多芬第五號交響曲」(Work) 與「卡拉揚 1963 年指揮的版本」(Track)。

    * 內容 (Audio) 與 容器 (Asset) 分離：區分「實際聽到的聲音」(PCM) 與「硬碟上的檔案」(File)。

* 嚴格的不可變性 (Strict Immutability):
    一旦檔案被寫入儲存層 (/objects/)，即視為唯讀資料。
    系統不允許「原地修改」檔案內容。任何音質的修復或更動，都必須作為一個「新物件」被導入，而非覆蓋舊物件。

---

## 2. 結構化架構設計 (Structural Architecture)

### 2.1 基礎層級定義

#### **Level 1: Asset (物理容器)**
- **定義**: 負責檔案的 I/O、儲存與完整性校驗，硬碟上實際存在的位元組流 (Byte Stream)。
- **Idenity**: `file_hash` (SHA-256)。
- **特性**: 這裡是 Lossless (無損) 與 Lossy (有損) 的物理棲息地。
  - *例子*: `nocturne.flac`, `nocturne.mp3`。

#### **Level 2: Audio (聲學實體)**
- **定義**: 即「聲音本身」，解碼後的純音訊數據 (Raw PCM)。
- **Idenity**: `pcm_hash` (ffmpeg s32le decoded SHA-256)。
- **格式無關 (Format Agnostic)**。
  - 若擁有同一個錄音的 `.wav` 和 `.flac` ，且兩者解碼後 PCM 相同，Lyra 會在資料庫中建立 1 個 Audio 記錄，並關聯到 2 個 Asset。
  - 這允許系統同時保留「原始來源」與「節省空間的版本」，而在邏輯上視為同一首歌。

#### **Level 3: Track (錄音版本)**
- **定義**: 特定時間、地點、演出者所錄製的具體差異。
- **Idenity**: `UUID`。
- **職責**: 連結 Audio 與 Metadata (Title, Album, Year)。即在播放清單中看到的「一首歌」。
- **關鍵設計**: Track 指向一個 Audio。若未來使添加更高音質的檔案（但內容不同，例如 Remaster 版），這是更新 ` Track -> Audio` 的關聯，而不必刪除 Track 與 低音質的 Audio。

#### **Level 4: Work (抽象作品)**
- **定義**: 音樂作品本身，獨立於任何錄音。
- **Idenity**: `UUID`。
- **關鍵設計**: **尤其利好古典樂、翻唱與 Remix**。
  - 所有的「貝多芬第九號交響曲」錄音 (Tracks) 都指向同一個 Work。
  - 這讓使用者能查詢「這首歌有哪些版本？」，將 Library 的維度從「檔案列表」提升為「音樂資料庫」。

### 2.2 實作標準

為了支撐上述結構，Core 必須遵循嚴格的雜湊計算標準：

#### **Audio Hash Pipeline**
所有輸入檔案必須經過統一的正規化流程計算指紋：
`Input File -> Decoder-> S32LE PCM -> SHA-256`
這是 Lyra 能夠跨格式識別聲音的唯一依據。

#### **Immutability Contract**
寫入 `/objects/` 的檔案由 Asset 表管理。一旦寫入，**禁止修改內容**。若需修改 Tag 等任何資訊，則操作 DB；若需修改音訊（例如剪輯），則匯入為新 Asset。

    注意：Audio Hash 僅保證在相同解碼器版本與編譯參數下的一致性。Lyra 資料庫中將記錄計算該 Hash 時的 `ffmpeg_version` 以供未來稽核。


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


---

## 4.前後端交互分式

### v0.1 local MVP
目標：
* 暫時不考慮 Server
* 先完成 Core，用 Json 與外界交互

Core 功能：
* 計算 Hash
* 用 hash 值歸檔到 /objects
* 與外界使用 Json 交互
* 調用 yt-dlp 取得歌曲資訊、下載
* DB 的 MVP

## 4. API

### 4.1 實體通用操作

#### 📋 實體列表 (ListEntities)
*   **功能**: 列出、篩選、排序及分頁所有實體。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "ListEntities",
  "params":{
    "type":"Track",
    "filter":{
      "artist_id": "uuid_周杰倫",  //Artist周杰倫 的 UUID
      "album_id": "uuid_十一月的蕭邦",
      "work_id": "uuid",
      "playlist_id": "uuid",
      "tag_id": "uuid",
      "year": [2020, 2026], // 支援範圍
    },
    "sort": [
      { "field": "year", "order": "desc" },
      { "field": "album", "order": "asc" },
      { "field": "track", "order": "asc" }
    ],
    "limit": 50,
    "Offset": 0
  }
} 
```

```dart
// Flutter
class SortPresets {
  // Define static sorting strategy
  static const List<SortRule> byYearDesc = [
    SortRule(field: 'year', order: 'desc'),
    SortRule(field: 'album', order: 'asc'),  // Autocomplete logic
    SortRule(field: 'track', order: 'asc'),  // Autocomplete logic
  ];

  static const List<SortRule> byTitleAz = [
    SortRule(field: 'title', order: 'asc'),
    SortRule(field: 'artist', order: 'asc'),
  ];
}

// Call API
lyraApi.listEntities(
  type: 'Track',
  sort: SortPresets.byYearDesc // 傳送的是完整的陣列規則
);
```

*   **📨 Response**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "code": 200,
  "data": {
    "items": [
      { "id": "uuid_1", "display_title": "夜曲", "artist": "周杰倫", "album": "十一月的蕭邦", "duration": 215 },
      { "id": "uuid_2", "display_title": "一路向北", "artist": "周杰倫", "album": "十一月的蕭邦", "duration": 240 }
    ],
    "total_count": 145  // 讓前端知道總共有幾頁
  }
}
```

#### 📄 搜尋所有實體 (SearchEntity)
*   **功能**: 利用 SQLite FTS 實現「模糊查找」與「權重排序」。
*   **📥 Request**:
```json
{
  "command": "SearchEntity",
  "params": {
    "query": "周杰倫",
    "scopes": ["Track", "Artist", "Album"], // 或者只傳 ["Track"]
    "limit": 20,
    "offset": 0
  }
}
```
*   **📨 Response**:
```json
{
  "code": 200,
  "data": {
      "results": [
        {
          "entity_type": "Artist",
          "uuid": "uuid_jay_chou",
          "display_title": "周杰倫",
          "subtitle": "Artist", // 或 "Taiwanese Pop Singer"
          "match_score": 1.0,
          "metadata": { // 原始資料放在這裡，供點擊後詳情使用
              "spotify_id": "..."
          }
        },
        {
          "entity_type": "Track",
          "uuid": "uuid_ye_hui_mei",
          "display_title": "以父之名",
          "subtitle": "周杰倫 • 葉惠美", // Track 的 subtitle 通常顯示 Artist • Album
          "match_score": 0.95,
          "metadata": {
              "duration": 342
          }
        }
      ],
      "total_count": 150 // 供分頁計算使用
    }
}
```

#### 🔍 取得 Entity 詳細資訊 (GetEntity)
*   **功能**: 取得 Entity 詳細資訊，所有Image、Text、Work、Artist 等關聯資訊。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "GetEntity",
  "params": {
    "uuid": "entity_uuid"
  }
}
```
*   **📨 Response**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "code": 200,
  "data": {
    "uuid": "entity_uuid",
    "title": "Entity Title",
    "type": "Entity Type",
    "description": "Entity Description",
    "year": 2025,
    "images": [
      {
        "url": "https://example.com/image.jpg",
        "width": 100,
        "height": 100
      }
    ],
    "texts": [
      {
        "type": "description",
        "content": "Entity Description"
      }
    ],
    "works": [
      {
        "uuid": "work_uuid",
        "title": "Work Title"
      }
    ],
    "artists": [
      {
        "uuid": "artist_uuid",
        "title": "Artist Title"
      }
    ],
    "albums": [
      {
        "uuid": "album_uuid",
        "title": "Album Title"
      }
    ],
    "playlists": [
      {
        "uuid": "playlist_uuid",
        "title": "Playlist Title"
      }
    ]
  }
}
```

#### ✏️ 更新實體資訊 (UpdateEntity)
*   **功能**: 修改 Artist, Work, Album, Playlist 的 Title, Year, Description 等非外鍵欄位，支援多個 Entity 統一更新。

*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "UpdateEntity",
  "params": {
    "ids": ["entity_uuid1", "entity_uuid2"],
    "fields": {
      "title": "New Title",
      "year": 2025,
      "description": "Updated description"
    }
  }
}
```

#### 🗑️ 刪除實體 (DeleteEntity)
*   **功能**: 刪除 Entity。(未來實做 垃圾桶功能，先標記「已刪除」)
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "DeleteEntity",
  "params": {
    "uuid": "entity_uuid"
  }
}
```

#### 🔗 追加 Entity 圖片 (AddEntityImage)
*   **功能**: 更新 Entity 的圖片資產，管理Entity_Image。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "AddEntityImage",
  "params": {
    "uuid": "entity_uuid",
    "image_path": "~/Downloads/image.jpg", // local path, can be null
    "image_url": "https://example.com/image.jpg", // url, can be null
    "image_role": "front" // front, back, 
  }
}
```

#### 🔗 追加 Entity 文字 (AddEntityText)
*   **功能**: 更新 Entity 的文字資產，管理Entity_Text。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "AddEntityText",
  "params": {
    "uuid": "entity_uuid",
    "text_content": "~/Downloads/image.jpg", // local path, can be null
    "text_role": "description" // description, lyrics, tags
  }
}
```

---
### 4.2 Artist 操作

#### ✨ 建立 Artist (CreateArtist)
*   **功能**: 建立 Artist。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "CreateArtist",
  "params": {
    "name": "Artist Name",
    "description": "Artist Description"
  }
}
```

#### 🗑️ 刪除 Artist (DeleteArtist)
*   **功能**: 刪除 Artist。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "DeleteArtist",
  "params": {
    "uuid": "artist_uuid"
  }
}
```

#### 🔗 追加 Artist (AddTrackArtist)
*   **功能**: 處理 Track_Artist, Album_Artist, Work_Artist。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "AddTrackArtist",
  "params": {
    "target_type": "Track", // Track, Album, Work
    "target_uuid": "track_uuid_1",
    "artist_uuid": "artist_uuid_A",
    "role": "featured",
    "position": 1 // 選填，用於排序
  }
}
```

#### ⛓️‍💥 移除 Artist (RemoveTrackArtist)
*   **功能**: 處理 Track_Artist, Album_Artist, Work_Artist。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "RemoveTrackArtist",
  "params": {
    "target_type": "Track", // Track, Album, Work
    "target_uuid": "track_uuid_1",
    "artist_uuid": "artist_uuid_A"
  }
}
```

---
### 4.3 Work 操作

#### ✨建立 Work (CreateWork)
*   **功能**: 建立 Work。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "CreateWork",
  "params": {
    "name": "Work Name",
    "description": "Work Description"
  }
}
```

#### 🗑️ 刪除 Work (DeleteWork)
*   **功能**: 刪除 Work。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "DeleteWork",
  "params": {
    "uuid": "work_uuid"
  }
}
```

#### 📌 指派 Work (SetWork)
*   **功能**: 處理 Track_Work。
*   **📥 Request**:
```json
{
  "command": "SetWork",
  "params": {
    "track_uuid": "track_uuid_1",
    "work_uuid": "work_uuid_9" 
  }
}
```

---
### 4.3 Album 操作

#### ✨ 建立 Album (CreateAlbum)
*   **功能**: 建立 Album。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "CreateAlbum",
  "params": {
    "name": "Album Name",
    "description": "Album Description"
  }
}
```

#### 🗑️ 刪除 Album (DeleteAlbum)
*   **功能**: 刪除 Album。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "DeleteAlbum",
  "params": {
    "uuid": "album_uuid"
  }
}
```

#### 🔗 追加 Album (AddAlbum)
*   **功能**: 處理 Track_Album。
*   **📥 Request**:
```json
{
  "command": "AddAlbum",
  "params": {
    "track_uuid": "track_uuid_1",
    "album_uuid": "album_uuid_9" 
  }
}
```

#### ⛓️‍💥 移除 Album (RemoveAlbum)
*   **功能**: 處理 Track_Album。
*   **📥 Request**:
```json
{
  "command": "RemoveAlbum",
  "params": {
    "track_uuid": "track_uuid_1",
    "album_uuid": "album_uuid_9" 
  }
}
```

---
### 4.4 Tag 操作

#### ✨ 建立 Tag (CreateTag)
*   **功能**: 建立 Tag。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "CreateTag",
  "params": {
    "name": "J-Pop",
    "description": "Japanese Pop Music"
  }
}
```

#### 🗑️ 刪除 Tag (DeleteTag)
*   **功能**: 刪除 Tag。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "DeleteTag",
  "params": {
    "uuid": "tag_uuid"
  }
}
```

#### 🏷️ 新增 Tag (AddTag)
*   **功能**: 對 Entity 新增 Tag。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "AddTag",
  "params": {
    "entity_uuid": "track_uuid",
    "tags": [ "J-Pop", "Female Vocal" ]
  }
}
```

#### 🏷️ 移除 Tag (RemoveTag)
*   **功能**: 對 Entity 移除 Tag。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "RemoveTag",
  "params": {
    "entity_uuid": "track_uuid",
    "tags": [ "J-Pop", "Female Vocal" ]
  }
}
```
---
### 4.5 合併操作 (Merge)

#### ➡️ 預覽合併 (GetMergePreview)
*   **功能**: 預覽兩個重複的 Entity。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "GetMergePreview",
  "params": {
    "entity_type": "Artist", // Track, Album, Work
    "target_uuid": "entity_uuid_1",
    "source_uuid": "entity_uuid_2"
  }
}
```


*   **📨 Response** (Merge Artist Preview):
```json
{
  "code": 200,
  "data": {
    "can_merge": true, // 是否可以合併，類型不兼容、唯讀、合併同一個 UUID
    "preview": {
      // 1. Confilct：兩邊數據不同，二選一
      "conflicts": [
        {
          "key": "name",           // 後端欄位名
          "label": "Name",         // 前端顯示標題
          "target_value": "周杰倫",
          "source_value": "Jay Chou",
          "recommended": "target_value" // target_value, source_value, null
        },
        {
          "key": "spotify_id",
          "label": "Spotify ID",
          "target_value": "uuid_spotify_1",
          "source_value": "uuid_spotify_2"
        }
      ],
      // 2. Patch：Target 原本沒資料，將從 Source 繼承
      "patches": [
        {
          "key": "country",
          "label": "Country",
          "value": "Taiwan",
          "is_selected": true  // 預設勾選
        },
        {
          "key": "bio",
          "label": "Biography",
          "value": "Jay Chou is a...",
          "is_selected": true
        }
      ],
      // 3. Union：集合類型的欄位，例如 Tag、Image、Genre 等
      "unions": {
        "tags": [
          { 
            "id": "tag_uuid_1", 
            "label": "Pop", 
            "origin": "both",    // 兩邊都有
            "is_selected": true
          },
          { 
            "id": "tag_uuid_2", 
            "label": "R&B", 
            "origin": "source",  // 來自來源
            "is_selected": true
          },
          { 
            "id": "tag_uuid_3", 
            "label": "Mandopop", 
            "origin": "target",  // 來自目標
            "is_selected": true 
          }
        ],
        "images": [
           // 圖片也可以用一樣的邏輯，讓使用者挑選要保留哪些封面
           { "id": "img_hash_1", "url": "...", "origin": "source", "is_selected": true }
        ]
      },
      // 4. Impact：影響區
      // 這些是 Read-Only，告訴使用者：「這些孩子要換爸爸了」
      "impact": {
        "summary": "12 Albums and 45 Tracks will be moved from 'Jay Chou' to '周杰倫'.",
        "details": [
          {
            "type": "Album",
            "count": 12,
            "items": [ // 只列出前幾筆作為範例，避免 JSON 太大
              { "uuid": "album_uuid_1", "title": "葉惠美", "year": 2003 },
              { "uuid": "album_uuid_2", "title": "七里香", "year": 2004 }
            ]
          },
          {
            "type": "Track",
            "count": 45,
            "items": [
              { "uuid": "track_uuid_1", "title": "以父之名", "album": "葉惠美" },
              { "uuid": "track_uuid_2", "title": "晴天", "album": "葉惠美" }
            ]
          }
        ]
      }

    }
  }
}
```


*   **📨 Response** (Merge Track Preview):
```json
{
  "code": 200,
  "data": {
    "can_merge": true, // 是否可以合併，類型不兼容、唯讀、合併同一個 UUID
    "preview": {
      // 1. Confilct：兩邊數據不同，二選一
      "conflicts": [
        {
          "key": "title",           // 後端欄位名
          "label": "Title",         // 前端顯示標題
          "target_value": "Nocturne",
          "source_value": "夜曲",
          "recommended": "target_value" // target_value, source_value, null
        }
      ],
      // 2. Patch：Target 原本沒資料，將從 Source 繼承
      "patches": [
        {
          "key": "recording_month",
          "label": "Recording Month",
          "value": 12,
          "is_selected": true  // 預設勾選
        },
        {
          "key": "recording_year",
          "label": "Recording Year",
          "value": 2005,
          "is_selected": true
        }
      ],
      // 3. Union：集合類型的欄位，例如 Tag、Image、Genre 等
      "unions": {
        "tags": [
          { 
            "id": "tag_uuid_1", 
            "label": "Pop", 
            "origin": "both",    // 兩邊都有
            "is_selected": true
          }
        ],
        "images": [
           // 讓使用者挑選要保留哪些 Image
           { "id": "img_hash_1", "path": "/path/to/image.jpg", "origin": "source", "is_selected": true }
        ]
      },
      // 4. Impact：影響區
      // 這些是 Read-Only，告訴使用者：「這些孩子要換爸爸了」
      "impact": {
        "summary": "12 Albums and 45 Tracks will be moved from 'Jay Chou' to '周杰倫'.",
        "details": [
          {
            "type": "Audio",
            "count": 12,
            "items": [
              { "uuid": "pcm_hash_1", "duration": 120, "quality_score": 100 }
            ]
          }
        ]
      }

    }
  }
}
```
---
#### 🔀 合併 Artist (MergeArtist)
*   **功能**: 合併兩個重複的 Artist。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "MergeArtist",
  "params": {
    "target_uuid": "artist_uuid_1",
    "source_uuid": "artist_uuid_2",
    "conflicts": {  // 指定保留哪一個值
       "name": "周杰倫",    
       "spotify_id": "..."
    },
    
    "unions": {  // 選擇哪些保留
      "tags": [
        { 
          "id": "tag_uuid_1", 
          "is_selected": true
        },
        { 
          "id": "tag_uuid_2", 
          "is_selected": false
        }
      ],
      "images": [
          { "id": "img_hash_1", "path": "/path/to/image.jpg", "origin": "source", "is_selected": true }
      ]
    },
    "patches": [  // 選擇要不要新增
      {
        "key": "recording_month",
        "label": "Recording Month",
        "value": 12,
        "is_selected": true  // 預設勾選
      },
      {
        "key": "recording_year",
        "label": "Recording Year",
        "value": 2005,
        "is_selected": true
      }
    ]
  }
}
```



### 4.6 Playlist 操作

#### ✨ 新增 Playlist (CreatePlaylist)
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "CreatePlaylist",
  "params":{
    "title": "My Playlist",
    "description": "My Playlist Description"
  }
} 
``` 

#### ➕ 新增歌曲至 Playlist (AddPlaylistTrack)
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "AddPlaylistTrack",
  "params":{
    "playlist_uuid": "playlist_id",
    "track_uuids": [ "track_id_1", "track_id_2" ]
  }
} 
``` 

#### ➖ 從 Playlist 移除歌曲 (RemovePlaylistTrack)
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "RemovePlaylistTrack",
  "params":{
    "playlist_uuid": "playlist_id",
    "track_uuids": [ "track_id_1", "track_id_2" ]
  }
} 
```

#### 🔃 調整播放順序 (MovePlaylistTrack)
*   **功能**: 更新歌曲在 Playlist 中的順序 (Update `position` index)。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "MovePlaylistTrack",
  "params": {
    "move": {
      "track_uuid": "track_id_1",
      "before": "track_id_2" // 插在誰前面 (NULL 代表移到最後)
    }
  }
}
```

### 4.7 資料匯入 (Ingestion)

#### ☁️ 從 YTM 匯入 (ImportYTM)
*   **功能**: 解析 YouTube Music 網址 (Song/Playlist) 並下載。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "ImportYTM",
  "params":{
    "url": [
      "https://music.youtube.com/playlist?list=PL...", 
      "https://music.youtube.com/watch?v=..."
    ]
  },
  "cookies_path": "/path/to/cookies.txt" // 選填，用於會員限定內容
} 
```
*   **📨 Response**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "code": 202, // Accepted
  "data": {
    "task_id": "task_uuid_12345",
    "message": "YTM import task started."
  }
}
```

#### 📂 匯入檔案 (ImportFile)
*   **功能**: 匯入本地音訊檔案或資料夾，參考 Metadata。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "ImportFile",
  "params":{
    "path": "/home/ryan/Downloads/music.opus" //確保 Path 是 Core Process 可讀的絕對路徑
  }
} 
```
*   **📨 Response**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "code": 202,
  "data": {
    "task_id": "task_uuid_67890",
    "message": "File import task started."
  }
}
```

---

### 4.8 資源存取 (Resource Access)

未來增加品質篩選功能，例如：選擇 320k、wav 等

#### 🎵 獲取資源路徑 (GetResourcePath)
*   **功能**: 取得檔案實體路徑以便播放器 (mpv/vlc) 讀取。
*   **📥 Request**:

```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "GetResourcePath",
  "params":{
    "uuid": "track_uuid" 
  }
} 
``` 

*   **📨 Response** (Only valid in local mode.):
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "code": 200,
  "data": {
    "path": "/lyra/objects/ab/cd/abcd1234.flac",
    "mime_type": "audio/flac"
  }
}
```

---

### 4.9 任務管理 (Task Management)
用於追蹤長耗時操作（如匯入、備份、資料庫重整）的進度。
未來加入 task type : Import、Backup、Database Verify、 etc
#### 📋 任務狀態 (Task Status)
*   **`pending`**: 任務已接受，正在排隊等待執行。
*   **`running`**: 任務正在執行中。
*   **`completed`**: 任務已成功完成。
*   **`failed`**: 任務執行失敗。

#### 📊 查詢任務狀態 (GetTaskStatus)
*   **功能**: Client 定時輪詢 (Polling) 此接口以更新 UI 進度條。也可根據 progress 增加速度決定輪詢頻率，兩者成正比關係。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "GetTaskStatus",
  "params":{
    "task_id": "task_uuid_12345"
  }
} 
```
*   **📨 Response (進行中)**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "code": 200,
  "data": {
    "task_id": "task_uuid_12345",
    "state": "processing", // pending, processing, finished, failed, cancelled
    "progress": 45.5,      // 百分比 0.0 ~ 100.0
    "step_description": "Converting audio: Track 3/10 (Jay Chou - Nocturne)",
    "created_at": "2026-02-15T10:00:00Z",
    "result": null
  }
}
```
*   **📨 Response (已完成)**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "code": 200,
  "data": {
    "task_id": "task_uuid_12345",
    "state": "finished",
    "progress": 100.0,
    "step_description": "Done.",
    "result": {
        // 任務完成後的摘要報告
        "total_items": 10,
        "success_count": 10,
        "playlist_uuid": "playlist_new_uuid",
        "errors": [] 
    }
  }
}
```

#### 📋 列出所有任務 (ListTasks)
*   **功能**: 查看背景任務列表（例如顯示在「下載管理器」面板）。
*   **📥 Request**:
```json

{
  "protocol": "lyra-core",
  "version": 0,
  "command": "ListTasks",
  "params":{
    "states": ["processing", "pending", "failed", "finished", "partially_failed", "cancelled"] // 篩選條件，可選
  }
} 
```
*   **📨 Response** (Only valid in local mode.):
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "code": 200,
  "data": {
    "tasks": [
      {
        "task_id": "task_uuid_12345",
        "state": "processing",
        "progress": 45.5,
        "step_description": "Converting audio: Track 3/10 (Jay Chou - Nocturne)",
        "created_at": "2026-02-15T10:00:00Z",
        "result": null
      }
    ],
    "total_count": 1
  }
}
```

#### 🛑 取消任務 (CancelTask)
*   **功能**: 中斷正在進行的任務（如 yt-dlp 下載、轉檔）。
*   **📥 Request**:
```json

{
  "protocol": "lyra-core",
  "version": 0,
  "command": "CancelTask",
  "params":{
    "task_id": "task_uuid_12345"
  }
}
```
---
### 4.10 General Response

#### ✨ 實體創建 (Entity Created)
*   **適用於**：CreatePlaylist, CreateTag, CreateArtist, CreateAlbum, CreateWork, CreateTrack 
*   **功能**：回傳新創建實體的 UUID。

*   **📨 Response**:
```json
{
  "code": 201, // Created
  "data": {
    "uuid": "new_generated_uuid_123", // 剛生成的 ID
    "affected_rows": 1
  }
}
```

#### 🔗 關聯變更 (Relation Modified)
*   **適用於**：AddPlaylistTrack, AddTag, RemoveTag
*   **功能**：確認操作了多少筆資料（例如批次加了 10 首歌進清單）。
*   **📨 Response**:
```json
{
  "code": 200, // OK
  "data": {
    "success": true,
    "affected_rows": 10, // 告知前端實際上變更了幾筆 (例如用於顯示: "Added 10 tracks")
    "target_uuid": "playlist_uuid_abc" // 操作的目標主體 (Context)
  }
}
```

#### 🛠️ 實體更新 (Entity Updated)
*   **適用於**：UpdatePlaylist, UpdateTag, UpdateArtist, UpdateAlbum, UpdateWork, UpdateTrack 
*   **功能**：確認更新成功，回傳變更的欄位。
*   **📨 Response**:
```json
{
  "code": 200,
  "data": {
    "uuid": "entity_uuid_123",
    "updated_fields": ["title", "year"], // 讓前端知道哪些欄位被變更了 (可用於局部刷新)
    "affected_rows": 1
  }
}
```

---
### 4.11 ReportPlayback

#### 📊 報告播放 (Report Playback)
*   **功能**：回報播放的歌曲，用於統計播放次數。
    通常在超過一定時長的播放時間後會自動 report一次 `play_time` 並歸零 UI 計時器，
    或在切換下一首歌時 report `play_time`。
    在超過一定比例時 report `play_count`。
*   **📥 Request**:
```json
{
  "protocol": "lyra-core",
  "version": 0,
  "command": "ReportPlayback",
  "params": {
    "track_uuid": "track_uuid_123",
    "play_count": 1, // 播放次數
    "play_time": 120.5 // 播放時間 (second)
  }
}
```

---
### 4.12 General Error Response

#### 📛 一般錯誤 (General Error)
*   **功能**：當 code 不為 2xx 時，data 欄位為 null，並回傳 error 物件。
*   **📨 Response**:
```json
{
  "code": 404, // 400 bad request / 404 not found /409 conflict / 500 internal server error / etc.
  "error": {
      "type": "ConstraintViolation",
      "message": "Tag with name 'J-Pop' already exists.",
      "details": {
        "field": "name",
        "rejected_value": "J-Pop",
        "existing_uuid": "existing_tag_uuid_xyz" // 貼心地回傳已存在的 ID，讓 UI 提示「是否要直接使用現有標籤？」
      }
    }
}
```

## v0.2 GUI 的開始

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

## 6. DB Schema 設計

### Entity Layer
所有具備業務意義的物件（Artist, Work, Album, Playlist, Track）皆繼承自 `Entity` 表，與其共用 UUID 主鍵。
* **設計目的**：統一 ID 空間，方便圖片 (Entity_Images) 與文本 (Entity_Text) 等資源的掛載。

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
    'main',       -- 主藝人 (Primary Artist, 專輯列表上顯示的名字)
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
* **Idenity**：`file_hash` SHA256, BINARY(32) in DB。
* **儲存**：對應 `/objects/` 下的實體檔案。
* **`Asset.asset_type`**：`SUBSTRING_INDEX(mime_type, '/', 1)`

### Audio Layer
* **Idenity**：`pcm_hash`(ffmpeg decoded raw stream hash), BINARY(32) in DB。
* **設計目的**：
  * 「無損 Wav Flac -> **內容(PCM)相同**」為同一概念、不同檔案
  * 「有損 Opus Mp3 etc. -> 內容(PCM)**不相同**」概念分離、不同檔案
  
* **`Audio` Table**：用於描述一段聲音的各種 metadata，
系統會根據`quality_score`來選擇**master**，而**master** 的 `pcm_hash`會是其餘`quality_score`較差的`Audio.parent_hash`，同時也是`Track.pcm_hash`的內容。

* **`Aduio_Asset` Table**：用於**關聯一段聲音<->實際檔案**，而這正是為了「PCM 相同、檔案不同的 Wav& Flac」設計，使系統能夠同時保留兩者。通常情況(沒有兩個PCM相同的聲音)下是一對一的關聯，即 **`Audio`<->`Asset`**。
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


> *願未來的你，與Lyra一起，聽見更多。*
