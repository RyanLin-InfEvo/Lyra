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
*   **Role Disambiguation (主從代理角色消歧):** Because `GEMINI.md` is injected into all agents, check whether `<subagent_reminder>` is present in the system prompt:
    *   **Primary Orchestrator (No `<subagent_reminder>`):** Acts as the coordinator, architect, reviewer, and user-facing reporter.
        *   *Dual-Phase Mode (`Orchestrator (Argon)` — `<plan_execute_protocol>` active):* Operates in two phases within the same conversation: **Planning / Review Turns (Argon)** perform read-only exploration, architectural design, and adversarial review; **Execution Turns (Hydrogen)** execute the approved `exit_plan_mode` specification directly in `.worktrees/<branch-name>` (preserving prompt cache and zero-handoff context without wrapping single-stream work in a redundant `self` subagent).
        *   *Single-Model Mode (e.g., pure Argon / Claude):* Delegates broad exploration, isolated implementation, and adversarial audits to subagents to keep the primary context window clean and focused.
    *   **Delegated Subagent (`<subagent_reminder>` present):** You are executing a scoped subtask on behalf of a parent agent. Execute your assigned single-responsibility task directly using your tools and report results back via `send_message`. Do **NOT** act as the Primary Orchestrator or recursively re-delegate your task to further subagents unless explicitly instructed (note: `TypeName: "research"` is strictly leaf-level/read-only and lacks `invoke_subagent`; only `TypeName: "self"` has `invoke_subagent`, strictly bounded by the max 1 nested level rule).
