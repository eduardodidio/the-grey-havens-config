#!/usr/bin/env python3
"""Tests for didio-events-lib (F01-T11).

Run: python3 bin/test_didio_events.py
"""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import importlib
events_lib = importlib.import_module("didio-events-lib")

FIXTURES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tests", "fixtures")
CLAUDE_FIXTURE = os.path.join(FIXTURES, "claude-stream.jsonl")
CODEX_FIXTURE = os.path.join(FIXTURES, "codex-json.jsonl")


def _legacy_count_tool_errors(path):
    """Pre-T11 behavior (didio-jsonl-errors.py): count tool_result + is_error=true."""
    n = 0
    with open(path) as f:
        for line in f:
            try:
                ev = json.loads(line)
            except Exception:
                continue
            content = (ev.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            for c in content:
                if isinstance(c, dict) and c.get("type") == "tool_result" and c.get("is_error"):
                    n += 1
    return n


class TestClaudeMapper(unittest.TestCase):
    def test_golden_count_matches_legacy(self):
        """AC3: Claude path is unchanged — error count matches pre-T11 logic."""
        legacy = _legacy_count_tool_errors(CLAUDE_FIXTURE)
        normalized = events_lib.count_tool_errors(CLAUDE_FIXTURE, "claude")
        self.assertEqual(legacy, 1)
        self.assertEqual(normalized, legacy)

    def test_tool_result_error_maps_to_error_kind(self):
        events = list(events_lib.iter_normalized_events(CLAUDE_FIXTURE, "claude"))
        errors = [e for e in events if e["kind"] == "error"]
        self.assertEqual(len(errors), 1)
        self.assertEqual(errors[0]["category"], "tool_result")
        self.assertTrue(errors[0]["is_error"])

    def test_result_event_maps_to_result_kind(self):
        events = list(events_lib.iter_normalized_events(CLAUDE_FIXTURE, "claude"))
        results = [e for e in events if e["kind"] == "result"]
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["text"], "Done.")
        self.assertEqual(results[0]["usage"], {"input_tokens": 100, "output_tokens": 50})

    def test_classify_success(self):
        self.assertEqual(events_lib.classify_last_result(CLAUDE_FIXTURE, "claude"), "success")


class TestCodexMapper(unittest.TestCase):
    def test_codex_error_item_maps_to_error_kind_unified_with_claude(self):
        """Happy path: a Codex error-ish item and a Claude tool_result error
        both unify to kind="error"."""
        codex_events = list(events_lib.iter_normalized_events(CODEX_FIXTURE, "codex"))
        codex_errors = [e for e in codex_events if e["kind"] == "error"]
        self.assertEqual(len(codex_errors), 1)
        self.assertEqual(codex_errors[0]["category"], "command_execution")

        claude_events = list(events_lib.iter_normalized_events(CLAUDE_FIXTURE, "claude"))
        claude_errors = [e for e in claude_events if e["kind"] == "error"]
        self.assertEqual(len(claude_errors), 1)

    def test_codex_count_tool_errors(self):
        self.assertEqual(events_lib.count_tool_errors(CODEX_FIXTURE, "codex"), 1)

    def test_codex_agent_message_maps_to_assistant(self):
        events = list(events_lib.iter_normalized_events(CODEX_FIXTURE, "codex"))
        assistant = [e for e in events if e["kind"] == "assistant"]
        self.assertEqual(len(assistant), 1)
        self.assertEqual(assistant[0]["text"], "Let me check that file.")

    def test_codex_event_with_no_analogue_degrades_to_raw(self):
        """Error scenario (AC4): an item type with no Claude analogue (e.g.
        'reasoning') degrades to kind='raw' instead of crashing."""
        events = list(events_lib.iter_normalized_events(CODEX_FIXTURE, "codex"))
        raw = [e for e in events if e["kind"] == "raw"]
        self.assertTrue(any(e["category"] == "reasoning" for e in raw))

    def test_codex_turn_completed_has_no_result_text(self):
        """Documented gap (AC4): turn.completed has no result text — degrades to None."""
        events = list(events_lib.iter_normalized_events(CODEX_FIXTURE, "codex"))
        results = [e for e in events if e["kind"] == "result"]
        self.assertEqual(len(results), 1)
        self.assertIsNone(results[0]["text"])

    def test_codex_rate_limit_classification_degrades_to_unknown(self):
        """Documented gap (AC4): no rate-limit reset analogue for Codex
        turn.completed (non-error) -> 'success', not a crash."""
        self.assertEqual(events_lib.classify_last_result(CODEX_FIXTURE, "codex"), "success")


class TestBoundaries(unittest.TestCase):
    def test_empty_log_is_tolerated(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".jsonl", delete=False) as f:
            path = f.name
        try:
            self.assertEqual(events_lib.count_tool_errors(path, "claude"), 0)
            self.assertEqual(events_lib.classify_last_result(path, "claude"), "unknown")
            self.assertEqual(list(events_lib.iter_normalized_events(path, "claude")), [])
        finally:
            os.unlink(path)

    def test_truncated_last_line_is_skipped(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".jsonl", delete=False) as f:
            f.write('{"type":"result","is_error":false,"result":"ok","usage":{}}\n')
            f.write('{"type":"assistant","message":{"content":[{"type":"text","tex')
            path = f.name
        try:
            events = list(events_lib.iter_normalized_events(path, "claude"))
            self.assertEqual(len(events), 1)
            self.assertEqual(events[0]["kind"], "result")
        finally:
            os.unlink(path)

    def test_unknown_provider_falls_back_to_claude(self):
        events = list(events_lib.iter_normalized_events(CLAUDE_FIXTURE, "unknown-provider"))
        self.assertTrue(any(e["kind"] == "result" for e in events))


if __name__ == "__main__":
    unittest.main()
