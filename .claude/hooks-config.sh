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
HOOK_ENTRY_GATE_SESSION=true
