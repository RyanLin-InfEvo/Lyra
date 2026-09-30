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
*   **UI Delegation with Apple HIG (UI 任務派工 Apple HIG 要求):** When delegating UI design, component refactoring, or view implementation tasks to subagents, the orchestrator MUST explicitly instruct the subagent to consult the `apple-design` skill (`/home/ryan/.gemini/config/skills/apple-design/SKILL.md`) and enforce Apple HIG and project design standards in its acceptance criteria.
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

## 3. Post-Implementation Quality Assurance & Adversarial Code Audit (審計與對抗性代碼審查)
*   **Self-Correction Phase:** After completing any modification, the agent MUST proactively check for:
    *   Security vulnerabilities (e.g., credential leaks, unsafe memory usage, input validation, SQL injection/identifier escaping).
    *   Data integrity & anti-bandaid checks (root-cause resolution, diagnostic observability, self-healing references, and domain topology adherence).
    *   Violations of project-specific best practices.
*   **Independent Adversarial Code Audit (獨立紅隊對抗性審計，取代軟性會後確認):**
    Once potential issues are resolved (or if none are found), the agent MUST invoke a subagent (e.g., `codebase_investigator` or `self`) to perform an independent, adversarial code audit before proposing a commit.
    *   **Prohibition of Confirmation-Bias Prompting (禁止導向性打勾審查):** The orchestrator MUST NOT provide a biased checklist of "what was implemented" or instruct the reviewer to "verify and issue sign-off". The audit prompt MUST be strictly adversarial and open-ended (e.g., *"Perform an adversarial code audit on the worktree. Search for implementation defects, interface/seam mismatches, missing DB indexes, false-positive returns, deviations from best practices, and hidden edge cases. Do not assume tests passing implies correctness."*).
    *   **Four-Dimensional Seam Audit (跨接縫四維審查邊界):** The audit scope MUST NOT be restricted to lines in `git diff`. The reviewer MUST explicitly verify:
        1.  *Contract & Interface Seam:* Do all concrete repository methods have corresponding declarations in the abstract interfaces (e.g., `I*Repository`), marked with `override`?
        2.  *Persistence & Schema Seam:* Do new query predicates (e.g., `WHERE`, `ORDER BY`, lookups like `pcm_hash`) have appropriate backing database indexes in schema definitions? Do state mutations validate affected rows (e.g., `exec() == 0` guards)?
        3.  *Error Handling & Type Symmetry:* Are error contracts unified (e.g., `tl::expected` instead of bare types)? Are statement lifecycles deterministic (e.g., `query.reset()`)?
        4.  *Boundary Defense & Negative Fuzzing:* Are client inputs guarded against null/empty values, unexpected types, and silent fallthrough? Do tests assert both positive flows and negative failure modes? Tests MUST assert the exact semantic `error_type` and HTTP status code, not merely `res.status_code == 404` or truthy response flags.
    *   **Test-First Remediation Rule (缺陷修復 TDD 防回歸鐵律):** Whenever an issue, defect, or missing validation is identified during self-correction or adversarial audit, the agent **MUST FIRST write a failing unit or integration test that reproduces the defect** before touching production code. Prohibit silent code modifications or "eye-ball fixes" without a corresponding regression test that asserts the exact error code, error message, or behavioral boundary.
    *   **Remediation Diff Re-Audit & Closed-Loop (修復差異二次閉環審計):** Code modifications produced to resolve audit findings must NEVER be declared complete without a secondary inspection.
        *   The orchestrator must dispatch a focused audit on the **remediation's own `git diff`**.
        *   *Anti-Overfitting Directive:* The secondary reviewer must specifically verify that the fix does not employ symptom-level masking, special-case bypasses (e.g. hardcoding return types or error types just to appease a failing pre-existing test), or error-code trampling.
    *   **Anti-Rubber-Stamping Rule (嚴禁橡皮圖章):** Green unit/integration tests are a prerequisite, NOT a substitute for critical code review. The audit subagent's objective is to actively attempt to falsify the implementation's completeness.

