#!/usr/bin/env python3
"""didio-events-lib — per-provider JSONL/event normalization (F01-T11).

Translates raw per-agent JSONL events (Claude `stream-json` or Codex
`exec --json`) into a small common internal shape so that error-detection,
rate-limit classification, and the dashboard renderer can work the same way
regardless of which provider produced the log.

Common event shape (dict):
    {
        "kind":     "assistant" | "tool" | "result" | "error" | "usage" | "raw",
        "category": optional str, e.g. "tool_use" | "tool_result" | "item" | ...
        "is_error": bool,
        "text":     str | None,   # best-effort human-readable text
        "usage":    dict | None,  # token usage, if present
        "raw":      dict,         # the original, unmodified event
    }

Provider mappers:
    - `claude` mapper is a thin pass that preserves today's fields/behavior
      exactly (golden — see test_didio_events.py).
    - `codex` mapper translates Codex `exec --json` events
      (`item.completed`, `turn.completed`, `turn.failed`, `token_count`, ...)
      to the same shape. Events with no Claude analogue degrade to
      `kind: "raw"` instead of crashing (AC4).

Known gaps (documented per AC4):
    - Codex has no rate-limit reset timestamp analogue. Rate-limit
      classification for `codex` always returns "unknown".
    - Codex `turn.completed`/`turn.failed` carry no `result` text; the
      normalized `text` field is `None` ("n/a") for those events.
"""
import json


# ── Claude mapper ────────────────────────────────────────────────────────
def _map_claude_event(ev):
    """Map one Claude stream-json event to one or more common events."""
    etype = ev.get("type")

    if etype == "assistant" or etype == "user":
        message = ev.get("message") or {}
        content = message.get("content")
        if not isinstance(content, list):
            return [{"kind": "raw", "category": etype, "is_error": False, "text": None, "usage": None, "raw": ev}]

        out = []
        for c in content:
            if not isinstance(c, dict):
                continue
            ctype = c.get("type")
            if ctype == "tool_use":
                out.append({
                    "kind": "tool",
                    "category": "tool_use",
                    "is_error": False,
                    "text": c.get("name"),
                    "usage": None,
                    "raw": ev,
                })
            elif ctype == "tool_result":
                is_error = bool(c.get("is_error"))
                out.append({
                    "kind": "error" if is_error else "tool",
                    "category": "tool_result",
                    "is_error": is_error,
                    "text": c.get("content") if isinstance(c.get("content"), str) else None,
                    "usage": None,
                    "raw": ev,
                })
            elif ctype == "text":
                out.append({
                    "kind": "assistant",
                    "category": "text",
                    "is_error": False,
                    "text": c.get("text"),
                    "usage": None,
                    "raw": ev,
                })
            else:
                out.append({"kind": "raw", "category": ctype, "is_error": False, "text": None, "usage": None, "raw": ev})
        return out or [{"kind": "raw", "category": etype, "is_error": False, "text": None, "usage": None, "raw": ev}]

    if etype == "result":
        is_error = bool(ev.get("is_error", False))
        return [{
            "kind": "result",
            "category": "result",
            "is_error": is_error,
            "text": ev.get("result"),
            "usage": ev.get("usage"),
            "raw": ev,
            "api_error_status": ev.get("api_error_status"),
        }]

    return [{"kind": "raw", "category": etype, "is_error": False, "text": None, "usage": None, "raw": ev}]


# ── Codex mapper ─────────────────────────────────────────────────────────
_CODEX_ERROR_ITEM_TYPES = {"error"}
_CODEX_TOOL_ITEM_TYPES = {"command_execution", "mcp_tool_call", "file_change", "web_search", "reasoning"}


