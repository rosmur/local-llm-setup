#!/bin/bash
# setup-local-pi.sh — interactive setup for a local coding agent:
#   llama.cpp -> GGUF model -> pi coding agent -> connect to local model
#
# Nothing is installed or changed without an explicit "y" from you.
#   macOS:            Homebrew or the official direct installer
#   Linux / Windows:  official direct installers only (no Homebrew)

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
# ask_y "question" -> returns 0 for yes, 1 for no. Defaults to yes on empty input.
ask_y() {
  local q="$1" reply
  printf '\n%s [Y/n] ' "${BOLD}${q}${RST}"
  read -r reply </dev/tty || reply=""
  case "$reply" in [nN]|[nN][oO]) return 1 ;; *) return 0 ;; esac
}

# --- OS detection -----------------------------------------------------------
detect_os() {
  case "$(uname -s)" in
    Darwin)               OS="macos" ;;
    Linux)                OS="linux" ;;
    MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
    *) die "Unsupported OS: $(uname -s). Supported: macOS, Linux, Windows." ;;
  esac
}

# system_ram_gb -> total RAM in GB, or empty if it can't be determined.
system_ram_gb() {
  case "$OS" in
    macos)   sysctl -n hw.memsize 2>/dev/null ;;
    linux)   awk '/MemTotal/{print $2*1024}' /proc/meminfo 2>/dev/null ;;
    windows) return ;;
  esac | awk '{printf "%.0f", $1/1073741824}'
}

# ---------------------------------------------------------------------------
say "${BOLD}Local coding agent setup${RST}"
say "This script will walk through four steps and ask permission before each one:"
say "  1. llama.cpp       — runs AI models on your machine (gives you 'llama')"
say "  2. a model         — you pick one; it's a multi-GB download from Hugging Face"
say "  3. pi              — a terminal coding agent"
say "  4. connect         — pi-llama plugin so pi auto-discovers your model"
say ""
say "${DIM}Nothing runs until you type 'y'. Ctrl-C quits at any time.${RST}"

detect_os
say ""
info "Detected OS: $OS"

# --- Step 1: llama.cpp ------------------------------------------------------
head_ "Step 1 of 4: llama.cpp"

# install_llama_direct — the official cross-platform installer (no Homebrew).
install_llama_direct() {
  info "Command: curl -LsSf https://llama.app/install.sh | sh"
  if ask "Install llama.cpp with the official direct installer?"; then
    curl -LsSf https://llama.app/install.sh | sh || die "llama.cpp direct install failed."
    if ! command -v llama >/dev/null 2>&1; then
      for d in "$HOME/.local/bin" "$HOME/bin"; do
        [ -x "$d/llama" ] && PATH="$d:$PATH" && export PATH && break
      done
    fi
    command -v llama >/dev/null 2>&1 || die "llama installed but 'llama' is not on PATH. Open a new terminal and re-run this script."
    ok "llama.cpp installed."
  else
    die "llama.cpp is required. Nothing was changed."
  fi
}

if command -v llama >/dev/null 2>&1; then
  ok "llama is already installed ($(llama --version 2>&1 | head -n1))."
else
  say "llama.cpp was not found."

  if [ "$OS" = "macos" ]; then
    # Homebrew may be installed but not yet on PATH in this shell
    if ! command -v brew >/dev/null 2>&1; then
      for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [ -x "$p" ] && eval "$("$p" shellenv)" && break
      done
    fi

    if command -v brew >/dev/null 2>&1; then
      say "Homebrew is installed, so you can install llama.cpp two ways:"
      info "  1) Homebrew (default):  brew install llama.cpp"
      info "  2) Direct installer:    curl -LsSf https://llama.app/install.sh | sh"
      if ask_y "Install llama.cpp via Homebrew? (n = use the direct installer instead)"; then
        brew install llama.cpp || die "brew install llama.cpp failed."
        command -v llama >/dev/null 2>&1 || die "llama installed but not on PATH. Open a new terminal and re-run this script."
        ok "llama.cpp installed via Homebrew."
      else
        install_llama_direct
      fi
    else
      say "Homebrew is not installed, so we'll use llama.cpp's official direct installer."
      install_llama_direct
    fi
  else
    say "On $OS we use llama.cpp's official direct installer (no Homebrew)."
    install_llama_direct
  fi
fi

# --- Step 2: pick and download a model --------------------------------------
head_ "Step 2 of 4: choose a model"

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

