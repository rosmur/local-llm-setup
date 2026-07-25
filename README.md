# Local AI Setup

This repo contains scripts and resources to setup local LLMs and AI.

| Your machine | Script | Documented in |
|---|---|---|
| **macOS** | [`setup-local-pi.sh`](setup-local-pi.sh) | Sections 1–9 below |
| **Windows** | [`setup-local-pi.ps1`](setup-local-pi.ps1) | [Section 10](#10-windows-setup-local-pips1) |

Both scripts set up the same four-piece stack and end at the same place: a coding assistant in your terminal, talking to a model running on your own hardware. The Windows script is a port of the macOS one, so sections 1–5 apply to both — read those first, then jump to section 10 for what differs.

## `setup-local-pi.sh` — Set up a private LLM based AI assistant on your Mac

This script sets up an AI assistant that runs **entirely on your own Mac**. No account, no API key, no subscription, and nothing you type is sent to a company's servers.

It is written to be readable and to ask before it does anything. Every step explains what it is about to do, shows the exact command, and waits for you to type `y`. Typing anything else skips that step. `Ctrl-C` quits at any point.

**Reading guide.** Sections 1–5 are for everyone and assume no technical background. Sections 6–9 are the detail an engineer would want before running this on their machine. Section 10 is the Windows port. You do not need the second half to use either script.

## Get Started

### macOS

Two options:

1. Run it directly by copy/pasting this into your terminal:

```bash
bash -c "$(curl -fsSL <https://raw.githubusercontent.com/rosmur/local-llm-setup/main/setup-local-pi.sh>)"
```

1. Or download the script first and then run it: <https://github.com/rosmur/local-llm-setup/blob/main/setup-local-pi.sh>. And then run it by typing:

```bash
sh Downloads/setup-local-pi.sh
```

### Windows

Open **PowerShell** (either Windows PowerShell or PowerShell 7) and either:

1. Run it directly:

```powershell
irm https://raw.githubusercontent.com/rosmur/local-llm-setup/main/setup-local-pi.ps1 | iex
```

1. Or download <https://github.com/rosmur/local-llm-setup/blob/main/setup-local-pi.ps1> first, then run it. The `-ExecutionPolicy Bypass` is needed because Windows blocks downloaded scripts by default:

```powershell
powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\Downloads\setup-local-pi.ps1
```

You do **not** need to run PowerShell as Administrator. See [section 10](#10-windows-setup-local-pips1) for the one case where it helps.

**NOTE**

- Written by AI
- `setup-local-pi.sh`: tested and verified operation on MacBook Pro M1 (Sequoia)
- `setup-local-pi.ps1`: verified by running the script end-to-end against stubbed
  `winget` / `llama-cli` / `node` / `npm` binaries — every branch, prompt and generated
  file was exercised, but **not yet on real Windows hardware with real downloads**
- Reviewed by human

---

## 1. What you end up with

Four pieces, installed in order, each one needed by the next:

| Piece | What it is | Why it's here |
|---|---|---|
| **Homebrew** | A "app store for the command line" that macOS doesn't ship with | It's how the next piece gets installed |
| **llama.cpp** | Software that runs AI models on your own hardware | This is the engine |
| **A model** | The AI itself — a multi-gigabyte file you choose from a menu | This is the brain |
| **pi** | A coding assistant that lives in your terminal | This is the part you talk to |

The arrangement is deliberate. `llama.cpp` runs a small local web server on your machine that speaks the same language as commercial AI services. `pi` is then pointed at that local server instead of at the internet. `pi` never knows the difference — and neither does your data, which never leaves the machine.

```
   You type in the terminal
            │
            ▼
        [  pi  ]  ← the assistant: reads files, writes code, runs commands
            │
            │  talks over http://localhost:8080  (localhost = your own Mac)
            ▼
   [ llama-server ]  ← part of llama.cpp; loads the model, does the thinking
            │
            ▼
   [ the model file ]  ← several GB sitting on your disk
```

---

## 2. Before you start

- **A Mac** for `setup-local-pi.sh`, or **Windows 10 1809+ / Windows 11** for `setup-local-pi.ps1`. Each script refuses to run on the other's platform.
- **Disk space.** Between 5 GB and 20 GB depending on which model you pick.
- **Memory (RAM).** This is the one that actually matters. The script prints how much your Mac has and shows the download size of each option next to it. As a rough rule, the model should be comfortably smaller than your RAM. Choosing a model that's too big won't break anything, but it will be painfully slow.
- **Patience for one step.** The model download is several gigabytes. It can take anywhere from a few minutes to over an hour.
- **An internet connection** — but only during setup. Afterwards, the assistant works offline.

## 3. Running it

```bash
bash setup-local-pi.sh
```

Then read each prompt and answer `y` or `n`. That's the whole thing.

## 4. Choosing a model

Step 3 offers three options. All are free and open-weight.

| | Model | Download | Notes |
|---|---|---|---|
| **1** | Gemma 4 E4B | ~4.6 GB | The small, fast one. Works on modest machines. A reasonable first choice if you're unsure. |
| **2** | Gemma 4 26B-A4B (QAT) | ~15 GB | Much more capable, but only activates a small slice of itself per word, so it stays fast. Wants ~24 GB of RAM. |
| **3** | Qwen3.5 35B-A3B | ~20 GB | Same idea, different family. Strong at code. Wants ~32 GB of RAM. |

"QAT" on option 2 means the model was *trained* to survive being compressed, so it loses less quality than ordinary compression would cost.

If you pick wrong, nothing is lost. Re-run the script and choose a different one; both models stay cached on disk and the script will simply point `pi` at whichever you chose most recently.

**Re-running the script is always safe.** Every step detects work that is already done and skips it, so an interrupted run — a dropped connection during the download, a closed laptop lid — is recovered by just starting again. The menu marks which models you already have, and nothing is downloaded twice.

## 5. Using it afterwards

You need **two terminal windows**, because the engine has to keep running while you work.

**Window 1** — start the engine and leave it alone:

```bash
~/bin/llama-serve-<model-name>.sh
```

(The script tells you the exact filename when it finishes.) The first run may pause a while as the model loads into memory.

**Window 2** — go to whatever folder you want help with, and start the assistant:

```bash
cd ~/my-project
pi
```

Inside `pi`, press **Ctrl+L** (or type `/model`) and select your local model from the list.

When you're done, close window 2, then press `Ctrl-C` in window 1 to shut the engine down and free up your memory.

> **A word of caution about coding assistants generally.** `pi` can read your files, write to them, and run commands on your Mac. That is what makes it useful, and it is also a real risk — a confused model can delete or overwrite things. Use it in folders tracked by version control (`git`), so any mistake can be undone. This applies to every tool of this kind, not just this one.

---

## 6. Exactly what gets installed and where

Nothing here is hidden; this is the full list of changes to your machine.

| Path | What | Created by |
|---|---|---|
| `/opt/homebrew` (Apple Silicon) or `/usr/local` (Intel) | Homebrew and everything it installs | Homebrew's own installer |
| `<brew prefix>/bin/llama-server`, `llama-cli` | The inference engine | `brew install llama.cpp` |
| `~/.cache/huggingface/hub/` | Downloaded model weights (the big files) | `llama-cli` / `llama-server` |
| `~/bin/llama-serve-<alias>.sh` | The launcher script for your model | This script |
| `~/.pi/agent/models.json` | Tells `pi` where your local server is | This script |
| `~/.pi/agent/models.json.bak.<timestamp>` | Backup, only if the file already existed | This script |
| npm's global prefix, **or** `~/.local` | The `pi` program itself | pi's installer |
| `~/.local/share/pi-node/` | A private copy of Node.js, **only** if you have no Homebrew and no suitable Node | pi's installer |
| Your `.zshrc` / `.bashrc` / `config.fish` | One appended `export PATH=...` line | pi's installer, **and only after asking you** |

**Not touched:** system files, login items, launch agents, browser data, SSH keys, credentials. Nothing runs at startup. Nothing phones home.

### Uninstalling

```bash
npm uninstall -g @earendil-works/pi-coding-agent   # remove pi
brew uninstall llama.cpp                          # remove the engine
rm -rf ~/.cache/huggingface/hub                    # reclaim the model files (the big one)
rm -rf ~/.cache/llama.cpp                          # older llama.cpp builds cached here instead
rm -rf ~/.pi                                       # remove pi's config and saved sessions
rm ~/bin/llama-serve-*.sh                          # remove the launcher
```

Homebrew itself is left in place, since you may have other things depending on it.

## 7. Step-by-step, with the actual commands

**Step 1 — Homebrew.** Checks for `brew` on `PATH`, then probes `/opt/homebrew/bin/brew` and `/usr/local/bin/brew` directly, because Homebrew can be installed without being on the current shell's `PATH`. If genuinely absent, and only with your consent:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

This is the official installer. It uses `sudo` and will ask for your Mac password. If you decline, the script stops here and changes nothing.

**Step 2 — llama.cpp.** Checks for `llama-server`. If missing:

```bash
brew install llama.cpp
```

The formula is named `llama.cpp` but installs binaries called `llama-cli` and `llama-server`.

**Step 3 — the model.** Before showing the menu, the script searches for models you already have and labels each option `[on disk: 4.6G]` or `[not downloaded, ~4.6 GB]`. Cache roots are searched in the same precedence order `llama.cpp` itself uses:

```
$LLAMA_CACHE  →  $HF_HUB_CACHE  →  $HUGGINGFACE_HUB_CACHE  →  $HF_HOME/hub
              →  ~/.cache/huggingface/hub  →  ~/.cache/llama.cpp
              →  ~/Library/Caches/llama.cpp
```

Two on-disk layouts are recognised, because recent `llama.cpp` migrated to the standard Hugging Face hub cache while older builds used a flat directory of their own: a `models--<org>--<repo>` directory, or any `.gguf` file whose name contains the model name. Sizes come from `du -sh`.

If your chosen model is already present the download is skipped. You are still offered a verification pass, which is worth taking if a previous run was interrupted — the download resumes rather than restarting.

The download itself uses `llama.cpp`'s Hugging Face integration: `-hf` fetches the weights into the cache, and generating exactly one token makes the process exit immediately afterwards. It is a download that happens to warm up the model on the way past. You can decline it and let the server download on first launch instead.

Getting it to exit cleanly takes more care than it should. `llama-cli` auto-enables conversation mode whenever the model ships a chat template — which all three of these do — and then sits at an interactive prompt waiting for you, requiring a `Ctrl-C` to escape. The documented off-switch, `-no-cnv`, is not reliable across builds. The script therefore uses three independent guards:

```bash
llama-cli -hf <repo>:<quant> -p ok -n 1 -no-cnv -st --no-warmup < /dev/null
```

- `-st` / `--single-turn` — documented as non-interactive when a prompt is supplied with `-p`
- `-no-cnv` — the legacy flag, still honoured by most builds
- `< /dev/null` — the backstop. Even if both flags are ignored, any prompt that appears receives end-of-input and the process exits.

The flags are probed against `llama-cli --help` before use, so an older or newer build that lacks one of them degrades to whichever it does support rather than aborting on an unknown argument. `stdout` is discarded; `stderr` is kept so the download progress bar stays visible.

The three repositories:

```
ggml-org/gemma-4-E4B-it-GGUF:Q4_0
unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL
unsloth/Qwen3.5-35B-A3B-GGUF:Q4_K_M
```

**Step 4 — pi.** Checks `node --version` against pi's minimum of 22.19.0 and reports, but does not act — pi's own installer handles Node. Then:

```bash
curl -fsSL https://pi.dev/install.sh | sh
```

Afterwards, if `pi` isn't resolvable, the script probes `$(npm prefix -g)/bin`, `~/.local/bin`, and `~/.local/share/pi-node/current/bin` and prepends whichever contains it — this only affects the running script, not your shell permanently.

**Step 4c — the launcher.** Written to `~/bin/llama-serve-<alias>.sh`:

```bash
llama-server \
  -hf <repo>:<quant> \
  --alias <alias> \
  --host 127.0.0.1 --port 8080 \
  -ngl 99 \
  -c 32768 \
  -fa on \
  --jinja
```

- `--host 127.0.0.1` binds to the loopback interface only. Other machines on your network cannot reach it.
- `--alias` is the important one. It pins the name the server reports over the API, so the entry written into `models.json` is guaranteed to match. Without it the name is derived from the repository path and a mismatch fails silently.
- `-ngl 99` offloads all layers to the GPU (Metal, on a Mac).
- `-c 32768` sets a 32K-token context window. Raise it if you have memory to spare; lower it if the server won't start.
- `--jinja` uses the chat template embedded in the model file, which matters for tool-calling.

**Step 4d — pi's configuration.** Backs up `~/.pi/agent/models.json` with a timestamp, then merges in:

```json
{
  "providers": {
    "llama-cpp": {
      "baseUrl": "http://localhost:8080/v1",
      "api": "openai-completions",
      "apiKey": "none",
      "models": [
        {
          "id": "<alias>",
          "name": "<label> (local)",
          "contextWindow": 32768,
          "maxTokens": 8192,
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
        }
      ]
    }
  }
}
```

The merge is a real merge, not an overwrite: existing providers survive, and re-running with the same model replaces that one entry rather than duplicating it. It is performed by `node` if available, otherwise `python3` — both branches are equivalent and both abort loudly if the existing file is malformed JSON.

The dummy `apiKey` is not vestigial. `pi` treats a model as unavailable until some credential exists for its provider, even for a keyless local server, so a placeholder is required for the model to appear in the `/model` picker.

## 8. Notes on the third-party installer

Step 4 pipes a remote script into a shell. That deserves scrutiny, so here is what `pi.dev/install.sh` does, from reading it:

- **Node.js.** Requires ≥ 22.19.0. If missing or too old it asks, then uses `brew install node` when Homebrew exists — which it will, because step 1 ran first. With no Homebrew it downloads a Node 22 tarball from `nodejs.org` and verifies it against the published `SHASUMS256.txt` before extracting.
- **Interactivity.** It opens `/dev/tty` explicitly for its prompts, which is why piping into `sh` doesn't break it. It shows you the exact `npm` command it intends to run and offers install / uninstall / do-nothing. Choosing "do nothing" exits cleanly.
- **What it runs.** By default: `npm install -g --ignore-scripts --min-release-age=0 @earendil-works/pi-coding-agent`. An alternative pinned-dependency path exists but is gated behind an environment variable and is off by default.
- **Privileges.** No `sudo` on macOS. The `sudo` calls in the file are confined to the Linux `apt`/`apk` branches.
- **Writes.** npm's prefix or `~/.local`, plus `~/.local/share/pi-node`, plus temp files. Its one edit to your shell profile is prompted and checks for a duplicate line first.
- No `eval`, no telemetry, no credential access.

To read it yourself before running anything:

```bash
curl -fsSL https://pi.dev/install.sh | less
```

## 9. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `pi: command not found` | The install directory isn't on your `PATH` yet. Open a **new** terminal window; pi's installer offers to fix your shell profile permanently. |
| Your model isn't in `pi`'s `/model` list | Two usual causes. The server isn't running — check with `curl http://localhost:8080/v1/models`. Or `pi` has no stored credential for the provider — start it once with `pi --api-key none`. |
| Server exits with a memory error | The model is too big for your RAM. Lower `-c 32768` to `-c 8192` in the launcher, or re-run the script and pick a smaller model. |
| Painfully slow responses | Also memory. The Mac is swapping to disk. Same fix. |
| Download step drops you into a chat prompt | Should not happen — three separate guards prevent it. If it does, press `Ctrl-C`; the download has already finished by the time the prompt appears, and the script continues normally. |
| Port 8080 already in use | Something else has it. Change the port in **both** the launcher script and the `baseUrl` in `models.json` — they must agree. |
| `brew: command not found` after step 1 | Homebrew installed but isn't on this shell's `PATH`. Open a new terminal and re-run the script; it'll detect the existing install and skip ahead. |

---

## 10. Windows (`setup-local-pi.ps1`)

A port of the macOS script, not a rewrite: same four pieces, same model menu, same
prompt-before-anything behaviour, same `models.json` result. What follows is only what
differs. Sections 1–5 still describe what you end up with and how to use it.

### 10.1 What changes, and why

| | macOS | Windows |
|---|---|---|
| Package manager | Homebrew (installed by the script) | **winget** (already on the OS) |
| llama.cpp | `brew install llama.cpp` | `winget install --exact --id ggml.llamacpp` |
| GPU backend | Metal | **Vulkan** (what the winget package ships) |
| Node.js | left to pi's installer | installed explicitly via winget |
| A shell for pi | already there | **Git Bash**, installed via winget |
| Launcher | `~/bin/llama-serve-<alias>.sh` | `%USERPROFILE%\bin\llama-serve-<alias>.cmd` |
| JSON merge | `node` or `python3` | PowerShell's own `ConvertFrom-Json` |
| Steps | 4 | **5** |

Two of these deserve an explanation.

**Why a fifth step.** On Windows, `pi` has a prerequisite it does not have on macOS: it
shells out to **bash** to run commands for you, and Windows ships none. pi looks for
`shellPath` in `~/.pi/agent/settings.json`, then Git Bash at
`C:\Program Files\Git\bin\bash.exe`, then any `bash.exe` on `PATH`. So the script offers
to install Git for Windows. Decline it and pi still installs and still talks to your
model — but its command-running tool will not work. If a `bash.exe` is found only in
`System32`, the script warns rather than accepting it: that is the legacy WSL launcher,
so paths and tools would come from inside your Linux distro instead of from Windows.

**Why Node.js is installed up front.** On macOS the script leaves Node to pi's own
installer, which offers to fetch it via Homebrew. On Windows `winget install --exact --id
OpenJS.NodeJS.LTS` is a single, inspectable line, and having Node present first means pi
can be installed with plain `npm` — see 10.4.

### 10.2 Exactly what gets installed and where

| Path | What | Created by |
|---|---|---|
| `%LOCALAPPDATA%\Microsoft\WinGet\Packages\ggml.llamacpp_*` | The inference engine's binaries and DLLs | `winget` |
| `%LOCALAPPDATA%\Microsoft\WinGet\Links\llama-*.exe` | Links to those binaries, on your `PATH` | `winget` |
| `C:\Program Files\Git\` | Git for Windows, which supplies `bash.exe` | `winget` |
| `C:\Program Files\nodejs\` | Node.js LTS | `winget` |
| The Visual C++ 2015+ x64 runtime | A dependency of the llama.cpp package | `winget` |
| `%USERPROFILE%\.cache\huggingface\hub\` | Downloaded model weights (the big files) | `llama-cli` / `llama-server` |
| `%USERPROFILE%\bin\llama-serve-<alias>.cmd` | The launcher for your model | This script |
| `%APPDATA%\npm\` | The `pi` program itself | `npm` |
| `%USERPROFILE%\.pi\agent\models.json` | Tells `pi` where your local server is | This script |
| `%USERPROFILE%\.pi\agent\models.json.bak.<timestamp>` | Backup, only if the file already existed | This script |

Older `llama.cpp` builds cache weights in `%LOCALAPPDATA%\llama.cpp` instead of the
Hugging Face directory; the script searches both.

**Not touched:** the registry beyond what winget's own installers write, system files,
startup entries, scheduled tasks, browser data, SSH keys, credentials. Nothing runs at
startup. Nothing phones home. No step needs Administrator.

#### Uninstalling

```powershell
npm uninstall -g @earendil-works/pi-coding-agent   # remove pi
winget uninstall --exact --id ggml.llamacpp        # remove the engine
Remove-Item -Recurse -Force $HOME\.cache\huggingface\hub   # reclaim the model files (the big one)
Remove-Item -Recurse -Force $env:LOCALAPPDATA\llama.cpp    # older builds cached here instead
Remove-Item -Recurse -Force $HOME\.pi              # remove pi's config and saved sessions
Remove-Item $HOME\bin\llama-serve-*.cmd            # remove the launcher
```

Git and Node.js are left in place, since you may have other things depending on them.
Remove them with `winget uninstall --exact --id Git.Git` and
`winget uninstall --exact --id OpenJS.NodeJS.LTS` if you want them gone.

### 10.3 Step-by-step, with the actual commands

**Step 1 — winget.** Checked, never installed. winget ships with Windows 11 and with
Windows 10 1809+ that have taken the Store's "App Installer" update; bootstrapping it
from a script is not something worth doing behind a `y` prompt. If it is missing the
script offers to open its Store page and then stops, changing nothing.

**Step 2 — llama.cpp.**

```powershell
winget install --exact --id ggml.llamacpp --accept-source-agreements --accept-package-agreements
```

The package is a `zip` of portable executables — `llama-cli.exe`, `llama-server.exe` and
nine others — linked into `%LOCALAPPDATA%\Microsoft\WinGet\Links`, plus the Visual C++
2015+ x64 runtime as a declared dependency. It is rebuilt for every upstream release.

Two things follow from how winget packages it:

- **It is the Vulkan x64 build.** Vulkan covers modern NVIDIA, AMD and Intel GPUs, so
  `-ngl 99` in the launcher does real work. On NVIDIA hardware a CUDA build is usually
  faster; if you want that, take the `-cuda-` asset from
  [llama.cpp's releases](https://github.com/ggml-org/llama.cpp/releases) instead and put
  it on your `PATH` before running this script — it will detect `llama-server` and skip
  step 2.
- **x64 only.** On an ARM64 Windows PC (Snapdragon X and similar) it runs under
  emulation, without GPU offload. The script says so up front. Building from source is
  the only fast path there.

**Step 3 — the model.** Identical to macOS, including the "already on disk" menu labels
and the one-token download trick, with two Windows details. The cache roots searched are:

```
$env:LLAMA_CACHE  →  $env:HF_HUB_CACHE  →  $env:HUGGINGFACE_HUB_CACHE
                  →  $env:HF_HOME\hub   →  %USERPROFILE%\.cache\huggingface\hub
                  →  %LOCALAPPDATA%\llama.cpp
```

And the download command's third guard changes shape. PowerShell has no way to hand a
native program a closed stdin, and `NUL` is a `cmd.exe` redirection rather than a real
file, so the script writes a two-line batch file to `%TEMP%`, runs it, and deletes it:

```bat
@echo off
"...\llama-cli.exe" -hf <repo>:<quant> -p ok -n 1 -no-cnv -st --no-warmup < NUL > NUL
```

Same three guards as macOS (`-st`, `-no-cnv`, and a closed stdin as the backstop), same
`--help` probing so a build missing a flag degrades instead of aborting. `stdout` goes to
`NUL`; `stderr` is untouched, so the download progress bar stays visible.

**Step 4 — Git Bash and Node.js.**

```powershell
winget install --exact --id Git.Git --accept-source-agreements --accept-package-agreements
winget install --exact --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
```

Node is only offered if it is absent or older than pi's minimum of 22.19.0.

After any of these, the script re-reads `PATH` from the registry — machine scope, then
user scope, plus winget's `Links` directory and `%APPDATA%\npm` — because this
PowerShell window's `PATH` was copied when it opened and will not otherwise show
anything installed since. That is what lets a fresh machine get through all five steps in
one session instead of needing a new terminal between each.

**Step 5 — pi.** Two routes, and the script asks which:

```powershell
npm install -g --ignore-scripts @earendil-works/pi-coding-agent   # A, offered first
irm https://pi.dev/install.ps1 | iex                              # B
```

A is the default suggestion, because Node.js already exists by this point and that one
line *is* the whole install — nothing to audit. B is the Windows equivalent of the
`curl | sh` one-liner the macOS script uses, and ends up running much the same `npm`
command with its own Node check and `PATH` handling around it.

**Step 5c — the launcher.** Written to `%USERPROFILE%\bin\llama-serve-<alias>.cmd`, with
the same flags as the macOS version:

```bat
llama-server ^
  -hf <repo>:<quant> ^
  --alias <alias> ^
  --host 127.0.0.1 --port 8080 ^
  -ngl 99 ^
  -c 32768 ^
  -fa on ^
  --jinja

if errorlevel 1 pause
```

A `.cmd` file rather than a `.ps1` for two reasons: PowerShell's execution policy cannot
block it, and you can double-click it in Explorer. The trailing `pause` keeps the window
open long enough to read the error if the server fails to start — which, double-clicked,
it otherwise would not. `--host 127.0.0.1` binds to loopback only, so nothing else on
your network can reach it and Windows Firewall has no reason to prompt.

**Step 5d — pi's configuration.** The same merge into `%USERPROFILE%\.pi\agent\models.json`,
producing the same JSON as section 7. No `node` or `python3` is needed: PowerShell's
`ConvertFrom-Json` / `ConvertTo-Json` do it. Existing providers, existing keys inside
`llama-cpp`, and unrelated top-level settings all survive; re-running with the same model
replaces that one entry rather than duplicating it; a malformed existing file aborts
loudly before anything is written; and a timestamped `.bak` is made first.

Two details that are easy to get wrong and are handled explicitly: the file is written as
UTF-8 **without** a byte-order mark, because pi is a Node program and `JSON.parse`
rejects a BOM; and `ConvertTo-Json` is called with `-Depth 20`, because its default of 2
would silently flatten the nested model entries into type names.

### 10.4 Notes on the third-party installer

Section 8 audits `pi.dev/install.sh` by reading it. **No equivalent audit of
`pi.dev/install.ps1` has been done here** — it could not be retrieved from the
environment this was written in, so nothing is claimed about it beyond what pi's own
documentation says. That is precisely why the script offers `npm` first and puts the
`irm | iex` route second: `npm install -g --ignore-scripts @earendil-works/pi-coding-agent`
installs the same published package with nothing extra to trust, and the script has
already installed the Node.js that makes it possible.

If you prefer route B, read it before running it:

```powershell
irm https://pi.dev/install.ps1 | more
```

### 10.5 Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `...ps1 cannot be loaded because running scripts is disabled` | Windows blocks downloaded scripts. Run it as `powershell -ExecutionPolicy Bypass -File .\setup-local-pi.ps1`, or use the `irm ... \| iex` form, which is not a file and so is not blocked. |
| `llama-server` not found right after winget installed it | winget links portable packages using symlinks, which Windows only permits for administrators or with Developer Mode on. Turn on Developer Mode (Settings → System → For developers), or re-run the winget command from an elevated PowerShell. The script detects this case and says so. |
| `pi: command not found` in a new window | `%APPDATA%\npm` is not on your `PATH`. Reinstalling Node.js via winget fixes it; the script only patches `PATH` for its own session. |
| pi runs but cannot execute any commands | No bash. Install Git for Windows, or point pi at the shell you have by creating `%USERPROFILE%\.pi\agent\settings.json` containing `{ "shellPath": "C:\\path\\to\\bash.exe" }`. |
| Your model isn't in `pi`'s `/model` list | As on macOS: check the server with `curl.exe http://localhost:8080/v1/models`, and start pi once as `pi --api-key none` so it has a stored credential for the provider. |
| Slow generation, GPU seemingly unused | The winget build is Vulkan. Check your GPU driver exposes Vulkan, and look for the offload lines in `llama-server`'s startup output. On NVIDIA, try the CUDA build from llama.cpp's releases. |
| The download is much slower than your connection | Windows Defender scans each multi-GB file as it lands. Excluding the cache directory from real-time scanning helps, at the usual cost of excluding a directory from scanning. |
| Server exits with a memory error, or 8080 is taken | Same causes and fixes as the macOS table in section 9. |

---

## Known gaps and caveats

Stated plainly, because you are being asked to run this on your own machine.

- **The one-token download trick** (`llama-cli ... -n 1 -no-cnv`) is a construction, not a documented workflow. The documented approach is to let `llama-server -hf` download on first launch. If the flags misbehave on your build of `llama.cpp`, answer `n` at the download prompt and let the server handle it.
- **The "already downloaded" check is advisory, not authoritative.** It reliably detects that a model *repository* is cached, but in the Hugging Face layout the individual files are named by content hash, so it cannot always confirm that the specific compression level (quant) is present or that the files are complete. This is why the verification pass is still offered. A false "on disk" would at worst cause `llama-server` to download the missing piece on first launch.
- **Download sizes for options 2 and 3 are approximate**, taken from model-card metadata and third-party guides rather than measured.
- **The server flags are reasonable defaults, not tuned ones.** Model authors publish longer, more specific flag sets — particularly for KV-cache quantization and speculative decoding, which can meaningfully improve speed. Those are worth investigating once you have the basic setup working.
- **The analysis in section 8 covers the copy of `install.sh` that was inspected.** Roughly 60% of its 1500 lines were read closely — the main flow, all Node paths, install-location selection, `PATH` handling, and install/uninstall. The remainder (progress animations and pinned-install validation) was audited by pattern-searching for privilege escalation and destructive operations rather than line by line. Nothing concerning surfaced. That server can also serve different content in future; this is a snapshot, not a guarantee.
- **The `--min-release-age=0` flag** in pi's installer deliberately bypasses an npm safeguard that delays newly published packages. The stated justification is that pi ships a `npm-shrinkwrap.json` pinning its dependencies. That reasoning is sound in principle but has not been independently verified.

### Specific to `setup-local-pi.ps1`

- **It has not been run on real Windows hardware.** Every branch, prompt and generated file was exercised end-to-end against stubbed `winget`, `llama-cli`, `node` and `npm` binaries — including the fresh-machine path, the already-cached path, declining every prompt, invalid menu input, and each failure path — and that testing found and fixed several real bugs. But a stub is not a Vulkan GPU, and no actual model has been downloaded by it. Treat the first real run as the real test.
- **`pi.dev/install.ps1` was not read**, unlike its `.sh` counterpart in section 8. The script therefore offers plain `npm` first. See 10.4.
- **The winget llama.cpp package is a community-maintained manifest**, not an official ggml distribution channel — though it tracks upstream releases closely and points at ggml's own GitHub release assets.
- **GPU acceleration is whatever Vulkan gives you.** No CUDA, ROCm or SYCL path is attempted. That is a deliberate simplification, and it leaves performance on the table for NVIDIA owners.
- **ARM64 Windows is warned about, not solved.** The script tells you it will be slow and emulated, then carries on if you want it to.
- **Windows PowerShell 5.1 is the assumed floor** (`#Requires -Version 5.1`). It was developed and tested against PowerShell 7 and written to stay inside the 5.1 feature set, but 5.1-only behaviour has not been exercised directly.

## Additional Info

<https://gist.github.com/rosmur/84f0a77404bd901263de26566ab06f08>
