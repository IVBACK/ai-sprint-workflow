#!/bin/bash
# Shared library for cross-LLM audit scripts.
# Sourced by cross-llm-audit.sh, pre-merge-audit.sh, verify-evidence.sh, audit-health-check.sh
# Not a standalone hook — prefix with _ to indicate library status.

# ── Logging ──
# Appends a structured JSONL line for every audit invocation.
# Works even if jq is missing (falls back to printf).
# State dir is resolved lazily so CLAUDE_PROJECT_DIR can be set after sourcing.
_log_audit() {
  local status="$1" reason="${2:-}" verdict="${3:-}"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Lazy state dir initialization
  local state_dir="${CLAUDE_PROJECT_DIR:-.}/.claude/.state"
  mkdir -p "$state_dir" 2>/dev/null
  local log_file="${state_dir}/cross-audit-log.jsonl"

  # Log rotation: if log exceeds max size, keep last N lines (configured in hooks-config.sh)
  if [[ -f "$log_file" ]]; then
    local _size
    _size=$(stat -c%s "$log_file" 2>/dev/null || stat -f%z "$log_file" 2>/dev/null || echo 0)
    if [[ "$_size" -gt "${AUDIT_LOG_MAX_BYTES:-1048576}" ]]; then
      tail -"${AUDIT_LOG_KEEP_LINES:-500}" "$log_file" > "${log_file}.tmp" && mv "${log_file}.tmp" "$log_file"
    fi
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -cn --arg ts "$ts" --arg status "$status" --arg reason "$reason" \
          --arg verdict "$verdict" --arg file "${FILE:-}" --arg mode "${AUDIT_MODE:-}" \
      '{ts:$ts,status:$status,reason:$reason,verdict:$verdict,file:$file,mode:$mode}' \
      >> "$log_file" 2>/dev/null
  else
    printf '{"ts":"%s","status":"%s","reason":"%s","verdict":"%s","file":"%s","mode":"%s"}\n' \
      "$ts" "$status" "$reason" "$verdict" "${FILE:-}" "${AUDIT_MODE:-}" \
      >> "$log_file" 2>/dev/null
  fi
}

# ── Secret scrubbing ──
# Strips known secret patterns from diff text before sending to external LLM.
# Input: text via stdin. Output: scrubbed text to stdout.
_scrub_secrets() {
  local text
  text=$(cat)
  # Well-known token prefixes
  text=$(echo "$text" | sed -E 's/sk-ant-[a-zA-Z0-9_-]{20,}/[REDACTED]/g' 2>/dev/null || echo "$text")
  text=$(echo "$text" | sed -E 's/sk-[a-zA-Z0-9_-]{20,}/[REDACTED]/g' 2>/dev/null || echo "$text")
  text=$(echo "$text" | sed -E 's/ghp_[a-zA-Z0-9]{36,}/[REDACTED]/g' 2>/dev/null || echo "$text")
  text=$(echo "$text" | sed -E 's/gho_[a-zA-Z0-9]{36,}/[REDACTED]/g' 2>/dev/null || echo "$text")
  text=$(echo "$text" | sed -E 's/ghu_[a-zA-Z0-9]{36,}/[REDACTED]/g' 2>/dev/null || echo "$text")
  text=$(echo "$text" | sed -E 's/xox[bpsar]-[a-zA-Z0-9-]{10,}/[REDACTED]/g' 2>/dev/null || echo "$text")
  # AWS access keys
  text=$(echo "$text" | sed -E 's/AKIA[A-Z0-9]{16}/[REDACTED]/g' 2>/dev/null || echo "$text")
  text=$(echo "$text" | sed -E 's/ASIA[A-Z0-9]{16}/[REDACTED]/g' 2>/dev/null || echo "$text")
  # Key=value assignments
  text=$(echo "$text" | sed -E "s/(api[_-]?key|secret[_-]?key|secret_?|password|passwd|token|credential|auth[_-]?token|access[_-]?key)(['\"]?[[:space:]]*[:=][[:space:]]*['\"]?)([^'\" ]{8,})/\1\2[REDACTED]/gi" 2>/dev/null || echo "$text")
  # Bearer tokens
  text=$(echo "$text" | sed -E 's/(Bearer )[a-zA-Z0-9_.=-]{20,}/\1[REDACTED]/g' 2>/dev/null || echo "$text")
  # Private key blocks
  text=$(echo "$text" | sed -E 's/-----BEGIN [A-Z ]* PRIVATE KEY-----/[PRIVATE KEY REDACTED]/g' 2>/dev/null || echo "$text")
  text=$(echo "$text" | sed -E 's/-----END [A-Z ]* PRIVATE KEY-----/[END KEY REDACTED]/g' 2>/dev/null || echo "$text")
  # Connection strings with embedded passwords
  text=$(echo "$text" | sed -E 's#(mysql|postgres|postgresql|mongodb|redis|amqp)(://[^:]+:)[^@]+(@)#\1\2[REDACTED]\3#g' 2>/dev/null || echo "$text")
  echo "$text"
}