def _map_codex_event(ev):
    """Map one Codex `exec --json` event to one or more common events.

    Events with no Claude analogue degrade to kind="raw" (AC4).
    """
    etype = ev.get("type")

    if etype == "item.completed":
        item = ev.get("item") or {}
        item_type = item.get("type")

        if item_type == "agent_message":
            return [{
                "kind": "assistant",
                "category": "text",
                "is_error": False,
                "text": item.get("text"),
                "usage": None,
                "raw": ev,
            }]

        if item_type in _CODEX_ERROR_ITEM_TYPES:
            return [{
                "kind": "error",
                "category": "item",
                "is_error": True,
                "text": item.get("text") or item.get("message"),
                "usage": None,
                "raw": ev,
            }]

        if item_type in _CODEX_TOOL_ITEM_TYPES:
            status = item.get("status")
            exit_code = item.get("exit_code")
            is_error = status == "failed" or (isinstance(exit_code, int) and exit_code != 0)
            return [{
                "kind": "error" if is_error else "tool",
                "category": item_type,
                "is_error": is_error,
                "text": item.get("text"),
                "usage": None,
                "raw": ev,
            }]

        return [{"kind": "raw", "category": item_type or "item.completed", "is_error": False, "text": None, "usage": None, "raw": ev}]

    if etype == "turn.completed":
        # No Claude-style result text/api_error_status analogue (AC4 gap).
        return [{
            "kind": "result",
            "category": "result",
            "is_error": False,
            "text": None,
            "usage": (ev.get("usage") or {}).get("token_count") if isinstance(ev.get("usage"), dict) else None,
            "raw": ev,
            "api_error_status": None,
        }]

    if etype == "turn.failed":
        error = ev.get("error") or {}
        return [{
            "kind": "result",
            "category": "result",
            "is_error": True,
            "text": error.get("message"),
            "usage": None,
            "raw": ev,
            "api_error_status": None,
        }]

    if etype == "token_count":
        return [{
            "kind": "usage",
            "category": "token_count",
            "is_error": False,
            "text": None,
            "usage": ev.get("info"),
            "raw": ev,
        }]

    return [{"kind": "raw", "category": etype, "is_error": False, "text": None, "usage": None, "raw": ev}]


_MAPPERS = {
    "claude": _map_claude_event,
    "codex": _map_codex_event,
}


def normalize_event(ev, provider="claude"):
    """Map one raw event dict to a list of common-shape event dicts.

    Unknown providers fall back to the `claude` mapper (today's default
    behavior, AC3).
    """
    mapper = _MAPPERS.get(provider, _MAPPERS["claude"])
    return mapper(ev)


def iter_normalized_events(path, provider="claude"):
    """Yield common-shape events for every valid JSON line in `path`.

    Empty lines and lines that fail to parse (e.g. a truncated final line)
    are skipped silently.
    """
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except Exception:
                continue
            if not isinstance(ev, dict):
                continue
            for normalized in normalize_event(ev, provider):
                yield normalized


def count_tool_errors(path, provider="claude"):
    """Count normalized tool-result errors in a JSONL log file.

    For `provider="claude"` this is golden-equivalent to the existing
    `didio-jsonl-errors.py` (`tool_result` + `is_error=true`).
    """
    n = 0
    try:
        for ev in iter_normalized_events(path, provider):
            if ev["kind"] == "error" and ev.get("category") in ("tool_result", "item", "command_execution", "mcp_tool_call", "file_change", "web_search"):
                n += 1
    except Exception:
        pass
    return n


def classify_last_result(path, provider="claude"):
    """Classify the last `result`-kind event: rate_limit|real_error|success|unknown.

    Known gap (AC4): Codex `turn.completed`/`turn.failed` carry no
    rate-limit reset text, so `codex` logs always classify as
    "unknown" unless `turn.failed` with a recognizable rate-limit message.
    """
    last_result = None
    try:
        for ev in iter_normalized_events(path, provider):
            if ev["kind"] == "result":
                last_result = ev
    except Exception:
        return "unknown"

    if last_result is None:
        return "unknown"

    if not last_result.get("is_error"):
        return "success"

    text = str(last_result.get("text") or "")
    api_status = str(last_result.get("api_error_status") or "")
    if "hit your limit" in text or "rate_limit" in text or api_status == "429":
        return "rate_limit"

    if provider == "codex" and last_result.get("api_error_status") is None:
        # No reset-time analogue available — degrade per AC4.
        return "real_error" if text else "unknown"

    return "real_error"
