#!/usr/bin/env bash
# Instrumented probe driver for context-isolation tests (F02-T09).
# Writes observed environment variable names to DIDIO_LOG_FILE as NDJSON.
# No model tokens spent — simulation stand-in only.
set -uo pipefail

python3 - "${DIDIO_LOG_FILE:?DIDIO_LOG_FILE required}" <<'PY'
import json, os, sys
entry = {
    "type": "system",
    "subtype": "probe-driver",
    "env_keys": sorted(os.environ.keys()),
}
with open(sys.argv[1], "a") as f:
    f.write(json.dumps(entry) + "\n")
PY
