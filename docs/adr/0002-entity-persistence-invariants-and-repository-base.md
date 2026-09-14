<!--
SPDX-FileCopyrightText: 2026 Tzu-Ting Lin

SPDX-License-Identifier: AGPL-3.0-or-later
-->
# 2. 實體持久化不變量封裝與 Repository 泛型基礎類別 (Entity Persistence Invariants & Repository Base)

* **狀態 (Status)**：已接受 (Accepted)
* **日期 (Date)**：2026-09
* **決策者 (Deciders)**：Tzu-Ting Lin (@RyanLin-InfEvo), Antigravity AI Pair

---

## 背景與問題脈絡 (Context)

Lyra 的資料庫架構採用多型雙表關聯結構（Polymorphic Double-Table Schema）：所有核心領域物件（如 `Album`、`Artist`、`Track`、`Work`、`Playlist` 等）均由通用基表 `Entity`（定義全域唯一 UUID `id`、`entity_type`、`created_at`、`updated_at`）以及具體領域表（如 `Album`、`Artist` 等，以 `id` 作為主鍵並外鍵參照 `Entity.id`）共同組成。

在 Phase 1 重構前，各個具體 Repository（如 `SqliteAlbumRepository`、`SqliteArtistRepository`）存在嚴重的重複樣板代碼（Boilerplate Code）與底層隱患：

1. **重複的雙表交易與持久化邏輯**：
   - 每個 Repository 的 `insert()` 均需手動開啟交易，先插入 `Entity` 表，再插入具體實體表。
   - 每個 Repository 的 `update()` 均需重複實作動態 SQL 字串拼接（`UPDATE ... SET field1 = ?, field2 = ? WHERE id = ?`），並在成功後手動執行 `UPDATE Entity SET updated_at = datetime('now') WHERE id = ?`。
   - 分頁與模糊搜尋（`list(offset, limit, search)`）在各表重複撰寫相似的 `COUNT(*)`、`LIMIT ? OFFSET ?` 與 LIKE 跳脫邏輯。
2. **`IDatabaseContext::get_db()` 洩漏**：
   - 各 Repository 子類別直接呼叫 `get_db()` 穿透存取原生 SQLite 連線，使交易邊界與持久化不變量無法集中管控。
3. **架構審查與安全漏洞發現 (Review Findings)**：
   - **WHERE 子句安全缺失（全表覆寫風險）**：在動態更新組裝中，若未嚴格校驗或強制指定 WHERE 條件，任何誤用可能產生缺少 WHERE 的 `UPDATE <table> SET ...`，造成全表覆寫的毀滅性災難。
   - **懸垂指標與暫時物件生命週期問題 (Dangling Pointer in Lambda Closures)**：若在動態參數綁定的 lambda closure 中以傳址方式（by-reference）捕捉暫時物件（如暫存字串或臨時 DTO 欄位），在延遲綁定執行時會引發未定義行為（Undefined Behavior）。
   - **SQL 識別碼注入與關鍵字衝突 (Identifier Escaping)**：SQL 語句直接拼接欄位或資料表名稱，遇到 SQL 保留關鍵字（如 `order`, `group`）或未跳脫名稱時可能引發語法錯誤甚至潛在注入風險。
   - **`with_transaction` 對 `std::optional` 的誤判回滾**：原先的交易輔助方法未精確區分 `tl::expected` 與 `std::optional`，導致回傳型別為 `std::optional` 且值為 `std::nullopt` 時（例如查詢未命中，屬正常業務結果）被誤判為失敗而觸發非預期的交易回滾。

---

## 決策內容 (Decision)

針對上述問題，決定實施架構重構並建立以下五大核心持久化機制：

1. **`SqliteEntityRepository<TEntity, TUpdate>` 泛型基礎類別 (Generic Base Repository)**：
   - 定義 generic template 基礎類別，封裝所有 Entity 的核心持久化不變量。
   - **雙表原子交易**：`insert()` 統一由基類透過 `with_transaction` 處理 `Entity` 與具體表的原子寫入，具體表寫入透過虛擬方法 `do_insert(SQLite::Database&, const TEntity&)` 由子類實現。
   - **動態更新不變量**：`update()` 統一委派給 `SqliteUpdateBuilder`，並確保空更新（empty update）遵循不變量：先確認實體 ID 是否存在（不存在則返回 ID not found 錯誤，存在則成功返回 no-op）。
   - **標準化查詢與搜尋分頁**：統一提供安全的 `get(id)`、`list(offset, limit, search)`（內建 ANSI 引號跳脫、`SqliteHelper::escape_like` 與雙重排序保證），以及型別安全的 `get_by_field` 與 `get_one_by_field`。
   - **子類極度瘦身**：子類（如 `SqliteAlbumRepository`）僅需提供 DTO 對應的 `do_insert` 與 `build_update`，其餘樣板全數由基類消除。

