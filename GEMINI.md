<!--
SPDX-FileCopyrightText: 2026 Tzu-Ting Lin

SPDX-License-Identifier: AGPL-3.0-or-later
-->
# User Interaction Habits & Agent Guidelines

## 1. Interaction Workflow & Methodology
*   **Atomic Commit Principle:** The agent must pause after logical units of work to allow for user review and manual `git commit` before proceeding.
*   **Worktree Isolation:** All code modifications MUST be performed in a separate Git Worktree (e.g., using `git worktree add`). The agent should not modify the primary workspace directly. The user will perform the final merge after review.
*   **Worktree Location:** The worktree MUST be created **inside** the primary workspace directory (e.g., `.worktrees/<type>-<name>`, `.worktrees/<feat>-<>`) rather than outside it (e.g., `../Lyra-<name>`). Creating worktrees outside the workspace causes tool permission failures because the agent's file-system access is scoped to the workspace root.
*   **Test-Driven Development (TDD):** Verification is mandatory. Automated unit tests must be written and executed (e.g., Python `unittest` for C++ components) before finalizing changes.
*   **Inquiry before Action:** For complex tasks (e.g., security audits or architectural changes), provide a comprehensive report or plan first. Wait for a directive before implementation.
*   **Surgical Feedback:** Address user feedback on specific code selections precisely using the provided context.
*   **Proactive Subagent Delegation (Orchestrator Mode):** The primary session should act primarily as a coordinator, orchestrator, and reporter to the user. All actual implementation, codebase exploration, or code modification tasks MUST be delegated to sub-agents (e.g., `self` or specialized agents). The primary session will only synthesize and report the final results to the user, ensuring the primary context window remains clean and focused.
*   **Security & Efficiency Automation:** The project-level `.gemini/settings.json` enables `security.enableConseca` for context-aware security checking. Low-risk operations (e.g., `git worktree add`, `ls`, `git status`) are pre-authorized in `tools.allowed` to streamline the development loop.

## 2. Post-Implementation Quality Assurance
*   **Self-Correction Phase:** After completing any modification, the agent MUST proactively check for:
    *   Security vulnerabilities (e.g., credential leaks, unsafe memory usage, input validation).
    *   Violations of project-specific best practices.
    *   Unreasonable design patterns or API usage.
*   **Subagent Final Review:** Once potential issues are resolved (or if none are found), the agent MUST invoke a subagent (e.g., `codebase_investigator` or `generalist`) to perform a "final confirmation" (會後確認) to ensure overall system integrity and adherence to standards.

## 3. Coding & Engineering Standards
*   **Pattern Adherence:** Rigorously analyze and replicate established implementation patterns, naming conventions (e.g., snake_case for members, CamelCase for classes), and architectural structures found in the codebase. Use standard libraries (e.g., `nlohmann/json`, `std::optional`) as the primary toolset whenever they are established as the idiomatic choice in existing modules.
*   **CMake Source Registration:** When adding any new `.cpp` source file, the agent MUST immediately update `core/CMakeLists.txt` to include it in the `add_library` target. Forgetting this step causes `undefined symbol` linker errors that only surface at test time.
*   **Security & Data Integrity:** Maintain strict server-side authority as a non-negotiable standard. Critical identifiers (e.g., UUIDs) must be generated on the server to prevent collision or injection, and all client-provided data must be treated as untrusted and validated against server-side business logic.
*   **Hardware Optimization:** Account for high-performance hardware (e.g., 64GB RAM) in system and environment configurations.
*   **Performance & Platform Trade-offs:** When encountering potential performance bottlenecks or architectural choices that differ between Mobile, PC, or Server environments, the agent MUST proactively initiate a discussion with the user about these trade-offs before implementing a solution.

## 4. Git & Commit Habits
*   **Commit Message Style:**
    *   Follow `type(scope): message` format based on repository history. (e.g., fix(core), chore(docs), feat(core))
    *   Prefer concise, one-line messages, but include a descriptive body if it helps clarify the rationale, design decisions, or complex modifications.
    *   Always propose a draft message and wait for approval before execution.
*   **Repository Hygiene:** Proactively maintain `.gitignore`, remove build artifacts, and ensure no large binary or sensitive files are tracked.

## 5. Environment & Context
*   **Nix/NixOS Proficiency:** The agent must be comfortable working with `nix-shell`, `flake.nix`, and NixOS-specific configurations.
*   **Mandatory nix-shell Wrapper:** All build and test commands (e.g., `cmake`, `python -m unittest`) MUST be executed inside the Nix environment. You should prioritize using the root-level `./build.sh` and `./test.sh` scripts for convenience, or execute them through the wrapper: `nix-shell core/shell.nix --run "..."`. Direct host-level execution will fail due to missing dependencies.
