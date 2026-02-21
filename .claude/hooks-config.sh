# Claude Code Hooks — Feature Flags
# Toggle individual hooks on/off without touching settings.json
# All hooks read this file first. Set to "false" to disable.
#
# These hooks enforce WORKFLOW.md rules for Claude Code users only.
# Other AI agents (GPT, Gemini, etc.) do not read this directory.

# Prevent CLAUDE.md from being overwritten (highest priority rule)
HOOK_PROTECT_CLAUDE_MD=true

# Validate TRACKING.md status values are legal after every edit
HOOK_VALIDATE_TRACKING=true

# Remind agent to read TRACKING.md at session start
HOOK_SESSION_START_PROTOCOL=true

# Detect duplicate CORE-### IDs in TRACKING.md after every edit
HOOK_VALIDATE_ID_UNIQUENESS=true

# Inject mandatory session boundary recommendation after Entry Gate report is written
# Also validates Entry Gate content: failure modes, verification plans, metrics
HOOK_ENTRY_GATE_SESSION=true

# CP3: Detect test failures in Bash output and surface AUDIT SIGNAL
HOOK_DETECT_TEST_REGRESSION=true

# CP4: Validate Close Gate report completeness and check for unverified must items
HOOK_VALIDATE_CLOSE_GATE=true

# Validate Sprint Close report: retrospective, baseline, handoff sections
HOOK_VALIDATE_SPRINT_CLOSE=true

# CP1+CP2: Self-activating metric regression and failure pattern detector (SessionStart)
# Requires structured §Performance Baseline Log and §Failure History tables in TRACKING.md
# Silent if sections missing or data insufficient — zero false positives without structured data
HOOK_DETECT_AUDIT_SIGNALS=true
