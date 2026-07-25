#!/bin/bash
# setup-local-pi.sh — interactive macOS setup for a local coding agent:
#   Homebrew -> llama.cpp -> GGUF model -> pi coding agent -> pi models.json
#
# Nothing is installed or changed without an explicit "y" from you.

set -u
set -o pipefail

BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; RST=$'\033[0m'

say()  { printf '%s\n' "$*"; }
info() { printf '%s\n' "${DIM}    $*${RST}"; }
head_() { printf '\n%s\n' "${BOLD}==> $*${RST}"; }
ok()   { printf '%s\n' "${GRN}    OK: $*${RST}"; }
warn() { printf '%s\n' "${YEL}    ! $*${RST}"; }
die()  { printf '%s\n' "${RED}    ERROR: $*${RST}" >&2; exit 1; }

# ask "question" -> returns 0 for yes, 1 for no. Defaults to no on empty input.
ask() {
  local q="$1" reply
  printf '\n%s [y/N] ' "${BOLD}${q}${RST}"
  read -r reply </dev/tty || reply=""
  case "$reply" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

require_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "This script is for macOS only."
}

# ---------------------------------------------------------------------------
say "${BOLD}Local coding agent setup${RST}"
say "This script will walk through four steps and ask permission before each one:"
say "  1. Homebrew        — the package manager macOS doesn't ship with"
say "  2. llama.cpp       — runs AI models on your own Mac (gives you 'llama-server')"
say "  3. a model         — you pick one; it's a multi-GB download from Hugging Face"
say "  4. pi              — a terminal coding agent, pointed at your local model"
say "                       (via its own installer, which also handles Node.js for you)"
say ""
say "${DIM}Nothing runs until you type 'y'. Ctrl-C quits at any time.${RST}"

require_macos

# --- Step 1: Homebrew -------------------------------------------------------
head_ "Step 1 of 4: Homebrew"

if ! command -v brew >/dev/null 2>&1; then
  # brew may be installed but not yet on PATH in this shell
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$p" ] && eval "$("$p" shellenv)" && break
  done
fi

if command -v brew >/dev/null 2>&1; then
  ok "Homebrew is already installed ($(brew --version | head -n1))."
else
  say "Homebrew was not found."
  info "It installs to /opt/homebrew (Apple Silicon) or /usr/local (Intel)."
  info "The installer is run with sudo and will ask for your Mac password."
  info "Command: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  if ask "Install Homebrew now?"; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
      || die "Homebrew install failed."
    for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      [ -x "$p" ] && eval "$("$p" shellenv)" && break
    done
    command -v brew >/dev/null 2>&1 || die "Homebrew installed but 'brew' is not on PATH. Open a new terminal and re-run this script."
    ok "Homebrew installed."
  else
    die "Homebrew is required for the rest of this script. Nothing was changed."
  fi
fi

# --- Step 2: llama.cpp ------------------------------------------------------
head_ "Step 2 of 4: llama.cpp"

if command -v llama-server >/dev/null 2>&1; then
  ok "llama-server is already installed ($(llama-server --version 2>&1 | head -n1))."
else
  say "llama.cpp was not found."
  info "The Homebrew formula is named 'llama.cpp'; it installs 'llama-cli' and 'llama-server'."
  info "llama-server exposes an OpenAI-compatible API on your machine — that's what pi talks to."
  info "Command: brew install llama.cpp"
  if ask "Install llama.cpp now?"; then
    brew install llama.cpp || die "brew install llama.cpp failed."
    ok "llama.cpp installed."
  else
    die "llama.cpp is required. Nothing further was changed."
  fi
fi

# --- Step 3: pick and download a model --------------------------------------
head_ "Step 3 of 4: choose a model"

