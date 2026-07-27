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

!!! note

    - Written by AI
    - Tested and verified operation on MacBook Pro M1 (Sequoia)
    - Reviewed by human
    - **Re-running the script is always safe.** Every step detects work that is already done and skips it. An interrupted run — a dropped connection, a closed laptop lid — is recovered by just starting again. The menu marks which models you already have, and nothing is downloaded twice.

## What happens step by step

1. **Homebrew** — Installed if missing (with your permission)
2. **llama.cpp** — Installed via Homebrew
3. **Model** — You pick from a menu of open-weight models
4. **pi** — The coding assistant is installed
5. **Launcher** — A startup script is written to `~/bin/`
6. **Configuration** — `pi` is pointed at your local server

## After the script finishes

See the [Usage](usage.md) page for how to start the engine and use `pi`.