# list_any_cached — prints one path per cached model found anywhere, covering
# both the Hugging Face hub layout (models--org--repo) and the older flat .gguf
# layout. Lets a re-run report models that are on disk but not in this menu.
list_any_cached() {
  for root in $CACHE_ROOTS; do
    find "$root" -maxdepth 1 -type d -name 'models--*--*' 2>/dev/null
    find "$root" -maxdepth 4 -type f -iname '*.gguf' 2>/dev/null
  done | sort -u
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
# llama cli auto-enables conversation mode whenever the model ships a chat
# template, which every model offered here does. -no-cnv is supposed to suppress
# that but is unreliable across builds, so three independent guards are used:
#   -st / --single-turn  documented to be non-interactive when -p is supplied
#   -no-cnv              legacy flag, still honoured by most builds
#   < /dev/null          the backstop: any prompt that appears gets EOF and exits
# Flags are probed against --help first so an older or newer llama never
# aborts with "unknown argument".
fetch_model() {
  fm_repo="$1"
  fm_help=$(llama cli --help 2>&1 || true)
  fm_flags="-n 1"
  case "$fm_help" in *-no-cnv*)       fm_flags="$fm_flags -no-cnv" ;; esac
  case "$fm_help" in *--single-turn*) fm_flags="$fm_flags -st" ;; esac
  case "$fm_help" in *--no-warmup*)   fm_flags="$fm_flags --no-warmup" ;; esac

  info "Running: llama cli -hf $fm_repo -p ok $fm_flags < /dev/null"
  # stdout is discarded (the single generated token); stderr is kept so the
  # download progress bar stays visible.
  llama cli -hf "$fm_repo" -p "ok" $fm_flags </dev/null >/dev/null
}

say "Checking which models you already have..."
S1=$(status_line "ggml-org" "gemma-4-E4B-it-GGUF"            "gemma-4-E4B"            "4.6 GB")
S2=$(status_line "unsloth"  "gemma-4-26B-A4B-it-qat-GGUF"    "gemma-4-26B-A4B-it-qat" "15 GB")
S3=$(status_line "unsloth"  "Qwen3.5-35B-A3B-GGUF"           "Qwen3.5-35B-A3B"        "20 GB")
ANY_CACHED=$(list_any_cached)

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
say "  ${BOLD}0)${RST} Skip the model download — no model now (steps 3 and 4 still run)"
say ""
RAM_GB=$(system_ram_gb)
if [ -n "$RAM_GB" ]; then
  info "Your machine reports $RAM_GB GB of RAM."
fi
if [ -n "$CACHE_ROOTS" ]; then
  info "Cache directories searched:$CACHE_ROOTS"
else
  info "No model cache directory exists yet — nothing has been downloaded before."
fi

# Report any cached models that aren't among the three offered above, so a
# re-run of this script doesn't silently ignore what's already on disk.
if [ -n "$ANY_CACHED" ]; then
  OTHER_CACHED=$(printf '%s\n' "$ANY_CACHED" | grep -viE 'gemma-4-E4B|gemma-4-26B-A4B-it-qat|Qwen3.5-35B-A3B' || true)
  if [ -n "$OTHER_CACHED" ]; then
    say ""
    info "Other models already on disk (not offered above):"
    printf '%s\n' "$OTHER_CACHED" | while IFS= read -r m; do info "  - ${m##*/}"; done
  fi
fi

MODEL_REPO=""; MODEL_ALIAS=""; MODEL_LABEL=""; MODEL_CTX=32768
MODEL_ORG=""; MODEL_NAME=""; MODEL_FRAG=""
while [ -z "$MODEL_REPO" ]; do
  printf '%s' "${BOLD}Choose 1, 2, 3, 0 to skip, or q to quit: ${RST}"
  read -r choice </dev/tty || choice="q"
  case "$choice" in
    1) MODEL_REPO="ggml-org/gemma-4-E4B-it-GGUF:Q4_0";              MODEL_ALIAS="gemma-4-e4b";         MODEL_LABEL="Gemma 4 E4B"
       MODEL_ORG="ggml-org"; MODEL_NAME="gemma-4-E4B-it-GGUF";         MODEL_FRAG="gemma-4-E4B" ;;
    2) MODEL_REPO="unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL";  MODEL_ALIAS="gemma-4-26b-a4b-qat"; MODEL_LABEL="Gemma 4 26B-A4B QAT"
       MODEL_ORG="unsloth"; MODEL_NAME="gemma-4-26B-A4B-it-qat-GGUF"; MODEL_FRAG="gemma-4-26B-A4B-it-qat" ;;
    3) MODEL_REPO="unsloth/Qwen3.5-35B-A3B-GGUF:Q4_K_M";             MODEL_ALIAS="qwen3.5-35b-a3b";     MODEL_LABEL="Qwen3.5 35B-A3B"
       MODEL_ORG="unsloth"; MODEL_NAME="Qwen3.5-35B-A3B-GGUF";        MODEL_FRAG="Qwen3.5-35B-A3B" ;;
    0|s|S) MODEL_REPO="SKIP" ;;
    q|Q) say "Nothing downloaded. Exiting."; exit 0 ;;
    *) warn "Please type 1, 2, 3, 0 or q." ;;
  esac