# Where llama.cpp keeps downloaded weights. Recent builds use the standard
# Hugging Face hub cache; older ones used their own directory. Both are checked,
# in the same precedence order llama.cpp itself uses.
CACHE_ROOTS=""
add_cache_root() {
  [ -n "${1:-}" ] || return 0
  [ -d "$1" ] || return 0
  case " $CACHE_ROOTS " in *" $1 "*) return 0 ;; esac
  CACHE_ROOTS="$CACHE_ROOTS $1"
}
add_cache_root "${LLAMA_CACHE:-}"
add_cache_root "${HF_HUB_CACHE:-}"
add_cache_root "${HUGGINGFACE_HUB_CACHE:-}"
[ -n "${HF_HOME:-}" ] && add_cache_root "$HF_HOME/hub"
add_cache_root "$HOME/.cache/huggingface/hub"
add_cache_root "$HOME/.cache/llama.cpp"
add_cache_root "$HOME/Library/Caches/llama.cpp"

# find_cached <org> <repo> <legacy-glob-fragment>
# Prints "<human size>\t<path>" of the first match found, or nothing.
# Two layouts are searched: the Hugging Face one (a models--org--repo directory)
# and the older flat one (a .gguf file whose name contains the model name).
find_cached() {
  fc_org="$1"; fc_repo="$2"; fc_frag="$3"
  for root in $CACHE_ROOTS; do
    hf_dir="$root/models--${fc_org}--${fc_repo}"
    if [ -d "$hf_dir" ]; then
      printf '%s\t%s\n' "$(du -sh "$hf_dir" 2>/dev/null | cut -f1)" "$hf_dir"
      return 0
    fi
    hit=$(find "$root" -maxdepth 3 -type f -iname "*${fc_frag}*.gguf" 2>/dev/null | head -n1)
    if [ -n "$hit" ]; then
      printf '%s\t%s\n' "$(du -sh "$hit" 2>/dev/null | cut -f1)" "$hit"
      return 0
    fi
  done
  return 1
}

# status_line <org> <repo> <glob-fragment> <approx size>
# Renders either an "already on disk" note or the download size.
status_line() {
  if sl_found=$(find_cached "$1" "$2" "$3"); then
    printf '%s' "${GRN}[on disk: $(printf '%s' "$sl_found" | cut -f1)]${RST}"
  else
    printf '%s' "${DIM}[not downloaded, ~$4]${RST}"
  fi
}

# Download the weights WITHOUT dropping the user into an interactive chat.
#
# llama-cli auto-enables conversation mode whenever the model ships a chat
# template, which every model offered here does. -no-cnv is supposed to suppress
# that but is unreliable across builds, so three independent guards are used:
#   -st / --single-turn  documented to be non-interactive when -p is supplied
#   -no-cnv              legacy flag, still honoured by most builds
#   < /dev/null          the backstop: any prompt that appears gets EOF and exits
# Flags are probed against --help first so an older or newer llama-cli never
# aborts with "unknown argument".
fetch_model() {
  fm_repo="$1"
  fm_help=$(llama-cli --help 2>&1 || true)
  fm_flags="-n 1"
  case "$fm_help" in *-no-cnv*)       fm_flags="$fm_flags -no-cnv" ;; esac
  case "$fm_help" in *--single-turn*) fm_flags="$fm_flags -st" ;; esac
  case "$fm_help" in *--no-warmup*)   fm_flags="$fm_flags --no-warmup" ;; esac

  info "Running: llama-cli -hf $fm_repo -p ok $fm_flags < /dev/null"
  # stdout is discarded (the single generated token); stderr is kept so the
  # download progress bar stays visible.
  llama-cli -hf "$fm_repo" -p "ok" $fm_flags </dev/null >/dev/null
}

say "Checking which models you already have..."
S1=$(status_line "ggml-org" "gemma-4-E4B-it-GGUF"            "gemma-4-E4B"            "4.6 GB")
S2=$(status_line "unsloth"  "gemma-4-26B-A4B-it-qat-GGUF"    "gemma-4-26B-A4B-it-qat" "15 GB")
S3=$(status_line "unsloth"  "Qwen3.5-35B-A3B-GGUF"           "Qwen3.5-35B-A3B"        "20 GB")

