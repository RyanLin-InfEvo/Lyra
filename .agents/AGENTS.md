<!--
SPDX-FileCopyrightText: 2026 Tzu-Ting Lin

SPDX-License-Identifier: AGPL-3.0-or-later
-->
# Lyra Technical Standards & Engineering Playbook (技術規範與操作手冊)

This document serves as the Single Source of Truth (SSOT) for all technical, engineering, testing, and implementation standards in the **Lyra** project. For high-level orchestration, interaction workflows, and agent delegation discipline, refer to [GEMINI.md](GEMINI.md).

---

## 🛠️ 1. Build and Compile Commands

All compilation and building must run within the Nix shell environment. Directly executing C++ build commands on the host will fail due to missing dependencies.

### Clean & Build Core Library and CLI
You can compile and build the project from the workspace root directory using the wrapper script:
```bash
./build.sh
```
*Note: Alternatively, you can run CMake configuration and compilation directly using the Nix-shell command: `nix-shell core/shell.nix --run "cd core && ./build.sh"`.*

### Flutter UI Commands (Desktop & Web)
All Flutter actions must be executed inside the Nix environment using the root wrapper script:
```bash
# Run Linux desktop application
./flutter.sh run -d linux

# Fetch dependencies & run static analysis
./flutter.sh pub get
./flutter.sh analyze
```
*Note: Alternatively, you can run Flutter commands directly via: `nix-shell ui/shell.nix --run "cd ui && flutter ..."`.*

---

## 🧪 2. Test Commands & TDD Workflow

Lyra implements a dual-layer test suite: C++ unit tests and Python integration tests (interacting with the C FFI), along with Flutter widget/unit tests for the UI.

### Run Python Integration Tests
You can run the full automated test suite from the workspace root directory using the wrapper script:
```bash
./test.sh
```
*Note: Alternatively, you can run tests directly via: `nix-shell core/shell.nix --run "python -m unittest discover -s core/tests"`.*

### Run a Specific Test Module
If you need to run a specific Python integration test module (e.g. `test_list_apis.py`):
```bash
nix-shell core/shell.nix --run "PYTHONPATH=core/tests python -m unittest core/tests/test_list_apis.py"
```

### Run Flutter Widget & Unit Tests
You can run the Flutter test suite from the workspace root directory using the wrapper script:
```bash
./flutter.sh test
```
*Note: Alternatively, you can run tests directly via: `nix-shell ui/shell.nix --run "cd ui && flutter test"`.*

### Test-Driven Development (TDD) Rule
*   Before finalizing any feature or bug fix, write corresponding test cases.
*   Low-level database or transaction depth validation should be added to C++ unit tests (e.g. `core/tests/database_context_test.cpp`).
*   Behavioral APIs should be validated via Python integration tests under `core/tests/`.
*   UI components and presentation logic should be validated via Flutter widget tests under `ui/test/`.

### Flutter UI Testing & Modular Design System Validation
*   **Widget & Contract Tests:** Test widgets against abstract facade contracts (e.g., `LyraButton`, `LyraCard`) and verify behavioral states (hover, focus, disabled, loading) across different themes.
*   **Design Token & Theme Validation:** Validate theme extensions and design tokens to ensure colors, paddings, and typography adapt correctly between dark/light modes and custom themes without hardcoded values.
*   **Layout Safety & Responsiveness Tests:** Run widget tests across multiple viewport constraints (e.g., mobile, tablet, desktop resolutions) to detect `RenderFlex` overflow errors early.
*   **Controller Leak Prevention:** Verify that stateful widgets properly clean up their controllers (`TextEditingController`, `ScrollController`, `AnimationController`) upon unmounting.
*   **Avoid Redundant Status Badges & AI Clutter (消除 AI 味標籤):** Do not add frivolous, redundant status capsules/badges to headers, toolbars, or table headers (such as "Bit-Perfect Engine", "CAS Validated", "AI Verified", or repetitive shortcut tags). Keep the UI clean, purposeful, and uncluttered like professional desktop applications.
*   **Platform-Neutral Search & Shortcuts:** Avoid hardcoding platform-specific shortcut strings (e.g. `⌘K` or `cmd + K`) into generic input placeholders.

