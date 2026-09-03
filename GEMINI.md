<!--
SPDX-FileCopyrightText: 2026 Tzu-Ting Lin

SPDX-License-Identifier: AGPL-3.0-or-later
-->
# Interaction & Orchestrator Meta-Rules (互動流程與調度中樞指南)

## 1. Interaction Workflow & Methodology
*   **Atomic Commit Principle:** The agent must pause after logical units of work to allow for user review and manual `git commit` before proceeding.
*   **Worktree Isolation:** All code modifications MUST be performed in a separate Git Worktree (e.g., using `git worktree add`). The agent should not modify the primary workspace directly. The user will perform the final merge after review. (*Exception:* Direct modifications in the primary workspace are strictly prohibited unless explicitly instructed by the user for special operational reasons, such as meta-document configuration updates).
*   **Worktree Location:** The worktree MUST be created **inside** the primary workspace directory (e.g., `.worktrees/<branch-name>`) rather than outside it (e.g., `../Lyra-<name>`). Creating worktrees outside the workspace causes tool permission failures because the agent's file-system access is scoped to the workspace root.
*   **Test-Driven Development (TDD):** Verification is mandatory before finalizing changes. Automated unit and integration tests must be written and executed.
*   **Inquiry before Action:** For complex tasks (e.g., security audits or architectural changes), provide a comprehensive report or plan first. Wait for a directive before implementation.
*   **Surgical Feedback:** Address user feedback on specific code selections precisely using the provided context.
*   **Security & Efficiency Automation:** The project-level `.gemini/settings.json` enables `security.enableConseca` for context-aware security checking. Low-risk operations (e.g., `git worktree add`, `ls`, `git status`) are pre-authorized in `tools.allowed` to streamline the development loop.

## 2. Orchestrator Architecture & Subagent Delegation Discipline (任務拆解與派工紀律)
*   **Proactive Subagent Delegation (Orchestrator Mode):** The primary session acts primarily as a coordinator, orchestrator, and reporter to the user. All actual implementation, codebase exploration, or code modification tasks MUST be delegated to subagents (e.g., `self` or specialized agents). The primary session will only synthesize and report the final results to the user, ensuring the primary context window remains clean and focused.
*   **No Wholesale Pass-Through (禁止直通轉發):** The primary orchestrator must never forward user requests wholesale to subagents without structural analysis, scope definition, and task decomposition.
*   **Dependency Analysis (任務相依性與順序分析):** Before delegating work, the orchestrator must analyze dependencies between subtasks to establish whether they must proceed sequentially or can run concurrently.
*   **Single-Responsibility Subtasks (單一職責子任務):** Break down broad features or modifications into discrete, single-responsibility subtasks with crisp acceptance criteria.
*   **Sequential Gating Workflow (循序閘門控制):** When tasks involve sequential deliverables or cross-dependencies (e.g., "first modify/commit A, then implement B"):
    1. Dispatch a subagent to address subtask A.
    2. Receive subagent report, synthesize progress, and propose a draft commit message for A.
    3. Pause and await explicit user review and commit confirmation.
    4. Only after user confirmation, proceed to dispatch the subsequent subagent for task B.
*   **Parallel Dispatch (平行分流條件):** Concurrent subagent dispatch is permissible ONLY when tasks are completely orthogonal and independent, with no shared file modifications or causal order dependencies.
*   **Subagent Hierarchy & Depth Control (子代理階層深度限制):**
    *   Default to flat coordination by the Primary Agent.
    *   If a subagent invokes its own subagent, the maximum hierarchy depth is strictly limited to 1 nested level (Primary -> Subagent -> Nested Subagent; recursive generation of deeper descendants is strictly prohibited).
    *   The final commit gating and user-facing reporting interface must strictly remain anchored to the Primary Agent.

## 3. Post-Implementation Quality Assurance
*   **Self-Correction Phase:** After completing any modification, the agent MUST proactively check for:
    *   Security vulnerabilities (e.g., credential leaks, unsafe memory usage, input validation).
    *   Data integrity & anti-bandaid checks (root-cause resolution, diagnostic observability, self-healing references, and domain topology adherence).
    *   Violations of project-specific best practices.
*   **Subagent Final Review:** Once potential issues are resolved (or if none are found), the agent MUST invoke a subagent (e.g., `codebase_investigator` or `self`) to perform a "final confirmation" (會後確認) to ensure overall system integrity and adherence to standards.

## 4. Engineering & Implementation Standards Reference
*   **Implementation Standards Authority:** All concrete C++ engineering rules (including CMake source registration and code formatting), Flutter UI modular design system standards (facade contracts, semantic tokens, layout safety, controller lifecycle, and elimination of redundant status badges), and test suite execution workflows MUST strictly adhere to .agents/AGENTS.md
*   **Core Architectural Principles:**
    *   *Strict Server-Side Authority:* Critical identifiers and validation logic belong entirely to the core engine; client inputs are untrusted.
    *   *Root-Cause First (No Bandaid Patching):* Strictly prohibit symptom-level masking fixes when queries or relational lookups yield unexpected results. Resolve underlying data or query issues directly.
    *   *Domain Topology Adherence:* Adhere to established relationship topologies (e.g., Single-Level Star Topology for audio versioning) without unverified hierarchical complexity.
    *   *Performance & Platform Trade-offs:* Proactively discuss Mobile, PC, and Server trade-offs with the user prior to implementing performance-sensitive architectural paths.

## 5. Git & Commit Habits
*   **Commit Message Style:**
    *   Follow `type(scope): message` format based on repository history (e.g., `fix(core)`, `chore(docs)`, `feat(core)`).
    *   Prefer concise, one-line messages, but include a descriptive body if it helps clarify rationale, design decisions, or complex modifications.
    *   **Comprehensive Working Tree Scope:** When proposing a commit message, the agent MUST base it on the **totality of all uncommitted modifications** currently in the working tree (`git status` / `git diff`), rather than only describing the delta from the most recent conversational turn.
    *   Always propose a draft message and wait for approval before execution.
*   **Repository Hygiene:** Proactively maintain `.gitignore`, remove build artifacts, and ensure no large binary or sensitive files are tracked.

## 6. Environment & Tooling Execution
*   **Nix Environment Prerequisite:** Lyra relies on Nix for deterministic compilation and testing environments. All builds, tests, formatting, and analysis must run inside the Nix shell environment.
*   **Tooling Reference:** Consult [.agents/AGENTS.md](.agents/AGENTS.md) for the authoritative wrapper scripts (`./build.sh`, `./test.sh`, `./flutter.sh`) and specific `nix-shell` commands.