say ""
say "Models are downloaded from Hugging Face and cached on disk. Re-running this"
say "script never re-downloads something you already have."
say "Rule of thumb: the model should fit comfortably inside your RAM."
say ""
say "  ${BOLD}1)${RST} Gemma 4 E4B (Q4_0)             8B params, small and fast     ${S1}"
say "     ggml-org/gemma-4-E4B-it-GGUF:Q4_0"
say "  ${BOLD}2)${RST} Gemma 4 26B-A4B QAT            MoE, 4B active — fast for its size  ${S2}"
say "     unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL"
say "  ${BOLD}3)${RST} Qwen3.5 35B-A3B (Q4_K_M)       MoE, 3B active, strong at code     ${S3}"
say "     unsloth/Qwen3.5-35B-A3B-GGUF:Q4_K_M"
say ""
info "Your Mac reports $(( $(sysctl -n hw.memsize) / 1073741824 )) GB of RAM."
if [ -n "$CACHE_ROOTS" ]; then
  info "Cache directories searched:$CACHE_ROOTS"
else
  info "No model cache directory exists yet — nothing has been downloaded before."
fi

MODEL_REPO=""; MODEL_ALIAS=""; MODEL_LABEL=""; MODEL_CTX=32768
MODEL_ORG=""; MODEL_NAME=""; MODEL_FRAG=""
while [ -z "$MODEL_REPO" ]; do
  printf '%s' "${BOLD}Choose 1, 2 or 3 (or q to quit): ${RST}"
  read -r choice </dev/tty || choice="q"
  case "$choice" in
    1) MODEL_REPO="ggml-org/gemma-4-E4B-it-GGUF:Q4_0";              MODEL_ALIAS="gemma-4-e4b";         MODEL_LABEL="Gemma 4 E4B"
       MODEL_ORG="ggml-org"; MODEL_NAME="gemma-4-E4B-it-GGUF";         MODEL_FRAG="gemma-4-E4B" ;;
    2) MODEL_REPO="unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL";  MODEL_ALIAS="gemma-4-26b-a4b-qat"; MODEL_LABEL="Gemma 4 26B-A4B QAT"
       MODEL_ORG="unsloth"; MODEL_NAME="gemma-4-26B-A4B-it-qat-GGUF"; MODEL_FRAG="gemma-4-26B-A4B-it-qat" ;;
    3) MODEL_REPO="unsloth/Qwen3.5-35B-A3B-GGUF:Q4_K_M";             MODEL_ALIAS="qwen3.5-35b-a3b";     MODEL_LABEL="Qwen3.5 35B-A3B"
       MODEL_ORG="unsloth"; MODEL_NAME="Qwen3.5-35B-A3B-GGUF";        MODEL_FRAG="Qwen3.5-35B-A3B" ;;
    q|Q) say "Nothing downloaded. Exiting."; exit 0 ;;
    *) warn "Please type 1, 2, 3 or q." ;;
  esac
done

say ""
say "Selected: ${BOLD}${MODEL_LABEL}${RST}  (${MODEL_REPO})"

if CACHED=$(find_cached "$MODEL_ORG" "$MODEL_NAME" "$MODEL_FRAG"); then
  ok "Already on disk: $(printf '%s' "$CACHED" | cut -f2)  ($(printf '%s' "$CACHED" | cut -f1))"
  info "Skipping the download. This is the normal path when re-running the script."
  info "Note: this check finds the model repository, but cannot always confirm which"
  info "compression level (quant) is present, or that the files are complete."
  if ask "Verify it anyway? (Fast if complete; resumes if a previous run was interrupted.)"; then
    fetch_model "$MODEL_REPO" || die "Verification failed."
    ok "Verified."
  fi
else
  info "This fetches the weights into the cache and exits on its own — it will NOT"
  info "drop you into a chat session, and needs no input from you while it runs."
  info "It can take a long time. The exact command is printed below."
  info "If it is interrupted, re-run this script — it resumes rather than starting over."
  if ask "Download the model now? (Say n to skip — llama-server will fetch it on first run.)"; then
    fetch_model "$MODEL_REPO" || die "Model download failed."
    ok "Model downloaded and cached."
  else
    warn "Skipped. The first 'llama-server' run will download it."
  fi
fi

# --- Step 4a: pi ------------------------------------------------------------
head_ "Step 4 of 4: pi coding agent"

