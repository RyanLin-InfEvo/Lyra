<!--
SPDX-FileCopyrightText: 2026 Tzu-Ting Lin

SPDX-License-Identifier: AGPL-3.0-or-later
-->
# Lyra Project Context & Architecture Guide

Welcome to the **Lyra** project. This document provides a comprehensive technical overview of the system architecture, design decisions, core engineering patterns, and database schemas. It serves as the primary context for AI agents and developers to understand and maintain the codebase.

---

## 🎯 1. Core System Philosophy

Lyra is a personal, offline-first music asset management system built for long-term auditability, reproducibility, and data integrity.

*   **Content over Container:** Audio assets are identified by the cryptographic hash of their decoded raw audio stream (PCM), not by filenames, container tags, or directory structures.
*   **Content-Addressable Storage (CAS):** Audio files are stored under `/objects/[first-2-chars]/[next-2-chars]/[full-hash].[ext]`. Opaque filenames derived from hashes guarantee single-instance storage and zero duplication.
*   **Database as the Source of Truth:** Imported metadata is stored strictly in the database. Lyra **never** writes tags back into original audio files, preserving file hashes and preventing file pollution.
*   **Immutability:** Once written to the objects directory, audio objects are read-only. Updates are performed by writing new objects.

---

## 🏗️ 2. Core Architectural Components & Layering

The codebase is strictly separated into three layers to isolate business logic from presentation:

```
Lyra/
├── .agents/                 # Workspace customizations & technical standards (AGENTS.md)
├── .worktrees/              # Isolated feature branch worktrees
├── docs/                    # Design documentation, ADRs, API specs & SQL schema diagrams
│   ├── README.md                  # Documentation hub & index
│   ├── 00_overview/               # System overview & core philosophy
│   │   └── Lyra_Design_Document.md
│   ├── adr/                       # Architecture Decision Records (ADRs)
│   ├── api/                       # Core FFI JSON API reference (core_api_reference.md)
│   ├── database/                  # SQLite/MySQL schema definitions & diagrams
│   ├── features/                  # Feature specifications & implementation plans
│   ├── guidelines/                # Refactoring lessons & engineering guides
│   └── archive/drafts/            # Historical drafts & AI-summarized overview
│       └── Lyra_Design_Document_AI.md
├── core/                    # Core C++ Backend & Tests
│   ├── include/             # Stable public interface (C API)
│   │   └── lyra_c_api.h
│   ├── src/                 # Backend implementations
│   │   ├── cli/             # CLI entry point, command parser & interactive REPL
│   │   ├── controllers/     # Controller layer (routes JSON inputs, executes use cases)
│   │   ├── models/          # Plain-Old-Data (POD) domain structures
│   │   ├── services/        # SQLite connection context & transaction manager
│   │   │   └── repositories/# Repository layer (SQLite Data Access Objects)
│   │   ├── utils/           # Utilities: JSON validation, SHA-256, UUIDs
│   │   └── router.cpp       # JSON command dispatcher & central router
│   └── tests/               # C++ unit tests & Python integration tests
├── ui/                      # Flutter Desktop & Mobile UI
│   ├── lib/                 # Modular design system, themes, semantic tokens, views & FFI bridge
│   └── test/                # Flutter widget, contract & responsive layout test suite
├── build.sh                 # Root-level C++ build helper script (Nix-shell wrapper)
├── test.sh                  # Root-level C++/Python test helper script (Nix-shell wrapper)
├── flutter.sh               # Root-level Flutter UI helper script (Nix-shell wrapper)
├── GEMINI.md                # Interaction & orchestrator meta-rules
└── README.md                # System build and setup documentation
```

