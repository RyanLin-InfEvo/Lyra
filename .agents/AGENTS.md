<!--
SPDX-FileCopyrightText: 2026 Tzu-Ting Lin

SPDX-License-Identifier: AGPL-3.0-or-later
-->
# Lyra Project Agent Guidelines & Workflow

This document defines the rules, development workflows, and standard procedures for agents working on the **Lyra** project.

---

## 🛠️ 1. Build and Compile Commands

All compilation and building must run within the Nix shell environment. Directly executing C++ build commands on the host will fail due to missing dependencies.

### Clean & Build Core Library and CLI
You can compile and build the project from the workspace root directory using the wrapper script:
```bash
./build.sh
```
*Note: Alternatively, you can run CMake configuration and compilation directly using the Nix-shell command: `nix-shell core/shell.nix --run "cd core && ./build.sh"`.*

---

## 🧪 2. Test Commands & TDD Workflow

Lyra implements a dual-layer test suite: C++ unit tests and Python integration tests (interacting with the C FFI).

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

### Test-Driven Development (TDD) Rule
*   Before finalizing any feature or bug fix, write corresponding test cases.
*   Low-level database or transaction depth validation should be added to C++ unit tests (e.g. `core/tests/database_context_test.cpp`).
*   Behavioral APIs should be validated via Python integration tests under `core/tests/`.

### Testing Internal C++ Modules (Without C FFI)
For C++ modules and utility classes (such as [sha256.cpp](file:///home/ryan/Documents/Lyra/core/src/utils/sha256.cpp)) that do not have a public FFI/C-API:
1. **Do NOT pollute FFI**: Do not add FFI functions in [lyra_c_api.h](file:///home/ryan/Documents/Lyra/core/include/lyra_c_api.h) solely for testing.
2. **C++ Unit Test Binary**: Create a standalone C++ test file in `core/tests/` containing `int main()` (e.g. `core/tests/sha256_test.cpp`). Ensure it includes the class header, tests the functionality, and returns `0` on success or non-zero on failure.
3. **Register in CMake**: Register the test executable inside the `if(BUILD_TESTING)` block in [core/CMakeLists.txt](file:///home/ryan/Documents/Lyra/core/CMakeLists.txt):
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
*   **NEVER** modify the codebase directly on the primary branch/workspace.
*   All changes must be done inside a dedicated Git Worktree located in the `.worktrees/` directory of the workspace.
*   **Command:**
    ```bash
    git worktree add -b <branch-name> .worktrees/<branch-name>
    ```

### B. CMake Source Registration
*   When adding any new `.cpp` file to `core/src/`, you **MUST** immediately register it in [core/CMakeLists.txt](file:///home/ryan/Documents/Lyra/core/CMakeLists.txt) under the `add_library(lyra_core ...)` target. Failure to do so will result in linker errors (`undefined symbols`) during test execution.

### C. C++ Code Formatting
*   Run `clang-format` (auto format) on edited C++ source files after completing edits.
*   You can run it directly on the host if `clang-format` is installed, or execute it via the Nix shell wrapper:
    ```bash
    nix-shell core/shell.nix --run "clang-format -i <file>"
    ```

### D. Atomic Commit & Commit Style
*   **Atomic Commits:** Break down tasks into small, logical increments. Pause and ask the user for review and commit after each logical unit is complete.
*   **Commit Message Format:** Use the standard semantic commit style: `type(scope): description` (e.g., `feat(core): implement savepoint transaction model`).
*   **Approval:** Always propose the draft commit message to the user and wait for explicit approval before proceeding.

### E. Self-Correction & Subagent Review
*   Perform a security review (checking SQLite query injection, resource cleanup, thread safety).
*   Invoke a subagent (e.g., `self` or `codebase_investigator`) to verify modifications against architectural constraints before presenting the final work.

---

## 📁 4. Project Structure Quick Reference

See [CONTEXT.md](file:///home/ryan/Documents/Lyra/CONTEXT.md) for a detailed breakdown of the system architecture and files.