done

if [ "$MODEL_REPO" = "SKIP" ]; then
  warn "Model download skipped. No model selected — steps 3 and 4 still run."
  warn "Add a model later with: llama cli -hf <org/repo>:<quant>"
else
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
  if ask "Download the model now? (Say n to skip — 'llama serve' will fetch it on first run.)"; then
    fetch_model "$MODEL_REPO" || die "Model download failed."
    ok "Model downloaded and cached."
  else
    warn "Skipped. The first 'llama serve' run will download it."
  fi
fi
fi

# --- Step 3: pi -------------------------------------------------------------
head_ "Step 3 of 4: pi coding agent"

# pi's installer handles Node.js itself: it requires Node >= 22.19.0 and, if that
# is missing, offers to install a compatible Node (via Homebrew on macOS, or a
# checksum-verified standalone build under ~/.local/share/pi-node elsewhere).
# So there is no separate Node step here -- just a heads-up if yours is too old.
if command -v node >/dev/null 2>&1; then
  NODE_V=$(node --version)
  if node -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>22||(a===22&&b>=19)?0:1)' 2>/dev/null; then
    ok "Node.js $NODE_V meets pi's requirement (>= 22.19.0)."
  else
    warn "Node.js $NODE_V is older than pi's minimum of 22.19.0."
    info "pi's installer will offer to upgrade it. Accept that prompt."
  fi
else
  info "Node.js is not installed. pi's installer will offer to install it."
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
  info "You are trusting the pi.dev server to serve an honest script, same as the other installers."
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
      info "The remaining step (pi-llama plugin) needs pi, so it will be skipped too."
    fi
  else
    warn "Skipped. llama.cpp and the model are still set up; you can install pi later."
  fi
fi

# --- Step 4: connect pi to the local model -----------------------------------
head_ "Step 4 of 4: connect pi to your local model"

# Step 4a: pi-llama plugin. Replaces the old models.json approach — pi
# auto-discovers the local model served by 'llama serve'. No manual config.
if command -v pi >/dev/null 2>&1; then
  say ""
  say "Install the pi-llama plugin so pi auto-discovers your local model."
  info "Command: pi install git:github.com/huggingface/pi-llama"
  info "This replaces the old models.json approach — no manual config file is needed."
  if ask "Install the pi-llama plugin now?"; then
    if pi install git:github.com/huggingface/pi-llama; then
      ok "pi-llama plugin installed."
    else
      warn "Plugin install reported an error. Run it again later with: pi install git:github.com/huggingface/pi-llama"
    fi
  else
    warn "Skipped. Run it later with: pi install git:github.com/huggingface/pi-llama"
  fi
else
  warn "pi is not installed, so the plugin can't be added here."
  info "Install pi first, then run: pi install git:github.com/huggingface/pi-llama"
fi

# Step 4b: llama serve. There's no launcher script anymore — just the minimal
# command, run in its own terminal and left running.
say ""
say "Finally, start your model server."
info "In a separate terminal, run this and leave it running:"
info "  llama serve"
info "'llama serve' starts the local server; pi finds it automatically via the pi-llama plugin."
if [ "$MODEL_REPO" != "SKIP" ]; then
  info "(The model you chose is already cached, so it starts without re-downloading.)"
fi

# --- Done -------------------------------------------------------------------
head_ "Done"
say "To use it, open ${BOLD}two${RST} terminal windows:"
say ""
say "  Terminal 1 (leave running):   ${BOLD}llama serve${RST}"
say "  Terminal 2:                   ${BOLD}cd /your/project && pi${RST}"
say ""
info "pi auto-discovers the local model via the pi-llama plugin — no models.json,"
info "no launcher script, no manual config."
