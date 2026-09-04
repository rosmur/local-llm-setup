---
title: Quick Start
description: Run a single command to install everything — Homebrew, llama.cpp, a model, and the pi coding assistant.
---

# Quick Start

The easiest method is to run the setup script that sets up everything for you.

## Option 1 — Run directly

Copy and paste this into your terminal:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rosmur/local-llm-setup/main/setup-local-pi.sh)"
```

## Option 2 — Download first

Download the script from [github.com/rosmur/local-llm-setup](https://github.com/rosmur/local-llm-setup/blob/main/setup-local-pi.sh), then run it:

```bash
bash Downloads/setup-local-pi.sh
```

## What to expect

The script is written to be readable and to ask before it does anything. Every step explains what it is about to do, shows the exact command, and waits for you to type `y`. Typing anything else skips that step. `Ctrl-C` quits at any point.

::: callout note
- Written by AI
- Tested and verified operation on MacBook Pro M1 (Sequoia)
- Reviewed by human
- **Re-running the script is always safe.** Every step detects work that is already done and skips it. An interrupted run — a dropped connection, a closed laptop lid — is recovered by just starting again. The menu marks which models you already have, and nothing is downloaded twice.
:::

## What happens step by step

1. **llama.cpp** — Installed via Homebrew (macOS) or the official direct installer (macOS, Linux, Windows)
2. **Model** — You pick from a menu of open-weight models, or type **0** to skip and download later
3. **pi** — The coding assistant is installed
4. **pi-llama plugin** — Installed so pi auto-discovers your local model
5. **llama serve** — You run the model server; no config files, no launcher script

## After the script finishes

See the [Usage](usage.md) page for how to start the engine and use `pi`.
