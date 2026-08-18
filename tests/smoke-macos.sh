#!/usr/bin/env bash
# macOS smoke test for setup-local-pi.sh.
#
# Runs the script on THIS host with stubbed `llama`/`pi` binaries and a
# restricted PATH (no /opt/homebrew, /usr/local, etc.), so real binaries can
# never be reached. HOME is pointed at a temp dir and the model "download" runs
# against the stubs, so nothing is installed or changed on the host.
#
# Uses `expect` to drive the interactive prompts, because macOS's BSD `script`
# cannot feed a pty from a pipe.
#
# Exits 0 on success, 1 on failure, or 0 (SKIP) if not macOS / no expect.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/setup-local-pi.sh"
STUBS="$ROOT/tests/stubs/bin"

if [ "$(uname -s)" != "Darwin" ]; then echo "SKIP: not macOS"; exit 0; fi
if ! command -v expect >/dev/null 2>&1; then echo "SKIP: expect not installed"; exit 0; fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export LLAMA_STUB_LOG="$TMP/llama-stub.log"
export PI_STUB_LOG="$TMP/pi-stub.log"
export HOME="$TMP/home"; mkdir -p "$HOME"
export PATH="$STUBS:/usr/bin:/bin:/usr/sbin:/sbin"
export SCRIPT

EXPECT_SCRIPT="$TMP/drive.exp"
cat > "$EXPECT_SCRIPT" <<'EXP'
set timeout 60
log_user 1
spawn bash $env(SCRIPT)
expect -re "Choose 1, 2 or 3"
send "1\r"
expect -re "Download the model now"
send "y\r"
expect -re "Install the pi-llama plugin now"
send "y\r"
expect -re "Done"
expect eof
catch wait result
exit [lindex $result 3]
EXP

echo "==> running setup-local-pi.sh (stubbed, temp HOME)"
OUT=$(expect -f "$EXPECT_SCRIPT" 2>&1); CODE=$?
echo "$OUT"
echo "---- llama stub calls ----"; cat "$LLAMA_STUB_LOG" 2>/dev/null
echo "---- pi stub calls ----"; cat "$PI_STUB_LOG" 2>/dev/null

PASS=1
for pat in \
  "Detected OS: macos" \
  "llama is already installed" \
  "Step 1 of 4: llama.cpp" \
  "Step 2 of 4: choose a model" \
  "Step 3 of 4: pi coding agent" \
  "Step 4 of 4: connect pi to your local model" \
  "Model downloaded and cached." \
  "pi-llama plugin installed." \
  "Done"; do
  if ! grep -qF "$pat" <<<"$OUT"; then echo "MISSING: $pat"; PASS=0; fi
done
# Stubs must have been invoked — proves the real binaries were never used.
grep -qF "llama cli -hf" <<<"$OUT" || { echo "MISSING: stub 'llama cli -hf' was not invoked"; PASS=0; }
grep -qF "pi install git:github.com/huggingface/pi-llama" <<<"$OUT" || { echo "MISSING: stub 'pi install' was not invoked"; PASS=0; }
[ "$CODE" -eq 0 ] || { echo "MISSING: expect exited non-zero ($CODE)"; PASS=0; }

if [ "$PASS" = 1 ]; then
  echo "SMOKE (macos) PASS"
  exit 0
else
  echo "SMOKE (macos) FAIL"
  exit 1
fi