## 4. Engineering & Implementation Standards Reference
*   **Implementation Standards Authority:** All concrete C++ engineering rules (including CMake source registration and code formatting), Flutter UI modular design system standards (facade contracts, semantic tokens, layout safety, controller lifecycle, and elimination of redundant status badges), and test suite execution workflows MUST strictly adhere to .agents/AGENTS.md
*   **Apple HIG Prerequisite for UI Tasks (UI 設計前置 Apple HIG 準則):** Whenever requested to perform UI design, review, or implementation work (including screen layouts, navigation hierarchy, typography, interactive states, or feedback micro-interactions), the agent MUST proactively consult and review the `apple-design` skill (`/home/ryan/.gemini/config/skills/apple-design/SKILL.md`) first. The design must adhere to Apple Human Interface Guidelines and project standards:
    *   *Quiet Defaults & Zero AI-Clutter:* Strictly prohibit vanity status badges for normal states (e.g., "Verified", "100% Bit-Perfect"). Normal items must remain visually quiet; highlight only warnings, errors, or destructive states.
    *   *Concise Header Typography:* Keep view titles minimal without redundant explanatory subtitles. Use Title Case for all table column headers.
    *   *Hierarchical Navigation:* Anchor primary and secondary sections in the left sidebar hierarchy rather than cluttering content headers with redundant top-level tabs. Keep maintenance and destructive operations in dedicated settings views.
    *   *Decoupled Interactions:* Secondary inline actions (such as copying a hash, downloading, or toggling) must never trigger row selection, navigation, or inspector drawer switching.
    *   *Focal Point Feedback & Motion Smoothness:* Interaction feedback must transform in-place where the user is looking (e.g. within active tooltips). Maintain fixed geometry (`height: 28.0`) across state toggles to prevent vertical layout shifts, and use smooth curves (`Curves.easeInOutCubic`) with transitional animations (`AnimatedSize`, `AnimatedSwitcher`, `AnimatedContainer`).
*   **Core Architectural Principles:**
    *   *Strict Server-Side Authority:* Critical identifiers and validation logic belong entirely to the core engine; client inputs are untrusted.
    *   *Fail-Fast Boundary Defense & Anti-False-Positive:* When parsing client payloads (e.g. JSON), `contains("key")` alone is strictly prohibited. The parser must explicitly validate non-nullity, expected data types, and non-empty values (`!p["key"].is_null() && p["key"].is_string()`). Incomplete or null parameters must fail-fast with explicit client error responses (`MissingParameter` / `InvalidValue`). Silent fallthrough to default uninitialized targets or returning HTTP 200 with empty execution results (false-positive success) is considered a critical defect.
    *   *Root-Cause First (No Bandaid Patching):* Strictly prohibit symptom-level masking fixes when queries or relational lookups yield unexpected results. Resolve underlying data or query issues directly.
    *   *Exhaustive Error Matrix & Anti-Overfitting:* Error mapping across layers must be symmetric and table-driven across the domain entity matrix `(TargetType x ErrorCode) -> (HttpCode, ErrorType)`. Prohibit hardcoded special-case overrides (such as `if (type == Asset) return AssetNotFound`) to artificially appease pre-existing integration tests.
    *   *Domain Topology Adherence:* Adhere to established relationship topologies (e.g., Single-Level Star Topology for audio versioning) without unverified hierarchical complexity.
    *   *Performance & Platform Trade-offs:* Proactively discuss Mobile, PC, and Server trade-offs with the user prior to implementing performance-sensitive architectural paths.

## 5. Git & Commit Habits
*   **Commit Message Style:**
    *   Follow `type(scope): message` format based on repository history (e.g., `fix(core)`, `chore(docs)`, `feat(core)`).
    *   Prefer concise, one-line messages, but include a descriptive body if it helps clarify rationale, design decisions, or complex modifications.
    *   **Comprehensive Working Tree Scope:** When proposing a commit message, the agent MUST base it on the **totality of all uncommitted modifications** currently in the working tree (`git status` / `git diff`), rather than only describing the delta from the most recent conversational turn.
    *   Always propose a draft message and wait for approval before execution.
*   **Repository Hygiene:** Proactively maintain `.gitignore`, remove build artifacts, and ensure no large binary or sensitive files are tracked.
*   **The Commit Timing:** Only provide commit message when user ask to commit, and the commit message must be base on the totality of all uncommitted modifications currently in the working tree (`git status` / `git diff`).

## 6. Environment & Tooling Execution
*   **Nix Environment Prerequisite:** Lyra relies on Nix for deterministic compilation and testing environments. All builds, tests, formatting, and analysis must run inside the Nix shell environment.
*   **Tooling Reference:** Consult [.agents/AGENTS.md](.agents/AGENTS.md) for the authoritative wrapper scripts (`./build.sh`, `./test.sh`, `./flutter.sh`) and specific `nix-shell` commands.