# ── Load .env for CROSS_AUDIT_* vars ──
# Only imports CROSS_AUDIT_* from .env.
# Shell env vars take precedence (don't override already-set values).
_load_audit_env() {
  local env_file="${1:-${CLAUDE_PROJECT_DIR:-.}/.env}"
  [[ -f "$env_file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    local key="${line%%=*}"
    local value="${line#*=}"
    key=$(echo "$key" | sed 's/^[[:space:]]*export[[:space:]]*//' | tr -d '[:space:]')
    value=$(echo "$value" | sed -E 's/[[:space:]]+#.*$//; s/^[[:space:]]*["'"'"']?//; s/["'"'"']?[[:space:]]*$//')
    if [[ "$key" == CROSS_AUDIT_* ]]; then
      [[ "$key" =~ ^[A-Z][A-Z0-9_]*$ ]] || continue
      local _cur_val
      _cur_val=$(printenv "$key" 2>/dev/null || true)
      [[ -z "$_cur_val" ]] && export "$key=$value"
    fi
  done < "$env_file"
}

# ── API call ──
# Sends a prompt to the configured audit LLM and prints the response content.
# Sets global: _AUDIT_VERDICT, _AUDIT_CONTENT, _AUDIT_PROMPT_TOKENS, _AUDIT_COMPLETION_TOKENS
# Returns: 0 on success, 1 on error
_call_audit_api() {
  local prompt="$1"
  local provider="${CROSS_AUDIT_PROVIDER:-openai}"
  local api_base="${CROSS_AUDIT_API_BASE:-}"
  local model="${CROSS_AUDIT_MODEL:-}"
  local timeout="${CROSS_AUDIT_TIMEOUT:-60}"
  local api_key="${CROSS_AUDIT_API_KEY:-}"

  # Provider defaults
  if [[ "$provider" == "anthropic" ]]; then
    api_base="${api_base:-https://api.anthropic.com}"
    model="${model:-claude-sonnet-4-20250514}"
  else
    api_base="${api_base:-https://api.openai.com/v1}"
    model="${model:-gpt-4o}"
  fi

  # Write prompt to tmpfile to avoid ARG_MAX limits
  local prompt_file
  prompt_file=$(mktemp "${TMPDIR:-/tmp}/.cross-audit-prompt-XXXXXX")
  trap 'rm -f "$prompt_file"' EXIT
  printf '%s' "$prompt" > "$prompt_file"

  local request_body response _http_code

  if [[ "$provider" == "anthropic" ]]; then
    request_body=$(jq -n --arg model "$model" --rawfile prompt "$prompt_file" \
      '{"model":$model,"messages":[{"role":"user","content":$prompt}],"max_tokens":2000,"temperature":0.1}')
    response=$(curl -s --max-time "$timeout" -w "\n%{http_code}" \
      -H "Content-Type: application/json" \
      -H "x-api-key: ${api_key}" \
      -H "anthropic-version: 2023-06-01" \
      "${api_base}/v1/messages" \
      -d "$request_body" 2>/dev/null) || {
      echo "Cross-audit: API call failed (timeout or network error)." >&2
      rm -f "$prompt_file"
      return 1
    }
  else
    request_body=$(jq -n --arg model "$model" --rawfile prompt "$prompt_file" \
      '{"model":$model,"messages":[{"role":"user","content":$prompt}],"temperature":0.1,"max_tokens":2000,"response_format":{"type":"json_object"}}')
    response=$(curl -s --max-time "$timeout" -w "\n%{http_code}" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer ${api_key}" \
      "${api_base}/chat/completions" \
      -d "$request_body" 2>/dev/null) || {
      echo "Cross-audit: API call failed (timeout or network error)." >&2
      rm -f "$prompt_file"
      return 1
    }
  fi

  rm -f "$prompt_file"

  _http_code=$(echo "$response" | tail -1)
  response=$(echo "$response" | sed '$d')

  # Parse response
  local api_error
  if [[ "$provider" == "anthropic" ]]; then
    api_error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
    [[ -z "$api_error" ]] && api_error=$(echo "$response" | jq -r '.error.type // empty' 2>/dev/null)
    _AUDIT_CONTENT=$(echo "$response" | jq -r '[.content[] | select(.type=="text") | .text] | join("")' 2>/dev/null)
    _AUDIT_PROMPT_TOKENS=$(echo "$response" | jq -r '.usage.input_tokens // "?"' 2>/dev/null)
    _AUDIT_COMPLETION_TOKENS=$(echo "$response" | jq -r '.usage.output_tokens // "?"' 2>/dev/null)
  else
    api_error=$(echo "$response" | jq -r '.error.message // empty' 2>/dev/null)
    _AUDIT_CONTENT=$(echo "$response" | jq -r '.choices[0].message.content // empty' 2>/dev/null)
    _AUDIT_PROMPT_TOKENS=$(echo "$response" | jq -r '.usage.prompt_tokens // "?"' 2>/dev/null)
    _AUDIT_COMPLETION_TOKENS=$(echo "$response" | jq -r '.usage.completion_tokens // "?"' 2>/dev/null)
  fi

  if [[ -n "$api_error" ]]; then
    echo "Cross-audit: API error — $api_error (HTTP ${_http_code:-unknown})" >&2
    return 1
  fi
  if [[ -z "$_AUDIT_CONTENT" ]]; then
    echo "Cross-audit: Empty response from API" >&2
    return 1
  fi

  # Parse verdict — layered: raw → strip fences → extract JSON substring
  _AUDIT_VERDICT=$(echo "$_AUDIT_CONTENT" | jq -r '.verdict // empty' 2>/dev/null || true)
  if [[ -z "$_AUDIT_VERDICT" ]]; then
    local _clean
    _clean=$(echo "$_AUDIT_CONTENT" | sed '/^[[:space:]]*```[a-z]*/d')
    _AUDIT_VERDICT=$(echo "$_clean" | jq -r '.verdict // empty' 2>/dev/null || true)
  fi
  if [[ -z "$_AUDIT_VERDICT" ]]; then
    local _extracted
    _extracted=$(echo "$_AUDIT_CONTENT" | sed -n '/{/,/}/p')
    _AUDIT_VERDICT=$(echo "$_extracted" | jq -r '.verdict // empty' 2>/dev/null || true)
  fi
  if [[ -z "$_AUDIT_VERDICT" ]]; then
    _AUDIT_VERDICT="UNKNOWN"
    echo "Cross-audit: WARNING — Could not parse verdict from LLM response." >&2
  fi
  _AUDIT_MODEL="$model"

  return 0
}
