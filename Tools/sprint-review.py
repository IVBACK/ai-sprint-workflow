#!/usr/bin/env python3
"""Blind review tool — sends content to external LLM for independent review.

MVP: single reviewer (GPT-4o or configured provider), blind prompt.
The reviewer has NO context about the author's reasoning.

Usage:
    sprint-review.py FILE                   # review a file
    sprint-review.py FILE --question "..."  # review with specific question
    sprint-review.py --stdin                # review from stdin (e.g. git diff | ...)
    sprint-review.py FILE --json            # structured JSON output
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile


def load_env(project_root: str) -> None:
    """Load CROSS_AUDIT_* vars from .env (don't override existing)."""
    env_file = os.path.join(project_root, ".env")
    if not os.path.isfile(env_file):
        return
    with open(env_file, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip().removeprefix("export ")
            value = value.strip().strip("'\"")
            if key.startswith("CROSS_AUDIT_") and not os.environ.get(key):
                os.environ[key] = value


def find_project_root() -> str:
    """Walk up to find .env or .claude/ directory."""
    d = os.getcwd()
    for _ in range(20):
        if os.path.isfile(os.path.join(d, ".env")) or os.path.isdir(
            os.path.join(d, ".claude")
        ):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            break
        d = parent
    return os.getcwd()


def build_blind_prompt(
    content: str,
    question: str | None = None,
    context: str | None = None,
) -> str:
    """Build the blind review prompt. Reviewer gets NO author reasoning."""
    prompt = """You are reviewing the following artifact. You have NO context about
why it was written this way or what the author was thinking. You are an independent
reviewer seeing this for the first time.
"""
    if context:
        prompt += f"""
[CONTEXT]
{context}
[/CONTEXT]
Note: The context above tells you WHAT this artifact is, not WHY it was made this way.
"""
    prompt += f"""
[ARTIFACT]
{content}
[/ARTIFACT]

Evaluate:
1. What assumptions are unchallenged?
2. What's missing that a senior engineer/architect would ask about?
3. What errors, inconsistencies, or risks do you see?
4. What would you change and why?
"""
    if question:
        prompt += f"\nAdditionally, answer this specific question: {question}\n"

    prompt += """
Respond in this JSON format:
{
  "findings": [
    {"severity": "critical|warning|info", "description": "...", "suggestion": "..."}
  ],
  "summary": "one paragraph overall assessment",
  "missing": ["things that should be there but aren't"]
}"""
    return prompt


def call_api(prompt: str) -> dict:
    """Call the external LLM API. Uses same config as cross-llm-audit."""
    provider = os.environ.get("CROSS_AUDIT_PROVIDER", "openai")
    api_key = os.environ.get("CROSS_AUDIT_API_KEY", "")
    api_base = os.environ.get("CROSS_AUDIT_API_BASE", "")
    model = os.environ.get("CROSS_AUDIT_MODEL", "")
    timeout = int(os.environ.get("CROSS_AUDIT_TIMEOUT", "60"))

    if not api_key:
        print("Error: CROSS_AUDIT_API_KEY not set. Run: bash .claude/setup-audit.sh",
              file=sys.stderr)
        sys.exit(1)

    if provider == "anthropic":
        api_base = api_base or "https://api.anthropic.com"
        model = model or "claude-sonnet-4-20250514"
        headers = [
            "-H", "Content-Type: application/json",
            "-H", f"x-api-key: {api_key}",
            "-H", "anthropic-version: 2023-06-01",
        ]
        url = f"{api_base}/v1/messages"
        body = json.dumps({
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": 2000,
            "temperature": 0.1,
        })
    else:
        api_base = api_base or "https://api.openai.com/v1"
        model = model or "gpt-4o"
        headers = [
            "-H", "Content-Type: application/json",
            "-H", f"Authorization: Bearer {api_key}",
        ]
        url = f"{api_base}/chat/completions"
        body = json.dumps({
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.1,
            "max_tokens": 2000,
            "response_format": {"type": "json_object"},
        })

    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        f.write(body)
        body_file = f.name

    try:
        result = subprocess.run(
            ["curl", "-s", "--max-time", str(timeout), *headers, url, "-d", f"@{body_file}"],
            capture_output=True, text=True, timeout=timeout + 10,
        )
    except subprocess.TimeoutExpired:
        print("Error: API call timed out.", file=sys.stderr)
        sys.exit(1)
    finally:
        os.unlink(body_file)

    if result.returncode != 0:
        print(f"Error: curl failed — {result.stderr}", file=sys.stderr)
        sys.exit(1)

    try:
        resp = json.loads(result.stdout)
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON response from API.", file=sys.stderr)
        sys.exit(1)

    if "error" in resp:
        print(f"Error: API — {resp['error'].get('message', resp['error'])}",
              file=sys.stderr)
        sys.exit(1)

    if provider == "anthropic":
        content = "".join(
            b["text"] for b in resp.get("content", []) if b.get("type") == "text"
        )
        tokens_in = resp.get("usage", {}).get("input_tokens", "?")
        tokens_out = resp.get("usage", {}).get("output_tokens", "?")
    else:
        content = resp.get("choices", [{}])[0].get("message", {}).get("content", "")
        tokens_in = resp.get("usage", {}).get("prompt_tokens", "?")
        tokens_out = resp.get("usage", {}).get("completion_tokens", "?")

    return {
        "content": content,
        "model": model,
        "tokens_in": tokens_in,
        "tokens_out": tokens_out,
    }


def parse_findings(raw_content: str) -> dict:
    """Try to parse structured JSON from response, fallback to raw text."""
    try:
        return json.loads(raw_content)
    except json.JSONDecodeError:
        pass
    # Try extracting JSON from markdown fences
    import re
    m = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", raw_content, re.DOTALL)
    if m:
        try:
            return json.loads(m.group(1))
        except json.JSONDecodeError:
            pass
    return {"raw": raw_content}


def format_text(findings: dict, model: str, tokens_in, tokens_out) -> str:
    """Format findings as readable text."""
    lines = [f"── Blind Review ({model}, {tokens_in}→{tokens_out} tokens) ──", ""]

    if "summary" in findings:
        lines.append(findings["summary"])
        lines.append("")

    for f in findings.get("findings", []):
        sev = f.get("severity", "info").upper()
        desc = f.get("description", "")
        suggestion = f.get("suggestion", "")
        lines.append(f"  [{sev}] {desc}")
        if suggestion:
            lines.append(f"         → {suggestion}")

    missing = findings.get("missing", [])
    if missing:
        lines.append("")
        lines.append("Missing:")
        for m in missing:
            lines.append(f"  - {m}")

    if "raw" in findings:
        lines.append(findings["raw"])

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Blind review via external LLM")
    parser.add_argument("file", nargs="?", help="File to review")
    parser.add_argument("--stdin", action="store_true", help="Read from stdin")
    parser.add_argument("--question", "-q", help="Specific question for reviewer")
    parser.add_argument("--context", "-c", help="What this artifact is (NOT why it was made)")
    parser.add_argument("--json", action="store_true", help="Output raw JSON")
    args = parser.parse_args()

    if not args.file and not args.stdin:
        parser.print_help()
        sys.exit(1)

    if args.stdin:
        content = sys.stdin.read()
    else:
        if not os.path.isfile(args.file):
            print(f"Error: File not found: {args.file}", file=sys.stderr)
            sys.exit(1)
        with open(args.file, encoding="utf-8") as f:
            content = f.read()

    if not content.strip():
        print("Error: Empty content.", file=sys.stderr)
        sys.exit(1)

    project_root = find_project_root()
    load_env(project_root)

    prompt = build_blind_prompt(content, args.question, args.context)
    response = call_api(prompt)
    findings = parse_findings(response["content"])

    if args.json:
        output = {
            "model": response["model"],
            "tokens": {"in": response["tokens_in"], "out": response["tokens_out"]},
            **findings,
        }
        print(json.dumps(output, indent=2, ensure_ascii=False))
    else:
        print(format_text(findings, response["model"], response["tokens_in"], response["tokens_out"]))


if __name__ == "__main__":
    main()