### Testing Internal C++ Modules (Without C FFI)
For C++ modules and utility classes (such as [sha256.cpp](core/src/utils/sha256.cpp)) that do not have a public FFI/C-API:
1. **Do NOT pollute FFI**: Do not add FFI functions in [lyra_c_api.h](core/include/lyra_c_api.h) solely for testing.
2. **C++ Unit Test Binary**: Create a standalone C++ test file in `core/tests/` containing `int main()` (e.g. `core/tests/sha256_test.cpp`). Ensure it includes the class header, tests the functionality, and returns `0` on success or non-zero on failure.
3. **Register in CMake**: Register the test executable inside the `if(BUILD_TESTING)` block in [core/CMakeLists.txt](core/CMakeLists.txt):
   ```cmake
   add_executable(sha256_test tests/sha256_test.cpp)
   target_link_libraries(sha256_test PRIVATE lyra_core nlohmann_json::nlohmann_json fmt::fmt)
   target_include_directories(sha256_test PRIVATE include src)
   ```
4. **Python Test Wrapper**: Write a corresponding Python test file (e.g. `core/tests/test_sha256.py`) inheriting from `BaseLyraTestCase`. Use `subprocess.run(["./core/build/sha256_test"])` to run the test executable and assert that the return code is 0.

---

## 🔄 3. Standard Git & Development Workflow

To maintain repository hygiene and ensure clean code integration, all agents must follow these steps:

### A. Worktree Isolation
*   All code modifications must be performed in a dedicated Git worktree inside the `.worktrees/` directory of the workspace root (creating worktrees outside the workspace causes tool permission errors).
*   **Command:**
    ```bash
    git worktree add -b <branch-name> .worktrees/<branch-name>
    ```
*   *Note:* Orchestration rules, worktree lifecycles, and exceptions are governed by [GEMINI.md](GEMINI.md).

### B. CMake Source Registration
*   When adding any new `.cpp` file to `core/src/`, you **MUST** immediately register it in [core/CMakeLists.txt](core/CMakeLists.txt) under the `add_library(lyra_core ...)` target. Failure to do so will result in linker errors (`undefined symbols`) during test execution.

### C. C++ Code Formatting
*   Run `clang-format` (auto format) on edited C++ source files after completing edits.
*   You can run it directly on the host if `clang-format` is installed, or execute it via the Nix shell wrapper:
    ```bash
    nix-shell core/shell.nix --run "clang-format -i <file>"
    ```

### D. Dart & Flutter Code Formatting
*   Run `dart format` on edited Dart source files:
    ```bash
    ./flutter.sh format lib/ test/
    ```
    *or `nix-shell ui/shell.nix --run "cd ui && dart format ."`.*

### E. Commit Message Format & Working Tree Scope
*   **Commit Message Style:** Use the standard semantic commit format: `type(scope): description` (e.g., `feat(core): implement savepoint transaction model`).
*   **Comprehensive Working Tree Scope:** When drafting and proposing commit messages, the agent MUST inspect the **complete set of uncommitted modifications across the working tree** (`git status` / `git diff`), rather than only summarizing the delta from the most recent conversational turn.
*   *Note:* The atomic commit gating workflow, approval cadence, and manual commit pause points are governed by [GEMINI.md](GEMINI.md).

### F. Self-Correction & Subagent Review
*   Perform a security review (checking SQLite query injection, resource cleanup, thread safety).
*   Perform a data integrity & anti-bandaid review:
    *   Verify that query or relational lookups do NOT use symptom-level bandaid patches (e.g. `if (!found) push_back(...)`) to artificially satisfy assertions.
    *   Verify that broken references or dangling foreign keys are observable and properly self-healed (e.g. updating dangling references to `NULL`) or cleanly guarded.
    *   Verify adherence to established relationship topologies (e.g. Single-Level Star Topology for audio versioning).
*   Perform a UI architecture review (checking facade abstraction, design token usage, `RepaintBoundary` on shaders/blurs, controller lifecycle disposal, and presentation/core separation).
*   Invoke a subagent (e.g., `self` or `codebase_investigator`) to verify modifications against architectural constraints before presenting the final work.

---

## 📁 4. Project Structure Quick Reference

See [CONTEXT.md](CONTEXT.md) for a detailed breakdown of the system architecture and files.