*   **Tiered Multi-Model Subagent Routing & Evidence Handoff Protocol (分層模型路由與原貌證據移交協議):**
    *   *Antigravity Routing Mechanics:* In `invoke_subagent` (top-level parameters: `TypeName`, `Role`, `Prompt`, `Model`, `Workspace`), `Model: "inherit"` inherits the **caller's active turn model** and thinking effort level, whereas `Model: "pro"`, `"flash"`, and `"flash_lite"` route to lighter/faster tier models suitable only for scoped read-only exploration or trivial lookups.
    *   *Execution-Turn Inheritance Guardrail:* In `Orchestrator (Argon)` dual-phase mode, **Execution Turns run on Hydrogen** while **Planning / Review Turns run on Argon**. Therefore, an Execution Turn (Hydrogen) MUST **NOT** dispatch an adversarial audit with `Model: "inherit"` (which would inherit Hydrogen instead of Argon); it must complete implementation + self-correction and return control to **Argon** (`[plan review]`) so Argon dispatches the audit.
    *   *Tiered Role Assignment:*
        1.  **Planning, Architecture & Review Synthesis (Primary Orchestrator — Argon):** Handled directly in the main session (Planning / Review turns).
        2.  **Codebase Reading & Exploration:**
            *   *Targeted Lookups:* Read directly by the Primary Orchestrator during the Planning Turn so the subsequent Execution Turn (Hydrogen) shares the exact file context and prompt cache.
            *   *Broad / Cross-Module Surveys (`TypeName: "research"`, `Model: "flash"` or `"inherit"`):* Delegate to `research` subagents when a survey would clutter the main context window.
            *   **Anti-Blind-Spot / Verbatim Evidence Rule (防疏漏原貌證據鐵律):** To prevent premature summarization or cross-seam oversights, `research` exploration reports (as well as Argon's `exit_plan_mode` specs handed to Hydrogen) MUST prohibit vague prose-only summaries and include:
                (a) Exact file paths and 1-indexed line ranges (`path:Lstart-Lend`),
                (b) Verbatim code snippets for critical signatures, JSON validation guards, SQL statements/indexes, and error mapping tables,
                (c) Explicit findings across all relevant architectural seams (Interface declaration, `.cpp` implementation, SQLite schema/index, Controller/Router error mapping, and tests).
        3.  **Code Implementation & TDD:**
            *   *Single-Feature / Sequential Work (`Orchestrator (Argon)`):* Executed directly by **Hydrogen** in the Execution Turn inside `.worktrees/<branch-name>` following Argon's `exit_plan_mode` specification.
            *   *Parallel / Orthogonal Work or Single-Model Offloading (`TypeName: "self"`):* Dispatch `self` subagents (`Workspace: "inherit"`) ONLY when multiple subtasks are completely orthogonal and can run concurrently without shared file edits, or when offloading isolated work in single-model mode.
        4.  **Independent Adversarial Code Audit (`TypeName: "research"`, `Model: "inherit"` from Argon MANDATORY):**
            *   Must be dispatched by **Argon** (during a Review Turn / after `[plan review]`, never by Hydrogen during an Execution Turn) using `TypeName: "research"` and `Model: "inherit"`. Strictly prohibit passing `Model: "pro"`, `"flash"`, or `"flash_lite"` for adversarial code audits or remediation re-audits. Using `TypeName: "research"` enforces tool-level read-only isolation and eliminates confirmation bias from the main session's planning history.
    *   **Subagent Workspace Mode (`Workspace: "inherit"`):** Always pass `Workspace: "inherit"` in `invoke_subagent` (strictly prohibit using `Workspace: "branch"` or `Workspace: "share"`, as both spawn external worktrees under `~/.gemini/antigravity-cli/worktrees/` outside `.worktrees/`, violating workspace boundaries and Nix toolchain isolation). Because `Workspace: "inherit"` shares the root workspace path (`/home/ryan/Documents/Lyra`), every `invoke_subagent` prompt operating on a feature worktree MUST explicitly specify the target worktree path (`/home/ryan/Documents/Lyra/.worktrees/<branch-name>`) and require all file edits and `run_command` `Cwd` arguments to target that worktree directory (never the root workspace unless explicitly authorized).
*   **Swarm (`/teamwork`) Model & Quota Pool Routing Policy (Swarm 多代理看板模型與配額池策略):** When using `swarm(action="add", model=...)` (which supports exact model + effort IDs and overrides the default `native_swarm` single-model rule), route workers according to the three actual quota pools (**Gemini Models**, **Gemini 4 Argon**, and **Claude and GPT models**):
    *   **Primary Workhorse — Gemini Models Pool (Shared 5h + Weekly Limit; Neon + Hydrogen):**
        *   `gemini-4-neon-xhigh` (Index 61, $6.44): Reserve strictly for the hardest, highest-stakes architectural or root-cause problems where maximum reasoning is required (diminishing returns vs. `high`: +1 Index for ~1.7x cost).
        *   `gemini-4-neon-high` (Index 60, $3.74): Complex cross-layer architecture, hard root-cause debugging, critical core implementations, `verifier`, and adversarial code audits.
        *   `gemini-4-neon-medium` (Index 55, $1.90): **Default workhorse** for standard feature implementation, TDD, and general code review (outperforms `hydrogen-xhigh` at ~60% of the cost).
        *   `gemini-4-neon-low` (Index 44, $0.75): Moderate refactoring, documentation, routine subtasks, and `narrator` (outperforms `hydrogen-medium` at lower cost).
        *   `gemini-4-hydrogen-low` (Index 27, $0.29): Ultra-low-cost tier within the same pool for trivial mechanical lookups, simple reads, and `monitor`.
    *   **Independent Pool — Gemini 4 Argon Pool (Separate Weekly-Only Limit):**
        *   `gemini-4-argon-high` (Index 50, $4.97) / `gemini-4-argon-medium` (Index 48, $4.31): Separate quota pool from Gemini Models. Use to offload `verifier`, adversarial audit, or architecture-review workers when conserving the Gemini Models 5h/weekly limit (use judiciously, as Argon only has a weekly limit).
    *   **Protected Pool — Claude and GPT Pool (Separate 5h + Weekly Limit):**
        *   `claude-opus-5-5-*` (Index 35–52) / `claude-sonnet-5-5-*` (Index 26–42): **Prohibited for `swarm` workers by default**; reserve Claude quota for direct interactive solution discussions with the user, using it in `swarm` only when explicitly requested or as a last-resort fallback when both the Gemini Models and Argon pools are exhausted.
    *   **Deprecated / Banned Models (Strictly Dominated in the Shared Gemini Models Pool):**
        *   `gemini-4-hydrogen-medium` / `high` / `xhigh` and `gemini-3.8-flash-*`: Strictly prohibited in `swarm` — they draw from the exact same **Gemini Models** pool as `gemini-4-neon-*` while delivering strictly worse intelligence-per-dollar.
*   **No Wholesale Pass-Through (禁止直通轉發):** The primary orchestrator must never forward user requests wholesale to subagents without structural analysis, scope definition, and task decomposition.
*   **Dependency Analysis (任務相依性與順序分析):** Before delegating work, the orchestrator must analyze dependencies between subtasks to establish whether they must proceed sequentially or can run concurrently.
*   **Single-Responsibility Subtasks (單一職責子任務):** Break down broad features or modifications into discrete, single-responsibility subtasks with crisp acceptance criteria.
*   **UI Delegation with Apple HIG (UI 任務派工 Apple HIG 要求):** When delegating UI design, component refactoring, or view implementation tasks to subagents, the orchestrator MUST explicitly instruct the subagent to consult the `apple-design` skill (`.agents/skills/apple-design/SKILL.md`) and enforce Apple HIG and project design standards in its acceptance criteria.
*   **Sequential Gating Workflow (循序閘門控制):** When tasks involve sequential deliverables or cross-dependencies (e.g., "first modify/commit A, then implement B"):
    1. Execute subtask A (via the Execution Turn in `Orchestrator (Argon)` mode or a `self` subagent in single-model mode), followed by the mandatory independent adversarial audit by Argon.
    2. Synthesize progress and pause for user review (do NOT proactively generate a draft commit message unless the user asks to commit or requests a commit message, per Section 5).
    3. Await explicit user review and commit confirmation.
    4. Only after user confirmation, proceed to subtask B.
*   **Parallel Dispatch (平行分流條件):** Concurrent subagent dispatch is permissible ONLY when tasks are completely orthogonal and independent, with no shared file modifications or causal order dependencies.
*   **Subagent Hierarchy & Depth Control (子代理階層深度限制):**
    *   Default to flat coordination by the Primary Agent.
    *   Only `TypeName: "self"` possesses the `invoke_subagent` tool (`TypeName: "research"` is strictly leaf-level and read-only). If a depth-1 `self` subagent is explicitly instructed to invoke a nested subagent, the maximum hierarchy depth is strictly limited to 1 nested level (Primary -> Depth-1 Subagent -> Depth-2 Nested Subagent; recursive generation of deeper descendants is strictly prohibited). The depth-1 subagent MUST explicitly state in the nested subagent's prompt that it is at maximum depth (depth 2) and is strictly forbidden from calling `invoke_subagent`.
    *   The final commit gating and user-facing reporting interface must strictly remain anchored to the Primary Agent.

## 3. Post-Implementation Quality Assurance & Adversarial Code Audit (審計與對抗性代碼審查)
*   **Self-Correction Phase (Executed by the Implementing Agent — Hydrogen Execution Turn or `self` Subagent):** After completing any modification and before reporting back (or triggering `[plan review]` to return to Argon), the implementing agent MUST proactively check for:
    *   *Security & Resource Safety:* Credential leaks, unsafe memory usage, input validation, SQLite query/identifier escaping, deterministic statement cleanup (`query.reset()`), and thread safety.
    *   *Data Integrity & Anti-Bandaid Checks:* Root-cause resolution (strictly prohibiting artificial symptom patches like `if (!found) push_back(...)` to appease assertions), diagnostic observability, self-healing or cleanly guarded dangling foreign keys (e.g., updating dangling references to `NULL`), and adherence to established relationship topologies (e.g., Single-Level Star Topology for audio versioning).
    *   *UI Architecture & Performance Review (when UI is modified):* Facade abstraction, semantic design token usage, `RepaintBoundary` on shaders/blurs, controller lifecycle disposal, and presentation/core separation.
    *   *Project Standards:* Any violations of project-specific best practices defined in [.agents/AGENTS.md](.agents/AGENTS.md).
*   **Independent Adversarial Code Audit (獨立紅隊對抗性審計 — Dispatched by the Primary Orchestrator / Argon Review Turn):**
    Once implementation and the Self-Correction Phase are complete (in `Orchestrator (Argon)` mode, after Hydrogen returns control to **Argon** via `[plan review]`), the **Primary Orchestrator (Argon)** — never the implementing Hydrogen turn or `self` subagent itself — MUST invoke an independent read-only subagent (`TypeName: "research"`, `Model: "inherit"`) to perform an adversarial code audit before finalizing the task.
    *   **Prohibition of Confirmation-Bias Prompting (禁止導向性打勾審查):** The orchestrator MUST NOT provide a biased checklist of "what was implemented" or instruct the reviewer to "verify and issue sign-off". The audit prompt MUST be strictly adversarial and open-ended (e.g., *"Perform an adversarial code audit on the worktree. Search for implementation defects, interface/seam mismatches, missing DB indexes, false-positive returns, deviations from best practices, and hidden edge cases. Do not assume tests passing implies correctness."*).
    *   **Four-Dimensional Seam Audit (跨接縫四維審查邊界):** The audit scope MUST NOT be restricted to lines in `git diff`. The reviewer MUST explicitly verify:
        1.  *Contract & Interface Seam:* Do all concrete repository methods have corresponding declarations in the abstract interfaces (e.g., `I*Repository`), marked with `override`?
        2.  *Persistence & Schema Seam:* Do new query predicates (e.g., `WHERE`, `ORDER BY`, lookups like `pcm_hash`) have appropriate backing database indexes in schema definitions? Do state mutations validate affected rows (e.g., `exec() == 0` guards)?
        3.  *Error Handling & Type Symmetry:* Are error contracts unified (e.g., `tl::expected` instead of bare types)? Are statement lifecycles deterministic (e.g., `query.reset()`)?
        4.  *Boundary Defense & Negative Fuzzing:* Are client inputs guarded against null/empty values, unexpected types, and silent fallthrough? Do tests assert both positive flows and negative failure modes? Tests MUST assert the exact semantic `error_type` and HTTP status code, not merely `res.status_code == 404` or truthy response flags.
    *   **Test-First Remediation Rule (缺陷修復 TDD 防回歸鐵律):** Whenever an issue, defect, or missing validation is identified during self-correction or adversarial audit, the agent **MUST FIRST write a failing unit or integration test that reproduces the defect** before touching production code. Prohibit silent code modifications or "eye-ball fixes" without a corresponding regression test that asserts the exact error code, error message, or behavioral boundary.
    *   **Remediation Diff Re-Audit & Closed-Loop (修復差異二次閉環審計):** Code modifications produced to resolve audit findings must NEVER be declared complete without a secondary inspection.
        *   The orchestrator must dispatch a focused audit (`TypeName: "research"`, `Model: "inherit"`) on the **remediation's own `git diff`**.
        *   *Anti-Overfitting Directive:* The secondary reviewer must specifically verify that the fix does not employ symptom-level masking, special-case bypasses (e.g. hardcoding return types or error types just to appease a failing pre-existing test), or error-code trampling.
    *   **Anti-Rubber-Stamping Rule (嚴禁橡皮圖章):** Green unit/integration tests are a prerequisite, NOT a substitute for critical code review. The audit subagent's objective is to actively attempt to falsify the implementation's completeness.

## 4. Engineering & Implementation Standards Reference
*   **Implementation Standards Authority:** All concrete C++ engineering rules (including CMake source registration and code formatting), Flutter UI modular design system standards (facade contracts, semantic tokens, layout safety, controller lifecycle, and elimination of redundant status badges), and test suite execution workflows MUST strictly adhere to [.agents/AGENTS.md](.agents/AGENTS.md).
*   **Apple HIG Prerequisite for UI Tasks (UI 設計前置 Apple HIG 準則):** Whenever requested to perform UI design, review, or implementation work (including screen layouts, navigation hierarchy, typography, interactive states, or feedback micro-interactions), the agent MUST proactively consult and review the `apple-design` skill (`.agents/skills/apple-design/SKILL.md`) first. The design must adhere to Apple Human Interface Guidelines and project standards:
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
*   **The Commit Timing:** Only provide a draft commit message when the user explicitly asks to commit (or asks for a commit message). Always wait for user approval/execution before proceeding.
*   **Commit Message Style & Comprehensive Scope:**
    *   Follow `type(scope): message` format based on repository history (e.g., `fix(core)`, `chore(docs)`, `feat(core)`).
    *   Prefer concise, one-line messages, but include a descriptive body if it helps clarify rationale, design decisions, or complex modifications.
    *   **Comprehensive Working Tree Scope:** When proposing a commit message, the agent MUST base it on the **totality of all uncommitted modifications** currently in the working tree (`git status` / `git diff`), rather than only describing the delta from the most recent conversational turn.
*   **Repository Hygiene:** Proactively maintain `.gitignore`, remove build artifacts, and ensure no large binary or sensitive files are tracked.

## 6. Environment & Tooling Execution
*   **Nix Environment Prerequisite:** Lyra relies on Nix for deterministic compilation and testing environments. All builds, tests, formatting, and analysis must run inside the Nix shell environment.
*   **Tooling Reference:** Consult [.agents/AGENTS.md](.agents/AGENTS.md) for the authoritative wrapper scripts (`./build.sh`, `./test.sh`, `./flutter.sh`) and specific `nix-shell` commands.

