# Local AI Setup - Mac Edition <!-- omit from toc -->

This repo contains scripts and resources to setup local LLMs and AI. Use AI freely - No account, no API key, no subscription, and nothing you type is sent to anybody else's computers.

- [1. Get Started](#1-get-started)
- [2. What's installed](#2-whats-installed)
- [3. Requirements](#3-requirements)
- [4. Model Choices](#4-model-choices)
- [5. Usage](#5-usage)
- [6. Uninstallation](#6-uninstallation)
- [7. Troubleshooting](#7-troubleshooting)
- [8. Known gaps and caveats](#8-known-gaps-and-caveats)
- [9. Manual Installation](#9-manual-installation)
- [10. Additional Info](#10-additional-info)

**Reading guide.** Sections 1–5 are for everyone and assume no technical background. Sections 6–8 are the detail an engineer would want before running this on their machine. You do not need the second half to use the script.

## 1. Get Started

The easiest method is to run the setup script as follows that sets up everything for you. It is written to be readable and to ask before it does anything. Every step explains what it is about to do, shows the exact command, and waits for you to type `y`. Typing anything else skips that step. `Ctrl-C` quits at any point. Alternatively, if you prefer to do the setup manually or step by step see the [manual installation section](#9-manual-installation).

To run the script, there are two options:

1. Run it directly by copy/pasting this into your terminal:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rosmur/local-llm-setup/main/setup-local-pi.sh)"
```

1. Or download the script first and then run it: <https://github.com/rosmur/local-llm-setup/blob/main/setup-local-pi.sh>. And then run it by typing:

```bash
sh Downloads/setup-local-pi.sh
```

**NOTE**

- Written by AI
- Tested and verified operation on MacBook Pro M1 (Sequoia)
- Reviewed by human

---

## 2. What's installed

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

<details>
<summary><strong>Exactly what gets installed and where</strong></summary>

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

</details>

---

## 3. Requirements

- **A Mac.** The script refuses to run on anything else.
- **Disk space.** Between 5 GB and 20 GB depending on which model you pick.
- **Memory (RAM).** This is the one that actually matters. The script prints how much your Mac has and shows the download size of each option next to it. As a rough rule, the model should be comfortably smaller than your RAM. Choosing a model that's too big won't break anything, but it will be painfully slow.
- **Patience for one step.** The model download is several gigabytes. It can take anywhere from a few minutes to over an hour.
- **An internet connection** — but only during setup. Afterwards, the assistant works offline.

Then read each prompt and answer `y` or `n`. That's the whole thing.

## 4. Model Choices

Step 3 offers three options. All are free and open-weight.

| | Model | Download | Notes |
|---|---|---|---|
| **1** | Gemma 4 E4B | ~4.6 GB | The small, fast one. Works on modest machines. A reasonable first choice if you're unsure. |
| **2** | Gemma 4 26B-A4B (QAT) | ~15 GB | Much more capable, but only activates a small slice of itself per word, so it stays fast. Wants ~24 GB of RAM. |
| **3** | Qwen3.5 35B-A3B | ~20 GB | Same idea, different family. Strong at code. Wants ~32 GB of RAM. |

"QAT" on option 2 means the model was *trained* to survive being compressed, so it loses less quality than ordinary compression would cost.

If you pick wrong, nothing is lost. Re-run the script and choose a different one; both models stay cached on disk and the script will simply point `pi` at whichever you chose most recently.

**Re-running the script is always safe.** Every step detects work that is already done and skips it, so an interrupted run — a dropped connection during the download, a closed laptop lid — is recovered by just starting again. The menu marks which models you already have, and nothing is downloaded twice.

## 5. Usage

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

## 6. Uninstallation

Run the following commands to uninstall/remove everything that was setup

```bash
npm uninstall -g @earendil-works/pi-coding-agent   # remove pi
brew uninstall llama.cpp                          # remove the engine
rm -rf ~/.cache/huggingface/hub                    # reclaim the model files (the big one)
rm -rf ~/.cache/llama.cpp                          # older llama.cpp builds cached here instead
rm -rf ~/.pi                                       # remove pi's config and saved sessions
rm ~/bin/llama-serve-*.sh                          # remove the launcher
```

Homebrew itself is left in place, since you may have other things depending on it.

## 7. Troubleshooting

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

## 8. Known gaps and caveats

Stated plainly, because you are being asked to run this on your own machine.

- **The one-token download trick** (`llama-cli ... -n 1 -no-cnv`) is a construction, not a documented workflow. The documented approach is to let `llama-server -hf` download on first launch. If the flags misbehave on your build of `llama.cpp`, answer `n` at the download prompt and let the server handle it.
- **The "already downloaded" check is advisory, not authoritative.** It reliably detects that a model *repository* is cached, but in the Hugging Face layout the individual files are named by content hash, so it cannot always confirm that the specific compression level (quant) is present or that the files are complete. This is why the verification pass is still offered. A false "on disk" would at worst cause `llama-server` to download the missing piece on first launch.
- **The server flags are reasonable defaults, not tuned ones.** Model authors publish longer, more specific flag sets — particularly for KV-cache quantization and speculative decoding, which can meaningfully improve speed. Those are worth investigating once you have the basic setup working.
- **The `--min-release-age=0` flag** in pi's installer deliberately bypasses an npm safeguard that delays newly published packages. The stated justification is that pi ships a `npm-shrinkwrap.json` pinning its dependencies. That reasoning is sound in principle but has not been independently verified.

## 9. Manual Installation

Manual installation is recommended if you:

- Are familiar with the terminal, bash, config files etc.
- Wish to install only a subset of items
- Want to make modifications not supported by the script like alternate models, usage of docker etc.

See [here for step by step installation instructions](docs/script-manual.md)

## 10. Additional Info

<https://gist.github.com/rosmur/84f0a77404bd901263de26566ab06f08>
