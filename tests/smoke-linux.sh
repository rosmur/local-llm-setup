#!/usr/bin/env bash
# Linux smoke test for setup-local-llm.sh.
#
# Runs the script inside a clean Alpine container with stubbed `llama` and `pi`
# binaries on a restricted PATH, so the script sees them "already installed" and
# walks all four steps WITHOUT installing or downloading anything real.
#
# The container runs with --network none as belt-and-braces: even if a prompt
# were answered unexpectedly, no real install or download could succeed.
#
# Exits 0 on success, 1 on failure, or 0 (SKIP) if docker is unavailable.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/setup-local-llm.sh"
STUBS="$ROOT/tests/stubs/bin"
IMG="local-llm-setup-smoke:latest"

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker not available or daemon not running"
  exit 0
fi

echo "==> building smoke image"
docker build -q -t "$IMG" -f "$ROOT/tests/Dockerfile" "$ROOT" >/dev/null \
  || { echo "FAIL: docker build"; exit 1; }

echo "==> running setup-local-llm.sh (stubbed, --network none)"
OUT=$(docker run --rm --network none \
  -v "$SCRIPT:/setup.sh:ro" \
  -v "$STUBS:/stubs:ro" \
  "$IMG" bash -c '
    export PATH="/stubs:/usr/bin:/bin:/usr/sbin:/sbin"
    export LLAMA_STUB_LOG=/tmp/llama-stub.log
    export PI_STUB_LOG=/tmp/pi-stub.log
    # model=1, approve stub download, approve stub plugin install
    printf "1\ny\ny\nn\n" | script -q -c "bash /setup.sh" /dev/null
    echo "SCRIPT_EXIT=$?"
    echo "---- llama stub calls ----"; cat "$LLAMA_STUB_LOG" 2>/dev/null
    echo "---- pi stub calls ----"; cat "$PI_STUB_LOG" 2>/dev/null
  ' 2>&1)
echo "$OUT"

PASS=1
for pat in \
  "Detected OS: linux" \
  "llama is already installed" \
  "Step 1 of 4: llama.cpp" \
  "Step 2 of 4: choose a model" \
  "Step 3 of 4: pi coding agent" \
  "Step 4 of 4: connect pi to your local model" \
  "Model downloaded and cached." \
  "pi-llama plugin installed." \
  "Done" \
  "SCRIPT_EXIT=0"; do
  if ! grep -qF "$pat" <<<"$OUT"; then echo "MISSING: $pat"; PASS=0; fi
done
# Stubs must have been invoked — proves the real binaries were never used.
grep -qF "llama cli -hf" <<<"$OUT" || { echo "MISSING: stub 'llama cli -hf' was not invoked"; PASS=0; }
grep -qF "pi install git:github.com/huggingface/pi-llama" <<<"$OUT" || { echo "MISSING: stub 'pi install' was not invoked"; PASS=0; }

if [ "$PASS" = 1 ]; then
  echo "SMOKE (linux) PASS"
  exit 0
else
  echo "SMOKE (linux) FAIL"
  exit 1
fi
