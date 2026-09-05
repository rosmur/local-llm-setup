---
title: Manual Installation
description: Step-by-step terminal commands to install llama.cpp, models, and pi manually without the setup script.
---

# Manual Installation

Manual installation is recommended if you:

- Are familiar with the terminal, bash, config files, etc.
- Wish to install only a subset of items
- Want modifications not supported by the script, like alternate models or Docker usage

Below is every command the setup script runs, explained step by step.

## Step-by-step, with the actual commands

**Step 1 — llama.cpp.** The script first detects your OS (macOS, Linux, or Windows). If `llama` is already on `PATH`, this step is skipped.

On macOS, when Homebrew is installed you are asked to pick between two methods — Homebrew (the default) or the official direct installer:

```bash
brew install llama.cpp
```

or

```bash
curl -LsSf https://llama.app/install.sh | sh
```

On Linux and Windows, only the official direct installer is used (no Homebrew). Recent builds of llama.cpp provide a unified `llama` command (`llama cli`, `llama serve`, `llama --version`).

**Step 2 — the model.** Before showing the menu, the script searches for models you already have and labels each option `[on disk: 4.6G]` or `[not downloaded, ~4.6 GB]`. Cache roots are searched in the same precedence order `llama.cpp` itself uses:

```
$LLAMA_CACHE  →  $HF_HUB_CACHE  →  $HUGGINGFACE_HUB_CACHE  →  $HF_HOME/hub
              →  ~/.cache/huggingface/hub  →  ~/.cache/llama.cpp
              →  ~/Library/Caches/llama.cpp
```

Two on-disk layouts are recognised, because recent `llama.cpp` migrated to the standard Hugging Face hub cache while older builds used a flat directory of their own: a `models--<org>--<repo>` directory, or any `.gguf` file whose name contains the model name. Sizes come from `du -sh`.

If your chosen model is already present the download is skipped. You are still offered a verification pass, which is worth taking if a previous run was interrupted — the download resumes rather than restarting.

You can also choose **0 (skip)** and download no model at all. Steps 3 and 4 still run, and `llama serve` will fetch the model on its first run.

The download itself uses `llama.cpp`'s Hugging Face integration: `-hf` fetches the weights into the cache, and generating exactly one token makes the process exit immediately afterwards. It is a download that happens to warm up the model on the way past. You can decline it and let the server download on first launch instead.

Getting it to exit cleanly takes more care than it should. `llama cli` auto-enables conversation mode whenever the model ships a chat template — which all three of these do — and then sits at an interactive prompt waiting for you, requiring a `Ctrl-C` to escape. The documented off-switch, `-no-cnv`, is not reliable across builds. The script therefore uses three independent guards:

```bash
llama cli -hf <repo>:<quant> -p ok -n 1 -no-cnv -st --no-warmup < /dev/null
```

- `-st` / `--single-turn` — documented as non-interactive when a prompt is supplied with `-p`
- `-no-cnv` — the legacy flag, still honoured by most builds
- `< /dev/null` — the backstop. Even if both flags are ignored, any prompt that appears receives end-of-input and the process exits.

The flags are probed against `llama cli --help` before use, so an older or newer build that lacks one of them degrades to whichever it does support rather than aborting on an unknown argument. `stdout` is discarded; `stderr` is kept so the download progress bar stays visible.

The three repositories:

```
ggml-org/gemma-4-E4B-it-GGUF:Q4_0
unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL
unsloth/Qwen3.6-35B-A3B-GGUF:Q4_K_M
```

**Step 3 — pi.** Checks `node --version` against pi's minimum of 22.19.0 and reports, but does not act — pi's own installer handles Node. Then:

```bash
curl -fsSL https://pi.dev/install.sh | sh
```

Afterwards, if `pi` isn't resolvable, the script probes `$(npm prefix -g)/bin`, `~/.local/bin`, and `~/.local/share/pi-node/current/bin` and prepends whichever contains it — this only affects the running script, not your shell permanently.

**Step 4 — connect pi to your local model.**

**Step 4a — the pi-llama plugin.** This replaces the old `models.json` approach. No manual config file is needed; pi auto-discovers the model served by `llama serve`:

```bash
pi install git:github.com/huggingface/pi-llama
```

**Step 4b — start the model server.** There is no launcher script anymore — just run the server in its own terminal and leave it running:

```bash
llama serve
```

`llama serve` starts the local server on `127.0.0.1:8080`. The pi-llama plugin finds it automatically. If you skipped the model download, the first `llama serve` run fetches the weights for you.

## Notes on the third-party installer

Step 3 pipes a remote script into a shell. That deserves scrutiny, so here is what `pi.dev/install.sh` does, from reading it:

- **Node.js.** Requires ≥ 22.19.0. If missing or too old it asks, then uses `brew install node` when Homebrew exists (macOS). Without Homebrew it downloads a Node 22 tarball from `nodejs.org` and verifies it against the published `SHASUMS256.txt` before extracting.
- **Interactivity.** It opens `/dev/tty` explicitly for its prompts, which is why piping into `sh` doesn't break it. It shows you the exact `npm` command it intends to run and offers install / uninstall / do-nothing. Choosing "do nothing" exits cleanly.
- **What it runs.** By default: `npm install -g --ignore-scripts --min-release-age=0 @earendil-works/pi-coding-agent`. An alternative pinned-dependency path exists but is gated behind an environment variable and is off by default.
- **Privileges.** No `sudo` on macOS. The `sudo` calls in the file are confined to the Linux `apt`/`apk` branches.
- **Writes.** npm's prefix or `~/.local`, plus `~/.local/share/pi-node`, plus temp files. Its one edit to your shell profile is prompted and checks for a duplicate line first.
- No `eval`, no telemetry, no credential access.

To read it yourself before running anything:

```bash
curl -fsSL https://pi.dev/install.sh | less
```
