<!--
SPDX-FileCopyrightText: 2026 Tzu-Ting Lin

SPDX-License-Identifier: AGPL-3.0-or-later
-->
# 1. 遷移至基於 Repository 依賴注入與 Router 跨實體協調機制 (Repository DI & Router-Centric Orchestration)

* **狀態 (Status)**：已接受 (Accepted / 補錄 2026-05 決策)
* **日期 (Date)**：2026-05 (於 2026-08 補錄)
* **決策者 (Deciders)**：Tzu-Ting Lin (@RyanLin-InfEvo)

---

## 背景與問題脈絡 (Context)

在專案初期，Lyra 核心層依賴一個名為 `DatabaseManager` 的全域靜態類別：
1. **並行效能瓶頸**：`DatabaseManager` 內部透過全域 `std::recursive_mutex` 序列化所有資料庫讀寫操作。在具備 16 核心的硬體環境下，即使啟用 SQLite WAL 模式，依然無法發揮多連線並行讀取的優勢。
2. **緊密耦合與難以測試**：各個 Controller（如 `AlbumController`、`TrackController`）直接呼叫全域靜態方法並在內部撰寫原生 SQL。撰寫單元測試時必須強制啟動實體資料庫檔案，無法對業務邏輯進行輕量隔離測試。
3. **錯誤處理不一致**：早期依賴 C++ 異常（Exceptions），導致跨 C FFI / JSON 邊界時難以進行窮舉式錯誤碼映射與安全保護。

為了提升並行效能、消除全域鎖並達到可依賴注入（Dependency Injection, DI）的可測試架構，需要進行徹底重構。

---

## 決策內容 (Decision)

1. **廢棄 `DatabaseManager`，引入工作單元與連線池 (`IDatabaseContext`)**：
   - 建立 `IDatabaseContext` 與 `SqliteDatabaseContext`，透過 `thread_local` 智慧連線池支援多執行緒並行讀取。
   - 透過 `begin_transaction()` 返回 RAII 管理的 `unique_ptr<ITransaction>`（支援巢狀 Savepoint 與最外層 Commit 時的非阻塞 `PASSIVE` Checkpoint）。

2. **建立單一實體 Repository 介面 (Repository Pattern)**：
   - 定義 `IAlbumRepository`、`ITrackRepository`、`IArtistRepository`、`IAssetRepository`、`IImageRepository` 等純虛擬介面。
   - 所有 Repository 實作類別均透過建構子注入 `IDatabaseContext&`。

3. **Controller 貧血化與單一相依性**：
   - 將各 Controller 改造為僅相依於對應的單一 Repository 介面（例如 `explicit AlbumController(IAlbumRepository &repo)`）。
   - Controller 內部不持有 `IDatabaseContext`，亦不跨表格相依其他 Controller。
   - 錯誤處理全數遷移至 `tl::expected<T, std::string>`。

4. **將跨實體交易與複合工作遷移至 `Router`**：
   - 由於各 Controller 僅被允許相依單一 Repository 且無法開啟 Transaction，複合業務流程（如 `ImportTrack` 需要同時調度音訊資產、去重演出者、去重專輯、新增音軌、建立多對多關聯、擷取並綁定封面）無法由單一 Controller 獨立完成。
   - 為了避免 Controller 之間產生網狀或循環依賴，複合業務協調邏輯、交易邊界（`m_db_context->begin_transaction()`）與階層降級查詢（如音軌/演出者封面回退查詢）全數收攏至 `Router`（`core/src/router.cpp`）由 `Router` 統一協調。

---

## 結果與權衡 (Consequences)

### 正向效益 (Positive Consequences)
* **並行讀取效能飛躍**：消除了全域互斥鎖，充分發揮 SQLite WAL 模式下多執行緒獨立連線的平行讀取能力。
* **可測試性提升**：所有 Repository 與單一 Controller 可透過 Mock / Fake Repository 進行獨立單元測試。
* **交易完整性**：透過 `IDatabaseContext` 統一管理 Savepoint 與事務回滾，避免跨表寫入失敗時產生孤立資料。
* **強型別與明確錯誤**：淘汰 C++ 異常，全面採用 `tl::expected`，編譯期保證錯誤路徑無遺漏。

### 負向影響與技術債 (Negative Consequences / Technical Debt)
* **Controller 淪為淺模組 (Anemic Shallow Controllers)**：
  除了 `create()` 產生 UUID 外，多數 Controller 僅有 1 行轉發代碼，介面複雜度等同於實作複雜度，未實質封裝複雜性。
* **Router 上帝物件化 (Router God Object)**：
  `Router` 承載了 1,500+ 行程式碼，同時身兼協定路由（Protocol Router）、JSON 驗證、跨實體交易協調者（ImportTrack）、音訊引擎控制器，甚至直接執行原生 SQL 查詢以處理封面降級，違反了單一職責原則（SRP）。

---

## 未來演進方向 (Future Evolution)

本決策為重構初期的過渡狀態。未來的架構深化方向應為：
* **提取領域服務層 (Domain / Application Services Layer)**：
  建立如 `IngestionService`、`CoverArtService` 等高內聚的深模組（Deep Modules），將 `Router` 中的跨實體交易與業務編排下沉至服務層。
* **讓 Router 回歸純粹的協定配接器 (Protocol Adapter)**：
  `Router` 僅專注於 JSON Schema 解析、DTO 轉換與錯誤碼轉換。