### Components Summary
1.  **Flutter Presentation Layer (`ui/`):** Cross-platform desktop and mobile interface built with a modular design system (facade contracts, semantic design tokens, dark/light themes, and Apple HIG alignment) communicating with the core engine via Dart FFI.
2.  **FFI C Boundary ([lyra_c_api.h](file:///home/ryan/Documents/Lyra/core/include/lyra_c_api.h)):** Exposes stable `extern "C"` functions. Inputs/outputs are exchanged as raw JSON strings to minimize ABI mismatches and memory leak risks across languages (C++ to Python/Rust/Flutter).
3.  **Central Dispatcher ([router.cpp](file:///home/ryan/Documents/Lyra/core/src/router.cpp)):** Dispatches all FFI requests to corresponding Controller methods based on the JSON `action` field.
4.  **Controllers (`core/src/controllers/`):** Translate JSON payloads, handle business flow, validate inputs using `json_validator`, and communicate with Repositories.
5.  **Repositories (`core/src/services/repositories/`):** SQLite database access logic (DAOs) using the `SQLiteCpp` library wrapper.
6.  **Database Context (`core/src/services/database_context.cpp`):** Manages connection lifetime, WAL mode, and thread-local nested transactions.

---

## 💾 3. Database Schema & Relations (v0.1 MVP)

Lyra uses SQLite for metadata persistence. All access is handled via repositories.
The database schema consists of the following primary tables:

*   **Entity:** Base table mapping UUIDs to entity types. Provides polymorphism/single-inheritance structure (e.g. Artist, Album, Track inherit from Entity).
*   **Artist:** Stores artist details (`id`, `name`, etc.).
*   **Album:** Stores album details (`id`, `title`, etc.).
*   **Track:** Represents the logical track entity (`id`, `title`, `duration`, `master_track_id`, etc.), referencing its primary file hash. Audio versioning follows a **Single-Level Star Topology** where derived versions point directly to the root track via `master_track_id` (preventing multi-hop chains).
*   **Asset / Audio:** Represents physical audio files stored in CAS, mapping container file hashes and decoded audio stream hashes (`pcm_hash`) to paths, size, formats, and channels for content-addressable audio deduplication.
*   **Playlist:** Groups tracks ordered by index.
*   **Relation / Junction Tables:** Maps relationships (e.g., Track-Artist, Album-Track, etc.).

---

## 🛠️ 4. Key Engineering & Design Patterns

### A. JSON-Based FFI Communication
To call the backend, external layers (like the CLI or UI) invoke:
```cpp
const char* lyra_execute_command(const char* json_request);
```
*   **Format:** The input is a JSON string of format `{"action": "ActionName", "params": {...}}`.
*   **Response:** Returns a heap-allocated JSON string response.
*   **Memory Management:** The caller must free returned strings by calling `lyra_free_string(const char* str)` to prevent memory leaks.

### B. SQLite WAL Mode & Connection Pool
*   **WAL Mode:** SQLite is initialized with `PRAGMA journal_mode=WAL` to allow simultaneous readers and one writer.
*   **Thread Safety:** The database context (`SqliteDatabaseContext`) maintains thread-local database connections to prevent multi-threaded lock crashes.

### C. Nested Transactions using `SAVEPOINT`s
*   To allow services to start nested transactions without locks or SQLite conflicts, the transaction manager tracks transaction depth `tl_depth` per thread-local connection.
*   **Depth = 0:** Starts a physical SQLite transaction (`BEGIN TRANSACTION`).
*   **Depth > 0:** Starts an SQLite SAVEPOINT (e.g., `SAVEPOINT sp_[depth]`).
*   **Rollback:** Rolling back at `depth > 0` runs `ROLLBACK TO SAVEPOINT sp_[depth]`, reverting only the nested modifications. Committing runs `RELEASE SAVEPOINT sp_[depth]`.

### D. Single Dispatch & Interactive REPL
The core CLI (`lyra-cli`) supports two interfaces:
1.  **Command-Line Execution:** Translates shell arguments into a JSON payload and dispatches it directly to `lyra_execute_command`.
2.  **Interactive REPL:** Executed via `lyra-cli interactive`. It opens a prompt loop allowing developers to query or command the system using raw JSON requests in real time.

---

## 📖 5. Design Documentation & Reference

*   **[Lyra_Design_Document.md](file:///home/ryan/Documents/Lyra/docs/00_overview/Lyra_Design_Document.md)**: The original, comprehensive, and highly detailed design draft. It contains detailed philosophy discussions, early implementation ideas, and complete background details of the Lyra asset management model. Agents should refer to this file when looking for deep context on original design intents.
*   **[core_api_reference.md](file:///home/ryan/Documents/Lyra/docs/api/core_api_reference.md)**: The authoritative reference for Core FFI JSON actions, request parameters, response payloads, and semantic error codes.
*   **[Lyra_Design_Document_AI.md](file:///home/ryan/Documents/Lyra/docs/archive/drafts/Lyra_Design_Document_AI.md)**: A condensed, AI-oriented summary of core design decisions and database columns.