# pi's installer handles Node.js itself: it requires Node >= 22.19.0 and, if that
# is missing, offers to install it via Homebrew (which now exists thanks to step 1)
# or as a checksum-verified standalone build under ~/.local/share/pi-node.
# So there is no separate Node step here -- just a heads-up if yours is too old.
if command -v node >/dev/null 2>&1; then
  NODE_V=$(node --version)
  if node -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>22||(a===22&&b>=19)?0:1)' 2>/dev/null; then
    ok "Node.js $NODE_V meets pi's requirement (>= 22.19.0)."
  else
    warn "Node.js $NODE_V is older than pi's minimum of 22.19.0."
    info "pi's installer will offer to upgrade it via Homebrew. Accept that prompt."
  fi
else
  info "Node.js is not installed. pi's installer will offer to install it via Homebrew."
fi

if command -v pi >/dev/null 2>&1; then
  ok "pi is already installed at $(command -v pi)."
  info "Running the installer again would offer to reinstall or uninstall; skipping."
else
  say ""
  say "pi is not installed."
  info "Command: curl -fsSL https://pi.dev/install.sh | sh"
  info "The installer runs a short animation, checks Node, shows you the exact npm"
  info "command it will run, and asks y / n (and 'u' to uninstall) before doing anything."
  info "It installs to npm's global prefix if writable, otherwise to ~/.local, and will"
  info "offer to add that bin directory to your shell profile."
  info "You are trusting the pi.dev server to serve an honest script, same as Homebrew."
  info "To read it first, in another window:  curl -fsSL https://pi.dev/install.sh | less"
  if ask "Run pi's installer now?"; then
    # The installer reads its own prompts from /dev/tty, so piping to sh is safe.
    curl -fsSL https://pi.dev/install.sh | sh || die "pi installer exited with an error."

    # It installs to npm's global prefix, or ~/.local when that is not writable.
    # Node may also have landed in a standalone dir not yet on this shell's PATH.
    if ! command -v pi >/dev/null 2>&1; then
      for d in "$(npm prefix -g 2>/dev/null)/bin" "$HOME/.local/bin" "$HOME/.local/share/pi-node/current/bin"; do
        if [ -x "$d/pi" ]; then PATH="$d:$PATH"; export PATH; break; fi
      done
    fi

    if command -v pi >/dev/null 2>&1; then
      ok "pi installed at $(command -v pi)."
    else
      warn "pi was not found afterwards."
      info "Either you chose 'n' (do nothing) at the installer's menu, or pi landed in a"
      info "directory this shell does not search. Check with: ls ~/.local/bin/pi"
      info "The remaining steps still run; they only write config files."
    fi
  else
    warn "Skipped. llama.cpp and the model are still set up; you can install pi later."
  fi
fi

# --- Step 4c: launcher script ----------------------------------------------
LAUNCHER="$HOME/bin/llama-serve-${MODEL_ALIAS}.sh"
mkdir -p "$HOME/bin"
say ""
say "Next, a small launcher script that starts llama-server with your model."
info "It will be written to: $LAUNCHER"
info "The --alias flag pins the model's API name to '${MODEL_ALIAS}' so pi's config always matches."
if ask "Write the launcher script?"; then
  cat > "$LAUNCHER" <<EOF
#!/bin/bash
# Starts llama-server for ${MODEL_LABEL}. Leave this running while you use pi.
exec llama-server \\
  -hf ${MODEL_REPO} \\
  --alias ${MODEL_ALIAS} \\
  --host 127.0.0.1 --port 8080 \\
  -ngl 99 \\
  -c ${MODEL_CTX} \\
  -fa on \\
  --jinja
EOF
  chmod +x "$LAUNCHER"
  ok "Wrote $LAUNCHER"
else
  warn "Skipped launcher script."
fi

# --- Step 4d: pi models.json -----------------------------------------------
PI_DIR="$HOME/.pi/agent"
PI_MODELS="$PI_DIR/models.json"
mkdir -p "$PI_DIR"