2. **`SqliteUpdateBuilder` 安全動態更新建構器 (Safe Dynamic Update Builder)**：
   - **嚴格守衛 WHERE 子句**：在 `execute()` 時強制檢查 `m_where_clause`，若無 WHERE 子句則嚴格拒絕執行並回傳安全錯誤（`Safety Error: Refusing to execute UPDATE without a WHERE clause.`），徹底杜絕全表更新。
   - **值拷貝閉包 (Owning Value Copies in Lambdas)**：針對字串與一般型別在 lambda 內部採用值拷貝（owning copy, 例如 `[v = std::string(*val)]`），徹底消除暫時物件生命週期結束後的懸垂指標（Dangling Pointer）風險。
   - **C++20 Concepts 解決多載歧義**：透過 `requires(!detail::is_optional_v<std::decay_t<T>>)` 精確區分 `std::optional<T>` 與一般型別 `T` 的 `set` 多載。
   - **識別碼安全引用**：所有 SET 欄位與 WHERE 欄位均自動透過 `SqliteHelper::quote_identifier` 進行 ANSI 雙引號跳脫。

3. **集中化 `SqliteHelper::quote_identifier` (Centralized ANSI Identifier Escaping)**：
   - 在 `SqliteHelper` 中實作標準 ANSI SQL 雙引號跳脫（將任何引號自身重複為 `""`，如 `"Album"`），防止欄位名稱碰撞 SQL 保留關鍵字，提供全系統共用的安全防禦基準。

4. **資料庫觸發器 (`AFTER UPDATE` Triggers) 縱深防禦**：
   - 在 `SqliteDatabaseContext::init_schema()` 中為具體實體表（`Album`, `Artist`, `Track`, `Work`, `Playlist`）建立 SQLite `AFTER UPDATE` 觸發器：
     ```sql
     CREATE TRIGGER IF NOT EXISTS trg_<table>_updated_at
     AFTER UPDATE ON <table>
     BEGIN
       UPDATE Entity SET updated_at = datetime('now') WHERE id = NEW.id;
     END;
     ```
   - 提供架構層的雙重縱深防禦（Defense-in-Depth）：即使在未來繞過 Repository 直接進行底層 SQL 批次更新，`Entity.updated_at` 依然保證被即時刷新。

5. **`IDatabaseContext::with_transaction` 精確型別萃取 (`is_expected_v`)**：
   - 引入 `detail::is_expected_type` 特化與 `is_expected_v` 變數模板，嚴格僅對 `tl::expected<T, E>` 進行 `result.has_value()` 驗證以決定是否 commit。
   - 對於 `void` 或一般型別（包含 `std::optional`）只要無異常擲出即提交事務，避免空值引發非預期 Rollback。

---

## 結果與權衡 (Consequences)

### 正向效益 (Positive Consequences)

* **程式碼大幅簡化 (>70% LOC Reduction)**：
  `SqliteAlbumRepository` 與 `SqliteArtistRepository` 移除大量重複的原生 SQL 與交易樣板，代碼規模縮減超過 70%（由原先約 170~180 行縮減至約 50 行），後續擴充實體表（如 `Work`、`Playlist`）只需極少量宣告代碼。
* **持久化不變量單一事實來源 (Single Source of Truth, SSOT)**：
  雙表一致性、`Entity.updated_at` 時間戳更新、分頁計數與 LIKE 跳脫集中於 `SqliteEntityRepository` 與資料庫 Trigger，不再因人而異或遺漏。
* **強韌的安全性與防禦保證**：
  - `SqliteUpdateBuilder` 強制防禦缺少 WHERE 的更新。
  - ANSI 引號跳脫防範 SQL 識別碼注入與關鍵字衝突。
  - Lambda 值拷貝徹底消除指標懸垂危險。
* **完整的測試覆蓋 (High Test Confidence)**：
  針對 `SqliteUpdateBuilder` 安全守衛、暫時字串生命週期、空更新不變量、雙表原子回滾及 Trigger 自動更新均建立了高覆蓋率的自動化單元與整合測試。

### 負向影響與權衡考量 (Trade-offs / Considerations)

* **C++ 模板基類的複雜度**：
  `SqliteEntityRepository` 為 Header-only 泛型模板類別，在提供高度可重用性的同時，稍增加了標頭相依性與編譯耗時。
* **SQLite 觸發器之維護成本**：
  資料庫 Trigger 具有隱含執行（Implicit side-effect）特性，須確保在資料庫初始化腳本、遷移工具及測試案例中持續同步維護與驗證。