say ""
say "Finally, register the local server with pi."
info "File: $PI_MODELS"
info "This adds a provider 'llama-cpp' at http://localhost:8080/v1 with model id '${MODEL_ALIAS}'."
info "Existing providers and models in that file are preserved; a .bak backup is made."
if ask "Update pi's models.json?"; then
  [ -f "$PI_MODELS" ] && cp "$PI_MODELS" "${PI_MODELS}.bak.$(date +%Y%m%d%H%M%S)" && info "Backup created."

  if command -v node >/dev/null 2>&1; then
    MERGE_CMD="node -e"
  elif command -v python3 >/dev/null 2>&1; then
    MERGE_CMD="python3 -c"
  else
    die "Need node or python3 to safely merge JSON. Neither was found."
  fi

  if [ "$MERGE_CMD" = "node -e" ]; then
  MODEL_ALIAS="$MODEL_ALIAS" MODEL_LABEL="$MODEL_LABEL" MODEL_CTX="$MODEL_CTX" PI_MODELS="$PI_MODELS" \
  node -e '
    const fs = require("fs");
    const path = process.env.PI_MODELS;
    let cfg = {};
    if (fs.existsSync(path)) {
      try { cfg = JSON.parse(fs.readFileSync(path, "utf8")); }
      catch (e) { console.error("Existing models.json is not valid JSON: " + e.message); process.exit(1); }
    }
    cfg.providers = cfg.providers || {};
    const p = cfg.providers["llama-cpp"] || {};
    p.baseUrl = "http://localhost:8080/v1";
    p.api     = "openai-completions";
    p.apiKey  = p.apiKey || "none";
    p.models  = Array.isArray(p.models) ? p.models : [];
    const entry = {
      id: process.env.MODEL_ALIAS,
      name: process.env.MODEL_LABEL + " (local)",
      contextWindow: Number(process.env.MODEL_CTX),
      maxTokens: 8192,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }
    };
    const i = p.models.findIndex(m => m && m.id === entry.id);
    if (i >= 0) p.models[i] = entry; else p.models.push(entry);
    cfg.providers["llama-cpp"] = p;
    fs.writeFileSync(path, JSON.stringify(cfg, null, 2) + "\n");
  ' || die "Failed to write $PI_MODELS"
  else
  MODEL_ALIAS="$MODEL_ALIAS" MODEL_LABEL="$MODEL_LABEL" MODEL_CTX="$MODEL_CTX" PI_MODELS="$PI_MODELS" \
  python3 -c '
import json, os, sys
path = os.environ["PI_MODELS"]
cfg = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            cfg = json.load(f)
    except Exception as e:
        sys.exit("Existing models.json is not valid JSON: %s" % e)
cfg.setdefault("providers", {})
p = cfg["providers"].get("llama-cpp", {})
p["baseUrl"] = "http://localhost:8080/v1"
p["api"] = "openai-completions"
p.setdefault("apiKey", "none")
if not isinstance(p.get("models"), list):
    p["models"] = []
entry = {
    "id": os.environ["MODEL_ALIAS"],
    "name": os.environ["MODEL_LABEL"] + " (local)",
    "contextWindow": int(os.environ["MODEL_CTX"]),
    "maxTokens": 8192,
    "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
}
for i, m in enumerate(p["models"]):
    if isinstance(m, dict) and m.get("id") == entry["id"]:
        p["models"][i] = entry
        break
else:
    p["models"].append(entry)
cfg["providers"]["llama-cpp"] = p
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
' || die "Failed to write $PI_MODELS"
  fi
  ok "Updated $PI_MODELS"
else
  warn "Skipped. You can add the provider yourself later — see https://pi.dev/docs/latest/models"
fi

# --- Done -------------------------------------------------------------------
head_ "Done"
say "To use it, open ${BOLD}two${RST} terminal windows:"
say ""
say "  Terminal 1 (leave running):   ${BOLD}${LAUNCHER}${RST}"
say "  Terminal 2:                   ${BOLD}cd /your/project && pi${RST}"
say ""
say "Inside pi, press ${BOLD}Ctrl+L${RST} or type ${BOLD}/model${RST} and pick '${MODEL_ALIAS}'."
say ""
info "If '${MODEL_ALIAS}' does not appear in /model, pi has no saved credential for the"
info "provider. Run: pi --api-key none   (local servers ignore the key; pi just wants one.)"
info "Check the server is alive with: curl http://localhost:8080/v1/models"
